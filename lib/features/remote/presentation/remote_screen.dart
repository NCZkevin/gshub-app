import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../features/dashboard/presentation/dashboard_provider.dart';
import '../../../shared/widgets/video_view_widget.dart';

enum _RemoteVideoMode { both, left, right }

enum _SpeedPreset {
  slow('慢速', 0.3),
  normal('标准', 0.6),
  fast('快速', 1.0);

  final String label;
  final double factor;

  const _SpeedPreset(this.label, this.factor);
}

class RemoteScreen extends ConsumerStatefulWidget {
  const RemoteScreen({super.key});

  @override
  ConsumerState<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends ConsumerState<RemoteScreen> {
  static const _controlInterval = Duration(milliseconds: 100);
  static const _idleLockDuration = Duration(seconds: 30);
  static const _maxLinear = 1.0;
  static const _maxAngular = 1.5;
  static const _deadZone = 0.08;

  late final JanusVideoController _leftVideo;
  late final JanusVideoController _rightVideo;
  late final WsConnectionManager _wsManager;
  Future<void>? _videoInitFuture;
  Timer? _controlTimer;
  Timer? _idleTimer;
  Timer? _hintTimer;

  _RemoteVideoMode _videoMode = _RemoteVideoMode.both;
  _SpeedPreset _speed = _SpeedPreset.normal;
  bool _videoPlaying = false;
  bool _videoBusy = false;
  bool _controlsLocked = true;
  bool _detailsOpen = false;
  bool _showUnlockHint = false;
  bool _rotatingLeft = false;
  bool _rotatingRight = false;
  double _joystickX = 0;
  double _joystickY = 0;
  double _linearX = 0;
  double _linearY = 0;
  double _angularZ = 0;
  DateTime? _lastCommandAt;

  @override
  void initState() {
    super.initState();
    _wsManager = ref.read(wsManagerProvider);
    _leftVideo = JanusVideoController(streamId: 100);
    _rightVideo = JanusVideoController(streamId: 101);
    _enterImmersiveMode();
    _videoInitFuture = _initializeVideo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wsManager.sendStop();
    });
  }

  Future<void> _enterImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  Future<void> _initializeVideo() async {
    await Future.wait([_leftVideo.initialize(), _rightVideo.initialize()]);
    if (!mounted) return;
    if (mounted) setState(() {});
    final url = _janusWsUrl(ref.read(activeConnectionProvider)?.baseUrl);
    if (url != null) {
      await _playVideo(url);
    }
  }

  @override
  void dispose() {
    _stopAll(force: true, updateState: false);
    _controlTimer?.cancel();
    _idleTimer?.cancel();
    _hintTimer?.cancel();
    unawaited(_disposeVideoControllers());
    unawaited(_exitImmersiveMode());
    super.dispose();
  }

  Future<void> _disposeVideoControllers() async {
    try {
      await _videoInitFuture;
    } catch (_) {}
    await Future.wait([_leftVideo.dispose(), _rightVideo.dispose()]);
  }

  Future<void> _playVideo(String url) async {
    if (_videoBusy) return;
    setState(() => _videoBusy = true);
    try {
      await Future.wait([
        _connectVideoSide(_leftVideo, url),
        _connectVideoSide(_rightVideo, url),
      ]);
      if (mounted) setState(() => _videoPlaying = true);
    } finally {
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  Future<void> _connectVideoSide(
    JanusVideoController controller,
    String url,
  ) async {
    try {
      await controller.connect(url);
    } catch (e) {
      controller.status.value = '连接失败: $e';
    }
  }

  String? _janusWsUrl(String? baseUrl) {
    if (baseUrl == null || baseUrl.isEmpty) return null;
    final uri = Uri.parse(baseUrl);
    return Uri(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      host: uri.host,
      port: 8188,
    ).toString();
  }

  void _unlock() {
    setState(() {
      _controlsLocked = false;
      _showUnlockHint = true;
    });
    _resetIdleTimer();
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showUnlockHint = false);
    });
  }

  void _lockControls() {
    _stopAll(force: true);
    setState(() => _controlsLocked = true);
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_controlsLocked) return;
    _idleTimer = Timer(_idleLockDuration, _lockControls);
  }

  double _applyDeadZone(double value) {
    if (value.abs() < _deadZone) return 0;
    return value.clamp(-1.0, 1.0);
  }

  void _updateJoystick(double x, double y) {
    if (_controlsLocked) return;
    setState(() {
      _joystickX = _applyDeadZone(x);
      _joystickY = _applyDeadZone(y);
      _applySpeedToVelocity();
      _detailsOpen = false;
    });
    _sendNow();
    _ensureControlLoop();
    _resetIdleTimer();
  }

  void _releaseJoystick() {
    if (_controlsLocked) return;
    setState(() {
      _joystickX = 0;
      _joystickY = 0;
      _linearX = 0;
      _linearY = 0;
    });
    _sendNow();
    _syncLoopAfterState();
    _resetIdleTimer();
  }

  void _setRotation({required bool left, required bool active}) {
    if (_controlsLocked) return;
    setState(() {
      if (left) {
        _rotatingLeft = active;
      } else {
        _rotatingRight = active;
      }
      _angularZ = _rotationValue();
      _detailsOpen = false;
    });
    _sendNow();
    _syncLoopAfterState();
    _resetIdleTimer();
  }

  double _rotationValue() {
    if (_rotatingLeft == _rotatingRight) return 0;
    return (_rotatingLeft ? 1 : -1) * _maxAngular * _speed.factor;
  }

  void _applySpeedToVelocity() {
    _linearX = -_joystickY * _maxLinear * _speed.factor;
    _linearY = _joystickX * _maxLinear * _speed.factor;
  }

  void _setSpeed(_SpeedPreset speed) {
    setState(() {
      _speed = speed;
      _applySpeedToVelocity();
      _angularZ = _rotationValue();
    });
    if (!_controlsLocked) {
      _sendNow();
      _syncLoopAfterState();
      _resetIdleTimer();
    }
  }

  void _ensureControlLoop() {
    if (!_hasVelocity || _controlTimer != null) return;
    _controlTimer = Timer.periodic(_controlInterval, (_) => _sendNow());
  }

  void _syncLoopAfterState() {
    if (_hasVelocity) {
      _ensureControlLoop();
    } else {
      _controlTimer?.cancel();
      _controlTimer = null;
      _wsManager.sendStop();
    }
  }

  bool get _hasVelocity => _linearX != 0 || _linearY != 0 || _angularZ != 0;

  void _sendNow() {
    if (_controlsLocked) return;
    if (_hasVelocity) {
      _wsManager.sendCmdVel(
        _linearX,
        _angularZ,
        linearY: _linearY,
        force: true,
      );
    } else {
      _wsManager.sendStop();
    }
    _lastCommandAt = DateTime.now();
  }

  void _stopAll({bool force = false, bool updateState = true}) {
    _controlTimer?.cancel();
    _controlTimer = null;
    if (updateState && mounted) {
      setState(() {
        _linearX = 0;
        _linearY = 0;
        _angularZ = 0;
        _rotatingLeft = false;
        _rotatingRight = false;
        _joystickX = 0;
        _joystickY = 0;
      });
    } else {
      _linearX = 0;
      _linearY = 0;
      _angularZ = 0;
      _rotatingLeft = false;
      _rotatingRight = false;
      _joystickX = 0;
      _joystickY = 0;
    }
    _wsManager.sendStop();
    if (force) _lastCommandAt = DateTime.now();
  }

  Future<void> _startMotion(DashboardState data) async {
    await ref
        .read(dashboardProvider.notifier)
        .toggleMotion(true, adapter: data.selectedMotionAdapter);
  }

  Future<void> _emergencyStop(DashboardState data) async {
    _stopAll(force: true);
    setState(() => _controlsLocked = true);
    final action = data.motionItems
        .where((item) => item['id']?.toString() == 'emergency_stop')
        .firstOrNull;
    if (action != null) {
      await ref
          .read(dashboardProvider.notifier)
          .triggerMotion('emergency_stop');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dashboardProvider, (_, next) {
      final data = next.valueOrNull;
      if (data == null) return;
      final motionRunning =
          data.servicesStatus?['motion']?['status'] == 'running';
      if (!motionRunning) _forceLockControls();
    });
    ref.listen(activeConnectionProvider, (_, next) {
      if (next == null) _forceLockControls();
    });

    final dashAsync = ref.watch(dashboardProvider);
    final connection = ref.watch(activeConnectionProvider);

    return PopScope(
      onPopInvokedWithResult: (_, _) => _stopAll(force: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: dashAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _RemoteError(message: '加载失败: $e'),
          data: (data) {
            final motionRunning =
                data.servicesStatus?['motion']?['status'] == 'running';
            final battery = data.robotInfo?.battery;
            return Stack(
              fit: StackFit.expand,
              children: [
                _VideoBackdrop(
                  mode: _videoMode,
                  left: _leftVideo,
                  right: _rightVideo,
                  connected: connection != null,
                ),
                _RemoteScrim(),
                Positioned(
                  left: 12,
                  top: 8,
                  right: 12,
                  child: _TopHud(
                    deviceName: connection?.name ?? '未连接',
                    controlConnected: connection != null,
                    motionRunning: motionRunning,
                    battery: battery,
                    speed: _speed,
                    linearX: _linearX,
                    linearY: _linearY,
                    angularZ: _angularZ,
                    detailsOpen: _detailsOpen,
                    lastCommandAt: _lastCommandAt,
                    onBack: () => context.pop(),
                    onToggleDetails: () =>
                        setState(() => _detailsOpen = !_detailsOpen),
                    onEmergencyStop: motionRunning
                        ? () => _emergencyStop(data)
                        : null,
                  ),
                ),
                Positioned(
                  top: 66,
                  left: 18,
                  child: _VideoModeControl(
                    mode: _videoMode,
                    playing: _videoPlaying,
                    busy: _videoBusy,
                    onModeChanged: (mode) => setState(() => _videoMode = mode),
                  ),
                ),
                Positioned(
                  left: 28,
                  bottom: 22,
                  child: _TranslationJoystick(
                    enabled: !_controlsLocked && motionRunning,
                    onMove: _updateJoystick,
                    onRelease: _releaseJoystick,
                  ),
                ),
                Positioned(
                  right: 28,
                  bottom: 30,
                  child: _RotationControls(
                    enabled: !_controlsLocked && motionRunning,
                    leftActive: _rotatingLeft,
                    rightActive: _rotatingRight,
                    onLeftChanged: (active) =>
                        _setRotation(left: true, active: active),
                    onRightChanged: (active) =>
                        _setRotation(left: false, active: active),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 26,
                  child: Center(
                    child: _StopControl(onPressed: () => _stopAll(force: true)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 106,
                  child: Center(
                    child: _SpeedSelector(value: _speed, onChanged: _setSpeed),
                  ),
                ),
                if (!motionRunning)
                  _MotionPreparation(
                    data: data,
                    onStartMotion: () => _startMotion(data),
                  )
                else if (_controlsLocked)
                  _ControlLockOverlay(onUnlock: _unlock),
                if (_showUnlockHint) const _UnlockHint(),
              ],
            );
          },
        ),
      ),
    );
  }

  void _forceLockControls() {
    if (_controlsLocked && !_hasVelocity) return;
    _stopAll(force: true);
    if (mounted) setState(() => _controlsLocked = true);
  }
}

class _VideoBackdrop extends StatelessWidget {
  final _RemoteVideoMode mode;
  final JanusVideoController left;
  final JanusVideoController right;
  final bool connected;

  const _VideoBackdrop({
    required this.mode,
    required this.left,
    required this.right,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (mode != _RemoteVideoMode.right)
          Expanded(
            child: _RemoteVideoPane(
              label: '左摄像头',
              controller: left,
              placeholder: connected ? '等待左路视频' : '未连接设备',
            ),
          ),
        if (mode != _RemoteVideoMode.left)
          Expanded(
            child: _RemoteVideoPane(
              label: '右摄像头',
              controller: right,
              placeholder: connected ? '等待右路视频' : '未连接设备',
            ),
          ),
      ],
    );
  }
}

