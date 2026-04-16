import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        actions: [
          dashAsync.whenOrNull(
            data: (d) => d.robotInfo?.connected == true
                ? const Icon(Icons.wifi, color: Colors.green)
                : const Icon(Icons.wifi_off, color: Colors.red),
          ) ??
              const SizedBox.shrink(),
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
                    wsManager: wsManager, speedMultiplier: speedMultiplier),
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
                SizedBox(
                  height: 240,
                  child: Card(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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
          SizedBox(
            height: 200,
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const VideoViewWidget(
                    placeholderText: '视频流（接入 Janus 后显示）'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text('遥控', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Center(
              child: JoystickWidget(
                size: 130,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('系统状态', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (hub == null)
              const Text('加载中...', style: TextStyle(color: Colors.grey))
            else ...[
              _MetricRow(
                label: 'CPU',
                value: '${hub.cpuUsage.toStringAsFixed(1)}%',
                progress: hub.cpuUsage / 100,
                color: hub.cpuUsage > 80 ? Colors.red : Colors.cyan,
              ),
              const SizedBox(height: 8),
              _MetricRow(
                label: '内存',
                value:
                    '${(hub.memUsedMb / 1024).toStringAsFixed(1)} / ${(hub.memTotalMb / 1024).toStringAsFixed(1)} GB',
                progress: hub.memUsedMb / hub.memTotalMb,
                color: Colors.purple,
              ),
            ],
            if (data.robotInfo?.battery != null) ...[
              const SizedBox(height: 8),
              _MetricRow(
                label: '电量',
                value: '${data.robotInfo!.battery}%',
                progress: (data.robotInfo!.battery ?? 0) / 100,
                color: Colors.green,
              ),
            ],
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value)],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          color: color,
          backgroundColor: Colors.white12,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}

class _ServicesCard extends ConsumerWidget {
  final DashboardState data;
  const _ServicesCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = data.servicesStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('服务', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
              color: running ? Colors.green : Colors.grey,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('模型容器', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (data.modelContainers.isEmpty)
              const Text('无模型容器', style: TextStyle(color: Colors.grey))
            else
              ...data.modelContainers.map((c) => _ContainerRow(
                    container: c,
                    onToggle: () => ref
                        .read(dashboardProvider.notifier)
                        .toggleContainer(c),
                  )),
          ],
        ),
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
              color: running ? Colors.green : Colors.grey,
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
