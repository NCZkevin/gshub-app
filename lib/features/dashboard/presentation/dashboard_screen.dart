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
                speedMultiplier: _speedMultiplier,
                onSpeedChanged: (v) => setState(() => _speedMultiplier = v),
              )
            : _NarrowLayout(
                data: data,
                wsManager: wsManager,
                speedMultiplier: _speedMultiplier,
                onSpeedChanged: (v) => setState(() => _speedMultiplier = v),
              ),
      ),
    );
  }
}

// ─── 宽屏布局（平板/桌面）──────────────────────────────────────

class _WideLayout extends ConsumerWidget {
  final DashboardState data;
  final WsConnectionManager wsManager;
  final double speedMultiplier;
  final void Function(double) onSpeedChanged;

  const _WideLayout({
    required this.data,
    required this.wsManager,
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
                ConsoleCard(
                  title: '视频链路',
                  icon: Icons.videocam_outlined,
                  trailing: const StatusPill(
                    label: 'BUFFER',
                    color: AppTheme.warning,
                  ),
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    height: 250,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: const VideoViewWidget(
                        placeholderText: '视频流（接入 Janus 后显示）',
                      ),
                    ),
                  ),
                ),
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
  final double speedMultiplier;
  final void Function(double) onSpeedChanged;

  const _NarrowLayout({
    required this.data,
    required this.wsManager,
    required this.speedMultiplier,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ConsoleCard(
            title: '视频链路',
            icon: Icons.videocam_outlined,
            trailing: const StatusPill(
              label: 'BUFFER',
              color: AppTheme.warning,
            ),
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 210,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: const VideoViewWidget(
                  placeholderText: '视频流（接入 Janus 后显示）',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SystemMetricsCard(data: data),
          const SizedBox(height: 12),
          _TeleopCard(wsManager: wsManager, speedMultiplier: speedMultiplier),
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

class _TeleopCard extends StatelessWidget {
  final WsConnectionManager wsManager;
  final double speedMultiplier;

  const _TeleopCard({required this.wsManager, required this.speedMultiplier});

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
        ],
      ),
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
      title: '服务',
      icon: Icons.power_settings_new,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServiceRow(
            label: '运动控制',
            running: status?['motion']?['status'] == 'running',
            onToggle: (v) => ref
                .read(dashboardProvider.notifier)
                .toggleMotion(v, adapter: 'go2'),
          ),
          _ServiceRow(
            label: '定位扫描',
            running: status?['scan']?['status'] == 'running',
            onToggle: (_) {}, // 扫描服务简化处理
          ),
          _ServiceRow(
            label: '语义建图',
            running: status?['semantic']?['status'] == 'running',
            onToggle: (_) {},
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String label;
  final bool running;
  final void Function(bool) onToggle;

  const _ServiceRow({
    required this.label,
    required this.running,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: Text(label)),
          Switch(value: running, onChanged: onToggle),
        ],
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
    final running = container.state == 'running';
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
