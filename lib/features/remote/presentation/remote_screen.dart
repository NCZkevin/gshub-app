import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../features/dashboard/domain/motion_item.dart';
import '../../../features/dashboard/presentation/dashboard_provider.dart';
import '../../../shared/widgets/video_view_widget.dart';

enum _RemoteVideoMode { both, left, right }

enum _RemotePanel { actions, settings }

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
  late WsConnectionManager _wsManager;
  Future<void>? _videoInitFuture;
  Timer? _controlTimer;
  Timer? _idleTimer;
  Timer? _hintTimer;

  _RemoteVideoMode _videoMode = _RemoteVideoMode.both;
  _SpeedPreset _speed = _SpeedPreset.normal;
  bool _videoBusy = false;
  bool _controlsLocked = true;
  bool _showVelocity = true;
  bool _showUnlockHint = false;
  bool _rotatingLeft = false;
  bool _rotatingRight = false;
  _RemotePanel? _openPanel;
  double _joystickX = 0;
  double _joystickY = 0;
  double _linearX = 0;
  double _linearY = 0;
  double _angularZ = 0;

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
    _stopAll(updateState: false);
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
    _stopAll();
    setState(() {
      _controlsLocked = true;
      _openPanel = null;
    });
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
      _openPanel = null;
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
      _openPanel = null;
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
    _linearY = -_joystickX * _maxLinear * _speed.factor;
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
  }

  void _stopAll({bool updateState = true}) {
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
  }

  Future<void> _startMotion(DashboardState data) async {
    await ref
        .read(dashboardProvider.notifier)
        .toggleMotion(true, adapter: data.selectedMotionAdapter);
  }

  Future<void> _emergencyStop(DashboardState data) async {
    _stopAll();
    setState(() {
      _controlsLocked = true;
      _openPanel = null;
    });
    final action = data.motionItems
        .where((item) => motionItemId(item) == 'emergency_stop')
        .firstOrNull;
    if (action != null) {
      try {
        await ref
            .read(dashboardProvider.notifier)
            .triggerMotion('emergency_stop');
        if (mounted) _showMessage('急停指令已发送');
      } catch (error) {
        if (mounted) _showMessage('急停执行失败：$error');
      }
    }
  }

  void _togglePanel(_RemotePanel panel) {
    setState(() => _openPanel = _openPanel == panel ? null : panel);
  }

  Future<void> _confirmMotion(
    Map<String, dynamic> item, {
    required bool motionRunning,
  }) async {
    if (_controlsLocked || !motionRunning) return;

    final id = motionItemId(item);
    if (id.isEmpty) return;
    final label = motionItemLabel(item);
    final description = motionItemDescription(item);

    _stopAll();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('执行“$label”？'),
        content: Text(description ?? '机器人将立即执行该动作，请确认周围环境安全。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认执行'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final currentData = ref.read(dashboardProvider).valueOrNull;
    final stillRunning =
        currentData?.servicesStatus?['motion']?['status'] == 'running';
    if (_controlsLocked || !stillRunning) {
      _showMessage('控制已锁定或 motion 已停止，动作未执行');
      return;
    }

    try {
      await ref.read(dashboardProvider.notifier).triggerMotion(id);
      if (mounted) _showMessage('$label 执行成功');
    } catch (error) {
      if (mounted) _showMessage('动作执行失败：$error');
    } finally {
      if (mounted) _resetIdleTimer();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
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
    _wsManager = ref.watch(wsManagerProvider);

    return PopScope(
      onPopInvokedWithResult: (_, _) => _stopAll(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: dashAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _RemoteError(message: '加载失败: $e'),
          data: (data) {
            final motionRunning =
                data.servicesStatus?['motion']?['status'] == 'running';
            final battery = data.robotInfo?.battery;
            final actionPending = data.pendingActions.any(
              (action) => action.startsWith('motion-action:'),
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 720 || constraints.maxHeight < 420;
                final controlEnabled = !_controlsLocked && motionRunning;
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
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _openPanel == null
                            ? null
                            : () => setState(() => _openPanel = null),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 8,
                      right: 12,
                      child: _TopHud(
                        deviceName: connection?.name ?? '未连接',
                        controlConnected: connection != null,
                        motionRunning: motionRunning,
                        battery: battery,
                        compact: compact,
                        onBack: () => context.pop(),
                        onEmergencyStop: motionRunning
                            ? () => _emergencyStop(data)
                            : null,
                      ),
                    ),
                    if (_showVelocity)
                      Positioned(
                        top: compact ? 58 : 66,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _VelocityOverlay(
                            linearX: _linearX,
                            linearY: _linearY,
                            angularZ: _angularZ,
                            compact: compact,
                          ),
                        ),
                      ),
                    Positioned(
                      left: compact ? 16 : 28,
                      bottom: compact ? 16 : 22,
                      child: _TranslationJoystick(
                        enabled: controlEnabled,
                        size: compact ? 144 : 172,
                        onMove: _updateJoystick,
                        onRelease: _releaseJoystick,
                      ),
                    ),
                    Positioned(
                      right: compact ? 16 : 28,
                      bottom: compact ? 22 : 30,
                      child: _RotationControls(
                        enabled: controlEnabled,
                        buttonSize: compact ? 84 : 104,
                        gap: compact ? 8 : 14,
                        leftActive: _rotatingLeft,
                        rightActive: _rotatingRight,
                        onLeftChanged: (active) =>
                            _setRotation(left: true, active: active),
                        onRightChanged: (active) =>
                            _setRotation(left: false, active: active),
                      ),
                    ),
                    if (!motionRunning)
                      _MotionPreparation(
                        data: data,
                        onStartMotion: () => _startMotion(data),
                      )
                    else if (_controlsLocked)
                      _ControlLockOverlay(onUnlock: _unlock),
                    if (_openPanel != null)
                      Positioned(
                        left: compact ? 96 : 180,
                        right: compact ? 96 : 180,
                        bottom: compact ? 76 : 88,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 480,
                              maxHeight: compact ? 156 : 220,
                            ),
                            child: _openPanel == _RemotePanel.actions
                                ? _MotionActionsPanel(
                                    items: data.motionItems,
                                    enabled: controlEnabled && !actionPending,
                                    controlsLocked: _controlsLocked,
                                    motionRunning: motionRunning,
                                    pendingActions: data.pendingActions,
                                    onActionPressed: (item) => _confirmMotion(
                                      item,
                                      motionRunning: motionRunning,
                                    ),
                                  )
                                : _RemoteSettingsPanel(
                                    speed: _speed,
                                    videoMode: _videoMode,
                                    videoBusy: _videoBusy,
                                    showVelocity: _showVelocity,
                                    onSpeedChanged: _setSpeed,
                                    onVideoModeChanged: (mode) =>
                                        setState(() => _videoMode = mode),
                                    onShowVelocityChanged: (show) =>
                                        setState(() => _showVelocity = show),
                                  ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: compact ? 14 : 20,
                      child: Center(
                        child: _ControlDock(
                          compact: compact,
                          openPanel: _openPanel,
                          actionCount: data.motionItems
                              .where((item) => motionItemId(item).isNotEmpty)
                              .length,
                          onActionsPressed: () =>
                              _togglePanel(_RemotePanel.actions),
                          onStopPressed: _stopAll,
                          onSettingsPressed: () =>
                              _togglePanel(_RemotePanel.settings),
                        ),
                      ),
                    ),
                    if (_showUnlockHint) const _UnlockHint(),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _forceLockControls() {
    if (_controlsLocked && !_hasVelocity && _openPanel == null) return;
    _stopAll();
    if (mounted) {
      setState(() {
        _controlsLocked = true;
        _openPanel = null;
      });
    }
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
  final bool compact;
  final VoidCallback onBack;
  final Future<void> Function()? onEmergencyStop;

  const _TopHud({
    required this.deviceName,
    required this.controlConnected,
    required this.motionRunning,
    required this.battery,
    required this.compact,
    required this.onBack,
    required this.onEmergencyStop,
  });

  @override
  Widget build(BuildContext context) {
    final batteryText = battery == null ? '--' : '$battery%';
    return Row(
      children: [
        _GlassIconButton(icon: Icons.arrow_back, onPressed: onBack),
        SizedBox(width: compact ? 6 : 10),
        Expanded(
          child: Wrap(
            spacing: compact ? 5 : 8,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HudPill(
                label: deviceName,
                icon: Icons.memory_outlined,
                compact: compact,
              ),
              _HudPill(
                label: controlConnected ? 'WS ONLINE' : 'WS OFFLINE',
                icon: controlConnected ? Icons.wifi : Icons.wifi_off,
                color: controlConnected ? AppTheme.success : AppTheme.danger,
                compact: compact,
              ),
              _HudPill(
                label: motionRunning ? 'MOTION ON' : 'MOTION OFF',
                icon: Icons.radio_button_checked,
                color: motionRunning ? AppTheme.success : AppTheme.warning,
                compact: compact,
              ),
              _HudPill(
                label: batteryText,
                icon: Icons.battery_full_outlined,
                color: battery != null && battery! <= 20
                    ? AppTheme.danger
                    : AppTheme.success,
                compact: compact,
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 6 : 10),
        _EmergencyButton(onTrigger: onEmergencyStop, compact: compact),
      ],
    );
  }
}

class _VelocityOverlay extends StatelessWidget {
  final double linearX;
  final double linearY;
  final double angularZ;
  final bool compact;

  const _VelocityOverlay({
    required this.linearX,
    required this.linearY,
    required this.angularZ,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      key: const ValueKey('remote_velocity_overlay'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 6 : 8,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 10 : 12,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.speed_rounded,
              color: AppTheme.accentDark,
              size: compact ? 14 : 16,
            ),
            const SizedBox(width: 6),
            Text('X ${linearX.toStringAsFixed(2)} m/s'),
            _VelocityDivider(compact: compact),
            Text('Y ${linearY.toStringAsFixed(2)} m/s'),
            _VelocityDivider(compact: compact),
            Text('W ${angularZ.toStringAsFixed(2)} rad/s'),
          ],
        ),
      ),
    );
  }
}

class _VelocityDivider extends StatelessWidget {
  final bool compact;

  const _VelocityDivider({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8),
      child: Text(
        '|',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
      ),
    );
  }
}

class _RemoteSettingsPanel extends StatelessWidget {
  final _SpeedPreset speed;
  final _RemoteVideoMode videoMode;
  final bool videoBusy;
  final bool showVelocity;
  final ValueChanged<_SpeedPreset> onSpeedChanged;
  final ValueChanged<_RemoteVideoMode> onVideoModeChanged;
  final ValueChanged<bool> onShowVelocityChanged;

  const _RemoteSettingsPanel({
    required this.speed,
    required this.videoMode,
    required this.videoBusy,
    required this.showVelocity,
    required this.onSpeedChanged,
    required this.onVideoModeChanged,
    required this.onShowVelocityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      key: const ValueKey('remote_settings_panel'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SettingsRow(
              label: '速度档位',
              child: _SpeedSelector(value: speed, onChanged: onSpeedChanged),
            ),
            const SizedBox(height: 8),
            _SettingsRow(
              label: videoBusy ? '视频连接中' : '视频画面',
              child: _VideoModeControl(
                mode: videoMode,
                onModeChanged: onVideoModeChanged,
              ),
            ),
            const SizedBox(height: 4),
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                key: const ValueKey('remote_velocity_toggle'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: const Text(
                  '显示实时速度',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: const Text(
                  '显示当前下发的 X / Y / W 指令',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                value: showVelocity,
                onChanged: onShowVelocityChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _VideoModeControl extends StatelessWidget {
  final _RemoteVideoMode mode;
  final ValueChanged<_RemoteVideoMode> onModeChanged;

  const _VideoModeControl({required this.mode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_RemoteVideoMode>(
      style: _segmentedStyle(),
      segments: const [
        ButtonSegment(value: _RemoteVideoMode.both, label: Text('双路')),
        ButtonSegment(value: _RemoteVideoMode.left, label: Text('左')),
        ButtonSegment(value: _RemoteVideoMode.right, label: Text('右')),
      ],
      selected: {mode},
      onSelectionChanged: (set) => onModeChanged(set.first),
    );
  }
}

ButtonStyle _segmentedStyle() {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    foregroundColor: const WidgetStatePropertyAll(Colors.white),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppTheme.primaryColor.withValues(alpha: 0.55);
      }
      return Colors.transparent;
    }),
    side: WidgetStatePropertyAll(
      BorderSide(color: Colors.white.withValues(alpha: 0.24)),
    ),
  );
}

class _MotionActionsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool enabled;
  final bool controlsLocked;
  final bool motionRunning;
  final Set<String> pendingActions;
  final ValueChanged<Map<String, dynamic>> onActionPressed;

  const _MotionActionsPanel({
    required this.items,
    required this.enabled,
    required this.controlsLocked,
    required this.motionRunning,
    required this.pendingActions,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final actions = items
        .where((item) => motionItemId(item).isNotEmpty)
        .toList(growable: false);
    final unavailableMessage = !motionRunning
        ? 'motion 未运行，动作暂不可用'
        : controlsLocked
        ? '解锁控制后可执行动作'
        : null;

    return _GlassPanel(
      key: const ValueKey('remote_actions_panel'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_run_rounded,
                  color: AppTheme.accentDark,
                  size: 18,
                ),
                const SizedBox(width: 7),
                const Text(
                  '离散动作',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${actions.length} 项',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            if (unavailableMessage != null) ...[
              const SizedBox(height: 5),
              Text(
                unavailableMessage,
                style: const TextStyle(color: AppTheme.warning, fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            if (actions.isEmpty)
              const SizedBox(
                width: double.infinity,
                child: Text(
                  '当前适配器暂无可用动作',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions.map((item) {
                  final id = motionItemId(item);
                  final pending = pendingActions.contains('motion-action:$id');
                  return Tooltip(
                    message: motionItemDescription(item) ?? id,
                    child: OutlinedButton(
                      onPressed: enabled ? () => onActionPressed(item) : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(pending ? '执行中…' : motionItemLabel(item)),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TranslationJoystick extends StatefulWidget {
  final bool enabled;
  final double size;
  final void Function(double x, double y) onMove;
  final VoidCallback onRelease;

  const _TranslationJoystick({
    required this.enabled,
    required this.size,
    required this.onMove,
    required this.onRelease,
  });

  @override
  State<_TranslationJoystick> createState() => _TranslationJoystickState();
}

class _TranslationJoystickState extends State<_TranslationJoystick> {
  Offset _stick = Offset.zero;

  void _update(Offset localPosition) {
    if (!widget.enabled) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final radius = widget.size * 0.32;
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
        key: const ValueKey('remote_translation_joystick'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _update(details.localPosition),
        onPanUpdate: (details) => _update(details.localPosition),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: CustomPaint(
          size: Size.square(widget.size),
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
  final double buttonSize;
  final double gap;
  final bool leftActive;
  final bool rightActive;
  final ValueChanged<bool> onLeftChanged;
  final ValueChanged<bool> onRightChanged;

  const _RotationControls({
    required this.enabled,
    required this.buttonSize,
    required this.gap,
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
            size: buttonSize,
            onChanged: onLeftChanged,
          ),
          SizedBox(width: gap),
          _HoldButton(
            icon: Icons.rotate_right_rounded,
            label: '右转',
            active: rightActive,
            enabled: enabled,
            size: buttonSize,
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
  final double size;
  final ValueChanged<bool> onChanged;

  const _HoldButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    required this.size,
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
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primaryColor.withValues(alpha: 0.58)
              : Colors.black.withValues(alpha: 0.34),
          border: Border.all(
            color: active
                ? AppTheme.primaryColor
                : Colors.white.withValues(alpha: 0.42),
          ),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: size * 0.34),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _ControlDock extends StatelessWidget {
  final bool compact;
  final _RemotePanel? openPanel;
  final int actionCount;
  final VoidCallback onActionsPressed;
  final VoidCallback onStopPressed;
  final VoidCallback onSettingsPressed;

  const _ControlDock({
    required this.compact,
    required this.openPanel,
    required this.actionCount,
    required this.onActionsPressed,
    required this.onStopPressed,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: EdgeInsets.all(compact ? 4 : 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DockButton(
            key: const ValueKey('remote_actions_button'),
            icon: Icons.directions_run_rounded,
            label: actionCount == 0 ? '动作' : '动作 $actionCount',
            active: openPanel == _RemotePanel.actions,
            compact: compact,
            onPressed: onActionsPressed,
          ),
          SizedBox(width: compact ? 4 : 6),
          _StopControl(compact: compact, onPressed: onStopPressed),
          SizedBox(width: compact ? 4 : 6),
          _DockButton(
            key: const ValueKey('remote_settings_button'),
            icon: Icons.tune_rounded,
            label: '设置',
            active: openPanel == _RemotePanel.settings,
            compact: compact,
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool compact;
  final VoidCallback onPressed;

  const _DockButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.compact,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: active
            ? AppTheme.primaryColor.withValues(alpha: 0.42)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 12,
          vertical: compact ? 9 : 11,
        ),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: compact ? 17 : 19),
      label: Text(label, style: TextStyle(fontSize: compact ? 11 : 12)),
    );
  }
}

class _StopControl extends StatelessWidget {
  final bool compact;
  final VoidCallback onPressed;

  const _StopControl({required this.compact, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('remote_stop_button'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.danger.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: compact ? 9 : 11,
        ),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      icon: Icon(Icons.stop_rounded, size: compact ? 18 : 20),
      label: Text('停止', style: TextStyle(fontSize: compact ? 11 : 12)),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  final _SpeedPreset value;
  final ValueChanged<_SpeedPreset> onChanged;

  const _SpeedSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_SpeedPreset>(
      style: _segmentedStyle(),
      segments: const [
        ButtonSegment(value: _SpeedPreset.slow, label: Text('慢速')),
        ButtonSegment(value: _SpeedPreset.normal, label: Text('标准')),
        ButtonSegment(value: _SpeedPreset.fast, label: Text('快速')),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.first),
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
  final bool compact;

  const _EmergencyButton({required this.onTrigger, required this.compact});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onTrigger,
      child: Opacity(
        opacity: onTrigger == null ? 0.46 : 1,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 14,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: compact ? 16 : 18,
              ),
              SizedBox(width: compact ? 4 : 6),
              Text(
                compact ? '急停' : '长按急停',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 11 : 14,
                ),
              ),
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
      top: 108,
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
  final bool compact;

  const _HudPill({
    required this.label,
    required this.icon,
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: compact ? 13 : 16),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 12,
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
    super.key,
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
