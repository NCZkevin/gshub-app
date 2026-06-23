import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../../../shared/widgets/console_widgets.dart';
import '../../../shared/widgets/joystick_widget.dart';
import '../../../shared/widgets/video_view_widget.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  double _speedMultiplier = 0.5;

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(dashboardProvider);
    final wsManager = ref.watch(wsManagerProvider);
    final activeConnection = ref.watch(activeConnectionProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;

    final robotInfo = dashAsync.whenOrNull(data: (d) => d.robotInfo);
    final connected = robotInfo?.connected == true;

    return ConsoleScaffold(
      appBar: AppBar(
        title: ConsoleAppBarTitle(
          title: '控制中心',
          subtitle: robotInfo?.robotType ?? 'robot console',
        ),
        actions: [
          StatusPill(
            label: connected ? 'CONNECTED' : 'OFFLINE',
            color: connected ? AppTheme.success : AppTheme.danger,
            icon: connected ? Icons.wifi : Icons.wifi_off,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (data) => isWide
            ? _WideLayout(
                data: data,
                wsManager: wsManager,
                janusWsUrl: _janusWsUrl(activeConnection?.baseUrl),
                speedMultiplier: _speedMultiplier,
                onSpeedChanged: (v) => setState(() => _speedMultiplier = v),
              )
            : _NarrowLayout(
                data: data,
                wsManager: wsManager,
                janusWsUrl: _janusWsUrl(activeConnection?.baseUrl),
                speedMultiplier: _speedMultiplier,
                onSpeedChanged: (v) => setState(() => _speedMultiplier = v),
              ),
      ),
    );
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
}

// ─── 宽屏布局（平板/桌面）──────────────────────────────────────

class _WideLayout extends ConsumerWidget {
  final DashboardState data;
  final WsConnectionManager wsManager;
  final String? janusWsUrl;
  final double speedMultiplier;
  final void Function(double) onSpeedChanged;

  const _WideLayout({
    required this.data,
    required this.wsManager,
    required this.janusWsUrl,
    required this.speedMultiplier,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左列：遥控 + 服务
        SizedBox(
          width: 260,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _TeleopCard(
                  data: data,
                  wsManager: wsManager,
                  speedMultiplier: speedMultiplier,
                ),
                const SizedBox(height: 12),
                Slider(
                  value: speedMultiplier,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '速度 ${(speedMultiplier * 100).round()}%',
                  onChanged: onSpeedChanged,
                ),
                const SizedBox(height: 12),
                _ServicesCard(data: data),
              ],
            ),
          ),
        ),
        // 中列：视频 + 系统指标
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _VideoStreamCard(janusWsUrl: janusWsUrl, height: 250),
                const SizedBox(height: 12),
                _SystemMetricsCard(data: data),
              ],
            ),
          ),
        ),
        // 右列：模型容器
        SizedBox(
          width: 220,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _ModelContainersCard(data: data),
          ),
        ),
      ],
    );
  }
}

// ─── 窄屏布局（手机）─────────────────────────────────────────

class _NarrowLayout extends ConsumerWidget {
  final DashboardState data;
  final WsConnectionManager wsManager;
  final String? janusWsUrl;
  final double speedMultiplier;
  final void Function(double) onSpeedChanged;

  const _NarrowLayout({
    required this.data,
    required this.wsManager,
    required this.janusWsUrl,
    required this.speedMultiplier,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _VideoStreamCard(janusWsUrl: janusWsUrl, height: 210),
          const SizedBox(height: 12),
          _SystemMetricsCard(data: data),
          const SizedBox(height: 12),
          _TeleopCard(
            data: data,
            wsManager: wsManager,
            speedMultiplier: speedMultiplier,
          ),
          const SizedBox(height: 4),
          Slider(
            value: speedMultiplier,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            label: '速度 ${(speedMultiplier * 100).round()}%',
            onChanged: onSpeedChanged,
          ),
          const SizedBox(height: 12),
          _ServicesCard(data: data),
          const SizedBox(height: 12),
          _ModelContainersCard(data: data),
        ],
      ),
    );
  }
}

// ─── 子组件 ──────────────────────────────────────────────────

class _VideoStreamCard extends StatefulWidget {
  final String? janusWsUrl;
  final double height;

  const _VideoStreamCard({required this.janusWsUrl, required this.height});

  @override
  State<_VideoStreamCard> createState() => _VideoStreamCardState();
}

class _VideoStreamCardState extends State<_VideoStreamCard> {
  late final JanusVideoController _left;
  late final JanusVideoController _right;
  bool _playing = false;
  bool _busy = false;
  String _viewMode = 'both';