class _RemoteVideoPane extends StatelessWidget {
  final String label;
  final JanusVideoController controller;
  final String placeholder;

  const _RemoteVideoPane({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: VideoViewWidget(
            renderer: controller.renderer,
            placeholderText: placeholder,
          ),
        ),
        Positioned(
          left: 12,
          bottom: 10,
          child: ValueListenableBuilder<String>(
            valueListenable: controller.status,
            builder: (context, status, _) => _HudPill(
              label: '$label · $status',
              icon: Icons.videocam_outlined,
            ),
          ),
        ),
      ],
    );
  }
}

class _RemoteScrim extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.54),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.42),
            ],
            stops: const [0, 0.44, 1],
          ),
        ),
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  final String deviceName;
  final bool controlConnected;
  final bool motionRunning;
  final int? battery;
  final _SpeedPreset speed;
  final double linearX;
  final double linearY;
  final double angularZ;
  final bool detailsOpen;
  final DateTime? lastCommandAt;
  final VoidCallback onBack;
  final VoidCallback onToggleDetails;
  final Future<void> Function()? onEmergencyStop;

  const _TopHud({
    required this.deviceName,
    required this.controlConnected,
    required this.motionRunning,
    required this.battery,
    required this.speed,
    required this.linearX,
    required this.linearY,
    required this.angularZ,
    required this.detailsOpen,
    required this.lastCommandAt,
    required this.onBack,
    required this.onToggleDetails,
    required this.onEmergencyStop,
  });

  @override
  Widget build(BuildContext context) {
    final batteryText = battery == null ? '--' : '$battery%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _GlassIconButton(icon: Icons.arrow_back, onPressed: onBack),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: onToggleDetails,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _HudPill(label: deviceName, icon: Icons.memory_outlined),
                    _HudPill(
                      label: controlConnected ? 'WS ONLINE' : 'WS OFFLINE',
                      icon: controlConnected ? Icons.wifi : Icons.wifi_off,
                      color: controlConnected
                          ? AppTheme.success
                          : AppTheme.danger,
                    ),
                    _HudPill(
                      label: motionRunning ? 'MOTION ON' : 'MOTION OFF',
                      icon: Icons.radio_button_checked,
                      color: motionRunning
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                    _HudPill(
                      label: batteryText,
                      icon: Icons.battery_full_outlined,
                      color: battery != null && battery! <= 20
                          ? AppTheme.danger
                          : AppTheme.success,
                    ),
                    _HudPill(label: speed.label, icon: Icons.speed_outlined),
                    _HudPill(
                      label:
                          'X ${linearX.toStringAsFixed(2)}  Y ${linearY.toStringAsFixed(2)}  W ${angularZ.toStringAsFixed(2)}',
                      icon: Icons.analytics_outlined,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _EmergencyButton(onTrigger: onEmergencyStop),
          ],
        ),
        if (detailsOpen) ...[
          const SizedBox(height: 8),
          _DetailsPanel(
            linearX: linearX,
            linearY: linearY,
            angularZ: angularZ,
            lastCommandAt: lastCommandAt,
          ),
        ],
      ],
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  final double linearX;
  final double linearY;
  final double angularZ;
  final DateTime? lastCommandAt;

  const _DetailsPanel({
    required this.linearX,
    required this.linearY,
    required this.angularZ,
    required this.lastCommandAt,
  });

  @override
  Widget build(BuildContext context) {
    final last = lastCommandAt == null
        ? '未发送'
        : '${lastCommandAt!.hour.toString().padLeft(2, '0')}:${lastCommandAt!.minute.toString().padLeft(2, '0')}:${lastCommandAt!.second.toString().padLeft(2, '0')}';
    return _GlassPanel(
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('实时信息'),
            const SizedBox(height: 6),
            Text('输出速度 X ${linearX.toStringAsFixed(3)} m/s'),
            Text('输出速度 Y ${linearY.toStringAsFixed(3)} m/s'),
            Text('角速度   W ${angularZ.toStringAsFixed(3)} rad/s'),
            Text('最近指令 $last'),
          ],
        ),
      ),
    );
  }
}

