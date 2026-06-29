import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../../../shared/widgets/console_widgets.dart';
import '../../../shared/widgets/joystick_widget.dart';
import '../../../shared/widgets/occupancy_map.dart';
import '../../../shared/widgets/point_cloud_viewer.dart';
import '../../../shared/widgets/video_view_widget.dart';
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
  final _routeNameController = TextEditingController();
  final _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cyclesController.dispose();
    _routeNameController.dispose();
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
          const SizedBox(height: 12),
          _buildNavParamsCard(navState),
        ],
      ),
    );
  }

  Widget _buildNavParamsCard(NavigationState navState) {
    final notifier = ref.read(navigationProvider.notifier);
    return ConsoleCard(
      title: '导航参数',
      icon: Icons.tune_outlined,
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (navState.navParamsDirty)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '参数有未应用修改，启动导航不会自动保存这些参数',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (navState.navParamsMessage != null) ...[
              Text(
                navState.navParamsMessage!,
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const TabBar(
              tabs: [
                Tab(text: '本体'),
                Tab(text: '绕障'),
                Tab(text: '停障'),
              ],
            ),
            SizedBox(
              height: 312,
              child: TabBarView(
                children: [
                  _buildRobotParamTab(navState.navParams),
                  _buildFreeParamTab(navState.navParams),
                  _buildFixedParamTab(navState.navParams),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: navState.loading
                        ? null
                        : notifier.reloadSavedNavParams,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('加载已保存'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: navState.loading
                        ? null
                        : notifier.applyNavParams,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('应用参数'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRobotParamTab(NavParamForm params) {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        _ParamNumberField(
          label: '雷达高度',
          unit: 'm',
          value: params.lidarHeight,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.lidarHeight, value),
        ),
        _ParamNumberField(
          label: '本体长度',
          unit: 'm',
          value: params.robotLength,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.robotLength, value),
        ),
        _ParamNumberField(
          label: '本体宽度',
          unit: 'm',
          value: params.robotWidth,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.robotWidth, value),
        ),
        _ParamNumberField(
          label: '设备前向距离',
          unit: 'm',
          value: params.deviceFrontDistance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.deviceFrontDistance, value),
        ),
        _ParamNumberField(
          label: '设备左向距离',
          unit: 'm',
          value: params.deviceLeftDistance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.deviceLeftDistance, value),
        ),
      ],
    );
  }

  Widget _buildFreeParamTab(NavParamForm params) {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        _ParamNumberField(
          label: '最低障碍高度',
          unit: 'm',
          value: params.freeMinObstacleHeight,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.freeMinObstacleHeight, value),
        ),
        _ParamNumberField(
          label: '最高障碍高度',
          unit: 'm',
          value: params.freeMaxObstacleHeight,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.freeMaxObstacleHeight, value),
        ),
        _ParamNumberField(
          label: '最大线速度',
          unit: 'm/s',
          value: params.freeLinearSpeed,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.freeLinearSpeed, value),
        ),
        _ParamNumberField(
          label: '最大角速度',
          unit: 'rad/s',
          value: params.freeAngularSpeed,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.freeAngularSpeed, value),
        ),
        _ParamNumberField(
          label: '到点距离',
          unit: 'm',
          value: params.freeXyGoalTolerance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.freeXyGoalTolerance, value),
        ),
        _ParamNumberField(
          label: '到点角度',
          unit: 'rad',
          value: params.freeYawGoalTolerance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.freeYawGoalTolerance, value),
        ),
        _ParamNumberField(
          label: '安全距离',
          unit: 'm',
          value: params.freeSafetyDistance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.freeSafetyDistance, value),
        ),
      ],
    );
  }

  Widget _buildFixedParamTab(NavParamForm params) {
    return ListView(
      padding: const EdgeInsets.only(top: 12),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('全向控制'),
          value: params.holonomic,
          onChanged: (value) =>
              ref.read(navigationProvider.notifier).setHolonomic(value),
        ),
        _ParamNumberField(
          label: '最大线速度',
          unit: 'm/s',
          value: params.fixedMaxLinearSpeed,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.fixedMaxLinearSpeed, value),
        ),
        _ParamNumberField(
          label: '最大角速度',
          unit: 'rad/s',
          value: params.fixedMaxAngularSpeed,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.fixedMaxAngularSpeed, value),
        ),
        _ParamNumberField(
          label: '到点距离',
          unit: 'm',
          value: params.fixedXyGoalTolerance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.fixedXyGoalTolerance, value),
        ),
        _ParamNumberField(
          label: '到点角度',
          unit: 'rad',
          value: params.fixedYawGoalTolerance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.fixedYawGoalTolerance, value),
        ),
        _ParamNumberField(
          label: '侧向安全距',
          unit: 'm',
          value: params.fixedLateralSafetyDistance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.fixedLateralSafetyDistance, value),
        ),
        _ParamNumberField(
          label: '前向停车距',
          unit: 'm',
          value: params.fixedForwardSafetyDistance,
          onChanged: (value) => ref
              .read(navigationProvider.notifier)
              .updateNavParam(NavParamField.fixedForwardSafetyDistance, value),
        ),
      ],
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
          _buildSafetyBar(navState),
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
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: '单点'),
                    Tab(text: '路径'),
                    Tab(text: '录制'),
                    Tab(text: '重定位'),
                    Tab(text: '路线'),
                  ],
                ),
                SizedBox(
                  height: 214,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSinglePointTab(navState),
                      _buildPathTab(navState),
                      _buildRecordTab(navState),
                      _buildRelocalizationTab(navState),
                      _buildSavedRoutesTab(navState),
                    ],
                  ),
                ),
                _buildControlRow(navState),
                _buildAuxiliaryRow(navState),
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
      goalPoint: navState.navMode == NavMode.relocalize
          ? navState.relocalizationPose
          : navState.goalPoint,
      waypoints: navState.waypoints.map((w) => (w.x, w.y)).toList(),
      plannedPath: navState.plannedPath,
      onTapWorld: (wx, wy) {
        if (navState.navMode == NavMode.singlePoint) {
          notifier.setGoalPoint(wx, wy);
        } else if (navState.navMode == NavMode.path ||
            navState.navMode == NavMode.record) {
          notifier.addWaypoint(wx, wy);
        } else if (navState.navMode == NavMode.relocalize) {
          notifier.setRelocalizationPose(wx, wy);
        }
      },
      onPoseSelected: (wx, wy, theta) {
        if (navState.navMode == NavMode.singlePoint) {
          notifier.setGoalPoint(wx, wy, theta: theta);
        } else if (navState.navMode == NavMode.relocalize) {
          notifier.setRelocalizationPose(wx, wy, theta: theta);
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
    final missionActive = navState.activeMission?.isActive == true;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SegmentedButton<SingleMissionMode>(
            segments: const [
              ButtonSegment(
                value: SingleMissionMode.standard,
                label: Text('绕障'),
                icon: Icon(Icons.route, size: 16),
              ),
              ButtonSegment(
                value: SingleMissionMode.direct,
                label: Text('停障'),
                icon: Icon(Icons.linear_scale, size: 16),
              ),
            ],
            selected: {navState.singleMissionMode},
            showSelectedIcon: false,
            onSelectionChanged: missionActive || navState.loading
                ? null
                : (values) => ref
                      .read(navigationProvider.notifier)
                      .setSingleMissionMode(values.first),
          ),
          const SizedBox(height: 10),
          if (goal != null)
            Text(
              '目标: x=${goal.$1.toStringAsFixed(2)}  y=${goal.$2.toStringAsFixed(2)}  θ=${goal.$3.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13),
            )
          else
            Text(
              '点击地图选点，长按拖拽设置方向',
              style: TextStyle(color: AppTheme.mutedText(context)),
            ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: goal == null || missionActive || navState.loading
                ? null
                : () => ref
                      .read(navigationProvider.notifier)
                      .startSingleMission(),
            icon: const Icon(Icons.navigation, size: 16),
            label: Text(missionActive ? '任务执行中' : '开始导航'),
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

  Widget _buildRelocalizationTab(NavigationState navState) {
    final pose = navState.relocalizationPose;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (pose == null)
            Text(
              '点击地图选初始位置，长按拖拽设置方向',
              style: TextStyle(color: AppTheme.mutedText(context)),
            )
          else
            Text(
              '初始位姿: x=${pose.$1.toStringAsFixed(2)}  y=${pose.$2.toStringAsFixed(2)}  θ=${pose.$3.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: pose == null || navState.loading
                ? null
                : () => ref
                      .read(navigationProvider.notifier)
                      .submitRelocalizationPose(),
            icon: const Icon(Icons.my_location, size: 16),
            label: const Text('提交初始位姿'),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRoutesTab(NavigationState navState) {
    final notifier = ref.read(navigationProvider.notifier);
    final missionActive = navState.activeMission?.isActive == true;
    final cycles = int.tryParse(_cyclesController.text) ?? 1;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _routeNameController,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '路线名称',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: navState.loading || navState.waypoints.length < 2
                    ? null
                    : () =>
                          notifier.saveCurrentRoute(_routeNameController.text),
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: navState.savedRoutes.isEmpty
                ? Center(
                    child: Text(
                      '当前地图暂无保存路线',
                      style: TextStyle(color: AppTheme.mutedText(context)),
                    ),
                  )
                : ListView.separated(
                    itemCount: navState.savedRoutes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final route = navState.savedRoutes[index];
                      return _SavedRouteTile(
                        route: route,
                        disabled: navState.loading,
                        missionActive: missionActive,
                        onStart: () => notifier.startSavedRoute(route, cycles),
                        onLoad: () {
                          notifier.loadSavedRoute(route);
                          _tabController.animateTo(NavMode.path.index);
                        },
                      );
                    },
                  ),
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
        ],
      ),
    );
  }

  Widget _buildAuxiliaryRow(NavigationState navState) {
    final wsManager = ref.watch(wsManagerProvider);
    final activeConnection = ref.watch(activeConnectionProvider);
    final pointCloudWsUrl = _navWsUrl(activeConnection?.baseUrl);
    final janusWsUrl = _janusWsUrl(activeConnection?.baseUrl);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showTeleopSheet(wsManager),
              icon: const Icon(Icons.gamepad_outlined, size: 18),
              label: const Text('遥控器'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: pointCloudWsUrl == null
                  ? null
                  : () => _showPointCloudSheet(pointCloudWsUrl),
              icon: const Icon(Icons.blur_on_outlined, size: 18),
              label: const Text('点云'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: janusWsUrl == null
                  ? null
                  : () => _showVideoSheet(janusWsUrl),
              icon: const Icon(Icons.videocam_outlined, size: 18),
              label: const Text('视频流'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyBar(NavigationState navState) {
    final notifier = ref.read(navigationProvider.notifier);
    final mission = navState.activeMission;
    final missionLabel = mission == null
        ? '无任务'
        : '${mission.mode ?? 'mission'} · ${mission.status}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: StatusPill(
              label: missionLabel,
              color: mission?.isActive == true
                  ? AppTheme.primaryColor
                  : AppTheme.slate500,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: navState.loading ? null : notifier.stopTask,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text('停止任务'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: navState.loading ? null : _confirmCloseNavigation,
            icon: const Icon(Icons.power_settings_new, size: 18),
            label: const Text('关闭导航'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCloseNavigation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关闭导航'),
        content: const Text('将停止当前任务并关闭导航容器，确认继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(navigationProvider.notifier).closeNavigation();
    }
  }

  void _showPointCloudSheet(String wsUrl) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: _NavigationPointCloudCard(wsUrl: wsUrl),
          ),
        ),
      ),
    );
  }

  void _showTeleopSheet(WsConnectionManager wsManager) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: _NavigationTeleopCard(wsManager: wsManager),
          ),
        ),
      ),
    );
  }

  void _showVideoSheet(String janusWsUrl) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: _NavigationVideoCard(janusWsUrl: janusWsUrl),
          ),
        ),
      ),
    );
  }

  String? _navWsUrl(String? baseUrl) {
    if (baseUrl == null || baseUrl.isEmpty) return null;
    final uri = Uri.parse(baseUrl);
    return Uri(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      host: uri.host,
      port: 9089,
    ).toString();
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

// ─── Helper widget ───────────────────────────────────────────

class _SavedRouteTile extends StatelessWidget {
  final NavLandmark route;
  final bool disabled;
  final bool missionActive;
  final VoidCallback onStart;
  final VoidCallback onLoad;

  const _SavedRouteTile({
    required this.route,
    required this.disabled,
    required this.missionActive,
    required this.onStart,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context).withValues(alpha: 0.72),
        border: Border.all(color: AppTheme.borderColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  route.name.isEmpty ? '未命名路线' : route.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${route.points.length} 个点',
                  style: TextStyle(
                    color: AppTheme.mutedText(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '加载到路径',
            onPressed: disabled ? null : onLoad,
            icon: const Icon(Icons.file_download_outlined),
          ),
          FilledButton.icon(
            onPressed: disabled || missionActive ? null : onStart,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('执行'),
          ),
        ],
      ),
    );
  }
}