  @override
  void initState() {
    super.initState();
    _left = JanusVideoController(streamId: 100);
    _right = JanusVideoController(streamId: 101);
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([_left.initialize(), _right.initialize()]);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _VideoStreamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.janusWsUrl != widget.janusWsUrl && _playing) {
      _stop();
    }
  }

  Future<void> _play() async {
    final url = widget.janusWsUrl;
    if (url == null || _busy) return;
    setState(() => _busy = true);
    try {
      await Future.wait([_connectSide(_left, url), _connectSide(_right, url)]);
      if (mounted) setState(() => _playing = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectSide(JanusVideoController controller, String url) async {
    try {
      await controller.connect(url);
    } catch (e) {
      controller.status.value = '连接失败: $e';
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Future.wait([_left.stop(), _right.stop()]);
      if (mounted) {
        setState(() {
          _playing = false;
          _viewMode = 'both';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.janusWsUrl != null;
    return ConsoleCard(
      title: '视频流',
      icon: Icons.videocam_outlined,
      trailing: ValueListenableBuilder<String>(
        valueListenable: _left.status,
        builder: (context, status, _) => StatusPill(
          label: _videoStatusLabel(connected ? status : '未配置'),
          color: _videoStatusColor(
            connected: connected,
            playing: _playing,
            label: status,
          ),
        ),
      ),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  Row(
                    children: [
                      if (_viewMode != 'right')
                        Expanded(
                          child: _StreamPane(
                            label: '左',
                            controller: _left,
                            placeholder: connected
                                ? 'NO SIGNAL — 点击下方播放'
                                : '未配置连接',
                          ),
                        ),
                      if (_viewMode != 'left')
                        Expanded(
                          child: _StreamPane(
                            label: '右',
                            controller: _right,
                            placeholder: connected
                                ? 'NO SIGNAL — 点击下方播放'
                                : '未配置连接',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _VideoControlBar(
              connected: connected,
              playing: _playing,
              viewMode: _viewMode,
              busy: _busy,
              onPlayToggle: _playing ? _stop : _play,
              onViewModeChanged: _playing
                  ? (value) => setState(() => _viewMode = value)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _videoStatusLabel(String label) {
    if (!widget.janusWsUrl.isNullOrEmpty && _playing) return 'LIVE';
    if (label.contains('失败') || label.contains('错误')) return 'ERROR';
    if (_busy || label.contains('请求') || label.contains('启动')) {
      return 'STARTING';
    }
    if (!widget.janusWsUrl.isNullOrEmpty) return 'STANDBY';
    return 'OFFLINE';
  }

  Color _videoStatusColor({
    required bool connected,
    required bool playing,
    required String label,
  }) {
    if (!connected) return AppTheme.slate500;
    if (label.contains('失败') || label.contains('错误')) return AppTheme.danger;
    if (_busy || label.contains('请求') || label.contains('启动')) {
      return AppTheme.warning;
    }
    return playing ? AppTheme.danger : AppTheme.slate500;
  }
}

extension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}

class _VideoPlayButton extends StatelessWidget {
  final bool playing;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  const _VideoPlayButton({
    required this.playing,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = playing ? AppTheme.danger : AppTheme.primaryColor;
    return FilledButton.tonalIcon(
      onPressed: enabled && !busy ? onPressed : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(92, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: activeColor.withValues(alpha: 0.14),
        foregroundColor: activeColor,
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 18,
            ),
      label: Text(playing ? '停止' : '播放'),
    );
  }
}

class _VideoControlBar extends StatelessWidget {
  final bool connected;
  final bool playing;
  final String viewMode;
  final bool busy;
  final VoidCallback onPlayToggle;
  final ValueChanged<String>? onViewModeChanged;

  const _VideoControlBar({
    required this.connected,
    required this.playing,
    required this.viewMode,
    required this.busy,
    required this.onPlayToggle,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final selector = _ViewModeSelector(
          value: viewMode,
          enabled: playing,
          onChanged: onViewModeChanged,
        );
        final playButton = _VideoPlayButton(
          playing: playing,
          busy: busy,
          enabled: connected,
          onPressed: onPlayToggle,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [playButton, const Spacer(), selector]),
            ],
          );
        }

        return Row(
          children: [
            const Spacer(),
            playButton,
            const SizedBox(width: 8),
            selector,
          ],
        );
      },
    );
  }
}

class _ViewModeSelector extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const _ViewModeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context).withValues(alpha: 0.72),
        border: Border.all(color: AppTheme.borderColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeButton(
            value: 'both',
            selected: value == 'both',
            enabled: enabled,
            tooltip: '显示双路',
            icon: Icons.view_column_rounded,
            onChanged: onChanged,
          ),
          _ViewModeButton(
            value: 'left',
            selected: value == 'left',
            enabled: enabled,
            tooltip: '只看左路',
            icon: Icons.keyboard_double_arrow_left_rounded,
            onChanged: onChanged,
          ),
          _ViewModeButton(
            value: 'right',
            selected: value == 'right',
            enabled: enabled,
            tooltip: '只看右路',
            icon: Icons.keyboard_double_arrow_right_rounded,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final String value;
  final bool selected;
  final bool enabled;
  final String tooltip;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  const _ViewModeButton({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.tooltip,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppTheme.primaryColor
        : AppTheme.mutedText(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: enabled ? () => onChanged?.call(value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 40,
          height: 34,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 19,
            color: enabled ? color : AppTheme.slate500.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _StreamPane extends StatelessWidget {
  final String label;
  final JanusVideoController controller;
  final String placeholder;

  const _StreamPane({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoViewWidget(
          renderer: controller.renderer,
          placeholderText: placeholder,
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: ValueListenableBuilder<String>(
            valueListenable: controller.status,
            builder: (context, status, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$label · $status',
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeleopCard extends StatelessWidget {
  final DashboardState data;
  final WsConnectionManager wsManager;
  final double speedMultiplier;

  const _TeleopCard({
    required this.data,
    required this.wsManager,
    required this.speedMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      title: '遥控',
      icon: Icons.gamepad_outlined,
      child: Column(
        children: [
          Center(
            child: JoystickWidget(
              size: 136,
              baseColor: AppTheme.primaryColor.withValues(alpha: 0.08),
              onMove: (x, y) {
                // 左摇杆：线速度（y 轴），角速度（x 轴）
                wsManager.sendCmdVel(
                  -y * speedMultiplier * 1.0, // linear_x
                  -x * speedMultiplier * 1.5, // angular_z
                );
              },
              onRelease: wsManager.sendStop,
            ),
          ),
          if (data.motionItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MotionActions(data: data),
          ],
        ],
      ),
    );
  }
}

class _MotionActions extends ConsumerWidget {
  final DashboardState data;

  const _MotionActions({required this.data});

  static const labels = {
    'stand_up': '站起',
    'sit_down': '趴下',
    'stop': '停止',
    'emergency_stop': '急停',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motionRunning =
        data.servicesStatus?['motion']?['status'] == 'running';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: data.motionItems.map((item) {
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) return const SizedBox.shrink();
        final pending = data.pendingActions.contains('motion-action:$id');
        return OutlinedButton(
          onPressed: !motionRunning || pending
              ? null
              : () => ref.read(dashboardProvider.notifier).triggerMotion(id),
          child: Text(pending ? '...' : (labels[id] ?? id)),
        );
      }).toList(),
    );
  }
}

class _SystemMetricsCard extends StatelessWidget {
  final DashboardState data;
  const _SystemMetricsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final hub = data.hubInfo;
    return ConsoleCard(
      title: '系统状态',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hub == null)
            EmptyState(icon: Icons.hourglass_top, label: '加载中...')
          else ...[
            _MetricRow(
              label: 'CPU',
              value: '${hub.cpuUsage.toStringAsFixed(1)}%',
              progress: hub.cpuUsage / 100,
              color: hub.cpuUsage > 80
                  ? AppTheme.danger
                  : AppTheme.primaryColor,
            ),
            const SizedBox(height: 8),
            _MetricRow(
              label: '内存',
              value:
                  '${(hub.memUsedMb / 1024).toStringAsFixed(1)} / ${(hub.memTotalMb / 1024).toStringAsFixed(1)} GB',
              progress: hub.memUsedMb / hub.memTotalMb,
              color: AppTheme.success,
            ),
          ],
          if (data.robotInfo?.battery != null) ...[
            const SizedBox(height: 8),
            _MetricRow(
              label: '电量',
              value: '${data.robotInfo!.battery}%',
              progress: (data.robotInfo!.battery ?? 0) / 100,
              color: AppTheme.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return MetricStrip(
      label: label,
      value: value,
      progress: progress,
      color: color,
    );
  }
}

class _ServicesCard extends ConsumerWidget {
  final DashboardState data;
  const _ServicesCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = data.servicesStatus;
    return ConsoleCard(
      title: '设备功能',
      icon: Icons.power_settings_new,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServiceRow(
            label: '运动控制',
            icon: Icons.radio_button_checked,
            status: _displayServiceStatus(
              'motion',
              status?['motion']?['status'],
            ),
            running: _serviceRunning(status?['motion']),
            pending: data.pendingActions.contains('motion'),
            onToggle: (v) => ref
                .read(dashboardProvider.notifier)
                .toggleMotion(v, adapter: data.selectedMotionAdapter),
          ),
          if (!_serviceRunning(status?['motion'])) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: data.motionAdapters.map((adapter) {
                return ChoiceChip(
                  label: Text(adapter),
                  selected: data.selectedMotionAdapter == adapter,
                  onSelected: (_) => ref
                      .read(dashboardProvider.notifier)
                      .selectMotionAdapter(adapter),
                );
              }).toList(),
            ),
          ] else if (data.activeMotionAdapter.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '当前适配器 · ${data.activeMotionAdapter}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          _ServiceRow(
            label: '定位扫描',
            icon: Icons.navigation_outlined,
            status: _displayServiceStatus(
              'scan',
              status?['scan']?['status'],
              scanStarting: data.scanStarting,
            ),
            running: _serviceRunning(status?['scan']) || data.scanStarting,
            pending: data.pendingActions.contains('scan'),
            onToggle: (v) => ref.read(dashboardProvider.notifier).toggleScan(v),
          ),
          if (status?['scan']?['detail']?['services'] is List)
            _ScanSubServices(
              items: status!['scan']['detail']['services'] as List<dynamic>,
            ),
          _ServiceRow(
            label: '语义建图',
            icon: Icons.document_scanner_outlined,
            status: _displayServiceStatus(
              'semantic',
              status?['semantic']?['status'],
            ),
            running: _serviceRunning(status?['semantic']),
            pending: data.pendingActions.contains('semantic'),
            onToggle: (v) =>
                ref.read(dashboardProvider.notifier).toggleSemantic(v),
          ),
        ],
      ),
    );
  }

  bool _serviceRunning(dynamic service) => service?['status'] == 'running';

  String _displayServiceStatus(
    String id,
    dynamic raw, {
    bool scanStarting = false,
  }) {
    if (id == 'scan' && scanStarting && raw != 'running') return 'starting';
    switch (raw) {
      case 'running':
        return 'active';
      case 'stopped':
        return 'stopped';
      case 'degraded':
        return id == 'scan' ? 'degraded' : 'stopped';
      default:
        return 'offline';
    }
  }
}

class _ServiceRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String status;
  final bool running;
  final bool pending;
  final void Function(bool) onToggle;

  const _ServiceRow({
    required this.label,
    required this.icon,
    required this.status,
    required this.running,
    required this.pending,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context).withValues(alpha: 0.72),
        border: Border.all(color: AppTheme.borderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: running ? AppTheme.primaryColor : AppTheme.slate500,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: running
                            ? AppTheme.success
                            : status == 'starting' || status == 'degraded'
                            ? AppTheme.warning
                            : AppTheme.slate500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status.toUpperCase(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (pending)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(value: running, onChanged: onToggle),
        ],
      ),
    );
  }
}

class _ScanSubServices extends StatelessWidget {
  final List<dynamic> items;

  const _ScanSubServices({required this.items});

  static const labels = {
    'websocket-server': 'WebSocket 服务',
    'gs-receiver': 'GS 接收器',
    'sensors-tower': '传感器塔',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
      child: Column(
        children: items.map((item) {
          final map = item as Map<String, dynamic>;
          final name = map['name']?.toString() ?? '';
          final state = (map['lifecycle_state'] ?? map['state'] ?? 'UNKNOWN')
              .toString();
          final normalized = state.toLowerCase();
          final color = normalized == 'running' || normalized == 'run'
              ? AppTheme.success
              : normalized == 'starting' ||
                    normalized == 'init' ||
                    normalized == 'ready'
              ? AppTheme.warning
              : AppTheme.slate500;
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labels[name] ?? name,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  state.toUpperCase(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ModelContainersCard extends ConsumerWidget {
  final DashboardState data;
  const _ModelContainersCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConsoleCard(
      title: '模型容器',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.modelContainers.isEmpty)
            const EmptyState(icon: Icons.inventory_2_outlined, label: '无模型容器')
          else
            ...data.modelContainers.map(
              (c) => _ContainerRow(
                container: c,
                onToggle: () =>
                    ref.read(dashboardProvider.notifier).toggleContainer(c),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContainerRow extends StatelessWidget {
  final ContainerInfo container;
  final VoidCallback onToggle;

  const _ContainerRow({required this.container, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final state = container.state.toUpperCase();
    final running = state == 'RUNNING' || state == 'HEALTHY';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: running ? AppTheme.success : AppTheme.slate500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              container.name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (container.allowManualStop)
            Switch(value: running, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}