class _VideoModeControl extends StatelessWidget {
  final _RemoteVideoMode mode;
  final bool playing;
  final bool busy;
  final ValueChanged<_RemoteVideoMode> onModeChanged;

  const _VideoModeControl({
    required this.mode,
    required this.playing,
    required this.busy,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(4),
      child: SegmentedButton<_RemoteVideoMode>(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.primaryColor.withValues(alpha: 0.55);
            }
            return Colors.transparent;
          }),
        ),
        segments: const [
          ButtonSegment(value: _RemoteVideoMode.both, label: Text('双路')),
          ButtonSegment(value: _RemoteVideoMode.left, label: Text('左')),
          ButtonSegment(value: _RemoteVideoMode.right, label: Text('右')),
        ],
        selected: {mode},
        onSelectionChanged: (set) => onModeChanged(set.first),
      ),
    );
  }
}

class _TranslationJoystick extends StatefulWidget {
  final bool enabled;
  final void Function(double x, double y) onMove;
  final VoidCallback onRelease;

  const _TranslationJoystick({
    required this.enabled,
    required this.onMove,
    required this.onRelease,
  });

  @override
  State<_TranslationJoystick> createState() => _TranslationJoystickState();
}

class _TranslationJoystickState extends State<_TranslationJoystick> {
  static const _size = 172.0;
  Offset _stick = Offset.zero;