class _NavigationPointCloudCard extends StatelessWidget {
  final String wsUrl;

  const _NavigationPointCloudCard({required this.wsUrl});

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      title: '点云',
      icon: Icons.blur_on_outlined,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: PointCloudViewer(
          wsUrl: wsUrl,
          pointCloudTopic: '/map_point_cloud',
          accumulate: true,
        ),
      ),
    );
  }
}

class _NavigationVideoCard extends StatefulWidget {
  final String janusWsUrl;

  const _NavigationVideoCard({required this.janusWsUrl});

  @override
  State<_NavigationVideoCard> createState() => _NavigationVideoCardState();
}

class _NavigationVideoCardState extends State<_NavigationVideoCard> {
  late final JanusVideoController _left;
  late final JanusVideoController _right;
  late final Future<void> _initFuture;
  bool _ready = false;
  bool _playing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _left = JanusVideoController(streamId: 100);
    _right = JanusVideoController(streamId: 101);
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([_left.initialize(), _right.initialize()]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    unawaited(_disposeControllers());
    super.dispose();
  }

  Future<void> _disposeControllers() async {
    try {
      await _initFuture;
    } catch (_) {}
    await Future.wait([_left.dispose(), _right.dispose()]);
  }

  Future<void> _play() async {
    if (_busy || !_ready) return;
    setState(() => _busy = true);
    try {
      await Future.wait([
        _connect(_left, widget.janusWsUrl),
        _connect(_right, widget.janusWsUrl),
      ]);
      if (mounted) setState(() => _playing = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(JanusVideoController controller, String url) async {
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
      if (mounted) setState(() => _playing = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      title: '视频流',
      icon: Icons.videocam_outlined,
      trailing: StatusPill(
        label: _playing
            ? 'LIVE'
            : _busy
            ? 'STARTING'
            : 'STANDBY',
        color: _playing
            ? AppTheme.danger
            : _busy
            ? AppTheme.warning
            : AppTheme.slate500,
      ),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Row(
                children: [
                  Expanded(
                    child: _NavigationStreamPane(label: '左', controller: _left),
                  ),
                  Expanded(
                    child: _NavigationStreamPane(
                      label: '右',
                      controller: _right,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _ready && !_busy ? (_playing ? _stop : _play) : null,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _playing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                label: Text(_playing ? '停止' : '播放'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationStreamPane extends StatelessWidget {
  final String label;
  final JanusVideoController controller;

  const _NavigationStreamPane({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoViewWidget(
          renderer: controller.renderer,
          placeholderText: 'NO SIGNAL',
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

class _NavigationTeleopCard extends StatefulWidget {
  final WsConnectionManager wsManager;

  const _NavigationTeleopCard({required this.wsManager});

  @override
  State<_NavigationTeleopCard> createState() => _NavigationTeleopCardState();
}

class _NavigationTeleopCardState extends State<_NavigationTeleopCard> {
  static const _maxLinear = 0.75;
  static const _maxAngular = 1.25;

  double _speed = 0.35;
  double _linear = 0;
  double _angular = 0;

  void _move(double x, double y) {
    final linear = -y * _maxLinear * _speed;
    final angular = -x * _maxAngular * _speed;
    setState(() {
      _linear = linear;
      _angular = angular;
    });
    widget.wsManager.sendCmdVel(linear, angular);
  }

  void _stop() {
    setState(() {
      _linear = 0;
      _angular = 0;
    });
    widget.wsManager.sendStop();
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      title: '遥控器',
      icon: Icons.gamepad_outlined,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          JoystickWidget(
            size: 178,
            stickColor: AppTheme.primaryColor,
            baseColor: AppTheme.subtleFill(context).withValues(alpha: 0.9),
            onMove: _move,
            onRelease: _stop,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('倍率', style: TextStyle(color: AppTheme.mutedText(context))),
              Expanded(
                child: Slider(
                  value: _speed,
                  min: 0.1,
                  max: 1,
                  divisions: 9,
                  onChanged: (value) => setState(() => _speed = value),
                ),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${(_speed * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'V ${_linear.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              Text(
                'W ${_angular.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('急停'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParamNumberField extends StatefulWidget {
  final String label;
  final String unit;
  final double value;
  final ValueChanged<double> onChanged;

  const _ParamNumberField({
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ParamNumberField> createState() => _ParamNumberFieldState();
}

class _ParamNumberFieldState extends State<_ParamNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _ParamNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.value != oldWidget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _format(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: widget.unit,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) {
          final parsed = double.tryParse(text);
          if (parsed != null) widget.onChanged(parsed);
        },
      ),
    );
  }
}

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
