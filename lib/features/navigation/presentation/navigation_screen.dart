import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../shared/domain/app_models.dart';
import '../../../shared/widgets/console_widgets.dart';
import '../../../shared/widgets/occupancy_map.dart';
import 'navigation_provider.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _cyclesController = TextEditingController(text: '1');
  final _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cyclesController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final mode = NavMode.values[_tabController.index];
      ref.read(navigationProvider.notifier).setNavMode(mode);
    }
  }

  // ─── Status helpers ─────────────────────────────────────────

  Color _statusColor(NavigationStatus status) {
    switch (status) {
      case NavigationStatus.navigating:
        return AppTheme.primaryColor;
      case NavigationStatus.arrived:
        return AppTheme.success;
      case NavigationStatus.failed:
        return AppTheme.danger;
      case NavigationStatus.paused:
        return AppTheme.warning;
      case NavigationStatus.stopped:
        return AppTheme.slate500;
      case NavigationStatus.vacant:
        return AppTheme.slate400;
    }
  }

  String _statusLabel(NavigationStatus status) {
    switch (status) {
      case NavigationStatus.navigating:
        return '导航中';
      case NavigationStatus.arrived:
        return '已到达';
      case NavigationStatus.failed:
        return '失败';
      case NavigationStatus.paused:
        return '已暂停';
      case NavigationStatus.stopped:
        return '已停止';
      case NavigationStatus.vacant:
        return '空闲';
    }
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final navAsync = ref.watch(navigationProvider);

    return navAsync.when(
      loading: () => const ConsoleScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ConsoleScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text('加载失败: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(navigationProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      data: (navState) {
        switch (navState.viewState) {
          case NavViewState.checking:
            return const ConsoleScaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case NavViewState.setup:
            return _buildSetupScreen(navState);
          case NavViewState.active:
            return _buildActiveScreen(navState);
        }
      },
    );
  }

  // ─── Setup screen ───────────────────────────────────────────

  Widget _buildSetupScreen(NavigationState navState) {
    return ConsoleScaffold(
      appBar: AppBar(
        title: const ConsoleAppBarTitle(
          title: '导航配置',
          subtitle: 'map selection',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConsoleCard(
            title: '启动导航',
            icon: Icons.route_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error banner
                if (navState.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      navState.error!,
                      style: const TextStyle(color: AppTheme.danger),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('选择地图', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(navState.selectedMap),
                  isExpanded: true,
                  initialValue: navState.selectedMap,
                  hint: const Text('请选择地图'),
                  items: navState.maps.map((m) {
                    return DropdownMenuItem<String>(
                      value: m.name,
                      child: Text(m.name),
                    );
                  }).toList(),
                  onChanged: navState.loading
                      ? null
                      : (name) {
                          if (name != null) {
                            ref
                                .read(navigationProvider.notifier)
                                .selectMap(name);
                          }
                        },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('重定位模式'),
                    const Spacer(),
                    Switch(
                      value: navState.relocalization,
                      onChanged: navState.loading
                          ? null
                          : (_) => ref
                                .read(navigationProvider.notifier)
                                .toggleRelocalization(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: navState.loading || navState.selectedMap == null
                      ? null
                      : () => ref
                            .read(navigationProvider.notifier)
                            .startNavContainer(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: navState.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('启动导航', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Active screen ──────────────────────────────────────────

  Widget _buildActiveScreen(NavigationState navState) {
    return ConsoleScaffold(
      appBar: AppBar(
        title: const ConsoleAppBarTitle(title: '导航', subtitle: 'live map'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: StatusPill(
              label: _statusLabel(navState.navStatus),
              color: _statusColor(navState.navStatus),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map area
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: ConsoleCard(
                title: '地图画布',
                icon: Icons.public_outlined,
                padding: EdgeInsets.zero,
                child: _buildMapArea(navState),
              ),
            ),
          ),
          // Control panel
          ConsoleCard(
            title: '任务控制',
            icon: Icons.tune_outlined,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '单点'),
                    Tab(text: '路径'),
                    Tab(text: '录制'),
                  ],
                ),
                SizedBox(
                  height: 186,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSinglePointTab(navState),
                      _buildPathTab(navState),
                      _buildRecordTab(navState),
                    ],
                  ),
                ),
                _buildControlRow(navState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Map area ───────────────────────────────────────────────

  Widget _buildMapArea(NavigationState navState) {
    final notifier = ref.read(navigationProvider.notifier);

    Widget mapWidget = OccupancyMap(
      pgmBytes: navState.pgmBytes,
      meta: navState.mapMeta,
      robotPose: navState.robotPose,
      trajectory: navState.trajectory,
      goalPoint: navState.goalPoint,
      waypoints: navState.waypoints.map((w) => (w.x, w.y)).toList(),
      plannedPath: navState.plannedPath,
      onTapWorld: (wx, wy) {
        if (navState.navMode == NavMode.singlePoint) {
          notifier.navigateTo(wx, wy);
        } else if (navState.navMode == NavMode.path ||
            navState.navMode == NavMode.record) {
          notifier.addWaypoint(wx, wy);
        }
      },
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(13),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 8.0,
          child: mapWidget,
        ),
      ),
    );
  }

  // ─── Single point tab ───────────────────────────────────────

  Widget _buildSinglePointTab(NavigationState navState) {
    final goal = navState.goalPoint;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (goal != null)
            Text(
              '目标点: (${goal.$1.toStringAsFixed(2)}, ${goal.$2.toStringAsFixed(2)}, θ=${goal.$3.toStringAsFixed(2)})',
              style: const TextStyle(fontSize: 13),
            )
          else
            Text(
              '点击地图选择目标点',
              style: TextStyle(color: AppTheme.mutedText(context)),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: goal == null
                ? null
                : () => ref
                      .read(navigationProvider.notifier)
                      .navigateTo(goal.$1, goal.$2),
            icon: const Icon(Icons.navigation, size: 16),
            label: const Text('开始导航'),
          ),
        ],
      ),
    );
  }

  // ─── Path tab ───────────────────────────────────────────────

  Widget _buildPathTab(NavigationState navState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: navState.waypoints.isEmpty
                      ? Center(
                          child: Text(
                            '点击地图添加航点',
                            style: TextStyle(
                              color: AppTheme.mutedText(context),
                            ),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: navState.waypoints.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final w = navState.waypoints[i];
                            return Chip(
                              label: Text(
                                'P${i + 1} (${w.x.toStringAsFixed(1)},${w.y.toStringAsFixed(1)})',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onDeleted: () => ref
                                  .read(navigationProvider.notifier)
                                  .removeWaypoint(i),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('循环次数', style: TextStyle(fontSize: 11)),
                  SizedBox(
                    width: 60,
                    height: 36,
                    child: TextField(
                      controller: _cyclesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: navState.waypoints.isEmpty
                ? null
                : () {
                    final cycles = int.tryParse(_cyclesController.text) ?? 1;
                    ref.read(navigationProvider.notifier).startPathNav(cycles);
                  },
            icon: const Icon(Icons.route, size: 16),
            label: const Text('开始路径导航'),
          ),
        ],
      ),
    );
  }

  // ─── Record tab ─────────────────────────────────────────────

  Widget _buildRecordTab(NavigationState navState) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '已录制 ${navState.waypoints.length} 个航点',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '点击地图记录机器人经过的路径点',
            style: TextStyle(color: AppTheme.mutedText(context), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: navState.waypoints.isEmpty
                    ? null
                    : () {
                        // Clear all recorded waypoints
                        for (
                          var i = navState.waypoints.length - 1;
                          i >= 0;
                          i--
                        ) {
                          ref
                              .read(navigationProvider.notifier)
                              .removeWaypoint(i);
                        }
                      },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('清除'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: navState.waypoints.isEmpty
                    ? null
                    : () {
                        final cycles =
                            int.tryParse(_cyclesController.text) ?? 1;
                        ref
                            .read(navigationProvider.notifier)
                            .startPathNav(cycles);
                      },
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('执行路径'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Control row ────────────────────────────────────────────

  Widget _buildControlRow(NavigationState navState) {
    final status = navState.navStatus;
    final isNavigating = status == NavigationStatus.navigating;
    final isPaused = status == NavigationStatus.paused;
    final notifier = ref.read(navigationProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context).withValues(alpha: 0.82),
        border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
      ),
      child: Row(
        children: [
          // Pause / Resume
          if (isNavigating)
            _ControlButton(
              icon: Icons.pause,
              label: '暂停',
              color: AppTheme.warning,
              onPressed: notifier.pause,
            )
          else if (isPaused)
            _ControlButton(
              icon: Icons.play_arrow,
              label: '继续',
              color: AppTheme.primaryColor,
              onPressed: notifier.resume,
            )
          else
            const SizedBox(width: 60),
          const Spacer(),
          // Return to origin
          _ControlButton(
            icon: Icons.home,
            label: '回原点',
            color: AppTheme.success,
            onPressed: notifier.returnToOrigin,
          ),
          const SizedBox(width: 12),
          // Stop navigation
          _ControlButton(
            icon: Icons.stop,
            label: '停止导航',
            color: AppTheme.danger,
            onPressed: notifier.stopNav,
          ),
        ],
      ),
    );
  }
}

// ─── Helper widget ───────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.44)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