  void _update(Offset localPosition) {
    if (!widget.enabled) return;
    final center = const Offset(_size / 2, _size / 2);
    final radius = _size * 0.32;
    var delta = localPosition - center;
    final distance = delta.distance;
    if (distance > radius) delta = delta / distance * radius;
    setState(() => _stick = delta);
    widget.onMove(delta.dx / radius, delta.dy / radius);
  }

  void _release() {
    if (_stick != Offset.zero) setState(() => _stick = Offset.zero);
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.enabled ? 1.0 : 0.42;
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onPanStart: (details) => _update(details.localPosition),
        onPanUpdate: (details) => _update(details.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: CustomPaint(
          size: const Size.square(_size),
          painter: _JoystickPainter(stick: _stick),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset stick;

  const _JoystickPainter({required this.stick});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final basePaint = Paint()..color = Colors.black.withValues(alpha: 0.34);
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final stickPaint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.82);

    canvas.drawCircle(center, size.width / 2, basePaint);
    canvas.drawCircle(center, size.width / 2 - 1, strokePaint);
    canvas.drawLine(
      Offset(center.dx, 18),
      Offset(center.dx, size.height - 18),
      strokePaint,
    );
    canvas.drawLine(
      Offset(18, center.dy),
      Offset(size.width - 18, center.dy),
      strokePaint,
    );
    canvas.drawCircle(center + stick, size.width * 0.22, stickPaint);
    canvas.drawCircle(center + stick, size.width * 0.22, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) =>
      oldDelegate.stick != stick;
}

class _RotationControls extends StatelessWidget {
  final bool enabled;
  final bool leftActive;
  final bool rightActive;
  final ValueChanged<bool> onLeftChanged;
  final ValueChanged<bool> onRightChanged;

  const _RotationControls({
    required this.enabled,
    required this.leftActive,
    required this.rightActive,
    required this.onLeftChanged,
    required this.onRightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Row(
        children: [
          _HoldButton(
            icon: Icons.rotate_left_rounded,
            label: '左转',
            active: leftActive,
            enabled: enabled,
            onChanged: onLeftChanged,
          ),
          const SizedBox(width: 14),
          _HoldButton(
            icon: Icons.rotate_right_rounded,
            label: '右转',
            active: rightActive,
            enabled: enabled,
            onChanged: onRightChanged,
          ),
        ],
      ),
    );
  }
}

class _HoldButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _HoldButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: enabled ? (_) => onChanged(true) : null,
      onPointerUp: enabled ? (_) => onChanged(false) : null,
      onPointerCancel: enabled ? (_) => onChanged(false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryColor.withValues(alpha: 0.58)
              : Colors.black.withValues(alpha: 0.34),
          border: Border.all(
            color: active
                ? AppTheme.primaryColor
                : Colors.white.withValues(alpha: 0.42),
          ),
          borderRadius: BorderRadius.circular(52),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StopControl extends StatelessWidget {
  final VoidCallback onPressed;

  const _StopControl({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.danger.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.stop_rounded),
      label: const Text('停止'),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  final _SpeedPreset value;
  final ValueChanged<_SpeedPreset> onChanged;

  const _SpeedSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(4),
      child: SegmentedButton<_SpeedPreset>(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.primaryColor.withValues(alpha: 0.55);
            }
            return Colors.transparent;
          }),
        ),
        segments: const [
          ButtonSegment(value: _SpeedPreset.slow, label: Text('慢速')),
          ButtonSegment(value: _SpeedPreset.normal, label: Text('标准')),
          ButtonSegment(value: _SpeedPreset.fast, label: Text('快速')),
        ],
        selected: {value},
        onSelectionChanged: (set) => onChanged(set.first),
      ),
    );
  }
}

class _ControlLockOverlay extends StatelessWidget {
  final VoidCallback onUnlock;

  const _ControlLockOverlay({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.white, size: 34),
            const SizedBox(height: 8),
            const Text(
              '控制已锁定',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              '点击解锁后可遥控机器人',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('解锁控制'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MotionPreparation extends StatelessWidget {
  final DashboardState data;
  final Future<void> Function() onStartMotion;

  const _MotionPreparation({required this.data, required this.onStartMotion});

  @override
  Widget build(BuildContext context) {
    final pending = data.pendingActions.contains('motion');
    return Center(
      child: _GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.power_settings_new, color: Colors.white, size: 34),
            const SizedBox(height: 8),
            const Text(
              'motion 未运行，无法遥控',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              '启动后仍需点击解锁控制',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            if (data.motionAdapters.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '适配器 ${data.selectedMotionAdapter}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: pending ? null : onStartMotion,
              icon: pending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: const Text('启动 motion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final Future<void> Function()? onTrigger;

  const _EmergencyButton({required this.onTrigger});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onTrigger,
      child: Opacity(
        opacity: onTrigger == null ? 0.46 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('长按急停', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnlockHint extends StatelessWidget {
  const _UnlockHint();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 92,
      child: Center(
        child: _HudPill(
          label: '遥控已解锁，松手会自动停止',
          icon: Icons.lock_open_rounded,
          color: AppTheme.success,
        ),
      ),
    );
  }
}

class _RemoteError extends StatelessWidget {
  final String message;

  const _RemoteError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _HudPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _HudPill({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.42),
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
