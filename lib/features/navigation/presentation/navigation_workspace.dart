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
import 'navigation_workspace_provider.dart';

class NavigationWorkspace extends ConsumerStatefulWidget {
  final NavigationState navState;

  const NavigationWorkspace({super.key, required this.navState});

  @override
  ConsumerState<NavigationWorkspace> createState() =>
      _NavigationWorkspaceState();
}

class _NavigationWorkspaceState extends ConsumerState<NavigationWorkspace> {
  final _mapController = MapViewportController();
  final _pathCyclesController = TextEditingController(text: '1');
  final _savedCyclesController = TextEditingController(text: '1');
  final _pathNameController = TextEditingController();
  final _recordNameController = TextEditingController();

  @override
  void didUpdateWidget(covariant NavigationWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navState.robotPose != widget.navState.robotPose &&
        ref.read(navigationWorkspaceProvider).followRobot) {
      _centerOnRobot();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pathCyclesController.dispose();
    _savedCyclesController.dispose();
    _pathNameController.dispose();
    _recordNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(navigationDraftProvider);
    final workspace = ref.watch(navigationWorkspaceProvider);
    final media = MediaQuery.of(context);
    final splitLayout =
        media.orientation == Orientation.landscape || media.size.width >= 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmCloseNavigation());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: SafeArea(
          child: splitLayout
              ? _buildSplitLayout(draft, workspace)
              : _buildPortraitLayout(draft, workspace),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMap(draft, workspace),
        _buildDraggableTaskSheet(draft, workspace),
        _buildMapHud(),
        _buildMapToolbar(workspace),
        if (workspace.interactionMode != MapInteractionMode.browse)
          _buildInteractionHint(workspace),
      ],
    );
  }

  Widget _buildSplitLayout(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    return Row(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMap(draft, workspace),
              _buildMapHud(),
              _buildMapToolbar(workspace),
              if (workspace.interactionMode != MapInteractionMode.browse)
                _buildInteractionHint(workspace),
            ],
          ),
        ),
        Container(
          key: const Key('navigation-side-panel'),
          width: 380,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(left: BorderSide(color: Color(0xFF334155))),
          ),
          child: _buildTaskPanel(
            draft,
            workspace,
            scrollController: null,
            showHandle: false,
          ),
        ),
      ],
    );
  }

  Widget _buildMap(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    final waypoints = switch (workspace.mode) {
      NavMode.path => draft.pathWaypoints,
      NavMode.record => draft.recordWaypoints,
      NavMode.savedRoute => draft.selectedRoute?.points ?? const <Waypoint>[],
      _ => const <Waypoint>[],
    };
    final goal = switch (workspace.mode) {
      NavMode.singlePoint => draft.singleGoal,
      NavMode.relocalize => draft.relocationPose,
      _ => null,
    };

    return OccupancyMap(
      key: const Key('navigation-map'),
      pgmBytes: widget.navState.pgmBytes,
      meta: widget.navState.mapMeta,
      robotPose: widget.navState.robotPose,
      trajectory: widget.navState.trajectory,
      goalPoint: goal,
      waypoints: waypoints
          .map(
            (point) => MapSelection(x: point.x, y: point.y, theta: point.theta),
          )
          .toList(),
      plannedPath: widget.navState.plannedPath,
      interactionMode: widget.navState.activeMission?.isActive == true
          ? MapInteractionMode.browse
          : workspace.interactionMode,
      viewportController: _mapController,
      onViewportInteraction: () =>
          ref.read(navigationWorkspaceProvider.notifier).disableFollowRobot(),
      onSelection: _handleMapSelection,
    );
  }

  void _handleMapSelection(MapSelection selection) {
    if (widget.navState.activeMission?.isActive == true) return;
    final workspace = ref.read(navigationWorkspaceProvider);
    final draft = ref.read(navigationDraftProvider.notifier);
    final workspaceNotifier = ref.read(navigationWorkspaceProvider.notifier);

    switch (workspace.mode) {
      case NavMode.singlePoint:
        draft.setSingleGoal(selection);
        workspaceNotifier.cancelMapInteraction();
        break;
      case NavMode.path:
        draft.addPathWaypoint(selection);
        break;
      case NavMode.record:
        draft.addRecordWaypoint(selection);
        break;
      case NavMode.relocalize:
        draft.setRelocationPose(selection);
        workspaceNotifier.cancelMapInteraction();
        break;
      case NavMode.savedRoute:
        break;
    }
  }

  Widget _buildMapHud() {
    final state = widget.navState;
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _HudButton(
            key: const Key('close-navigation'),
            icon: Icons.close_rounded,
            tooltip: '关闭导航',
            onPressed: _confirmCloseNavigation,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GlassPanel(
              child: Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      state.selectedMap ?? '未选择地图',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: _runtimeStatusLabel(state),
                    color: _runtimeStatusColor(state),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapToolbar(NavigationWorkspaceState workspace) {
    final robotAvailable =
        widget.navState.robotPose != null && widget.navState.mapMeta != null;
    return Positioned(
      top: 72,
      right: 12,
      child: Column(
        children: [
          _HudButton(
            icon: Icons.fit_screen_rounded,
            tooltip: '适应地图',
            onPressed: _mapController.reset,
          ),
          const SizedBox(height: 8),
          _HudButton(
            icon: Icons.my_location_rounded,
            tooltip: '定位机器人',
            selected: workspace.followRobot,
            onPressed: robotAvailable ? _toggleFollowRobot : null,
          ),
          const SizedBox(height: 8),
          _GlassPanel(
            padding: EdgeInsets.zero,
            child: PopupMenuButton<NavigationAuxTool>(
              key: const Key('navigation-tools'),
              tooltip: '辅助工具',
              color: const Color(0xFF172033),
              icon: const Icon(Icons.widgets_outlined, color: Colors.white),
              onSelected: _openTool,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: NavigationAuxTool.teleop,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.gamepad_outlined),
                    title: Text('遥控器'),
                  ),
                ),
                PopupMenuItem(
                  value: NavigationAuxTool.pointCloud,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.blur_on_outlined),
                    title: Text('点云'),
                  ),
                ),
                PopupMenuItem(
                  value: NavigationAuxTool.video,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.videocam_outlined),
                    title: Text('视频流'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionHint(NavigationWorkspaceState workspace) {
    final label = switch (workspace.interactionMode) {
      MapInteractionMode.pickGoal => '轻触选择目标；长按拖动设置朝向',
      MapInteractionMode.addWaypoint => '连续轻触添加路径点；完成后退出选点',
      MapInteractionMode.pickRelocalization => '轻触选择初始位姿；长按拖动设置朝向',
      MapInteractionMode.browse => '',
    };
    return Positioned(
      top: 78,
      left: 12,
      right: 70,
      child: Align(
        alignment: Alignment.topCenter,
        child: _GlassPanel(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: AppTheme.warning,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: '退出选点',
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(navigationWorkspaceProvider.notifier)
                    .cancelMapInteraction(),
                icon: const Icon(Icons.close, size: 17, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTaskSheet(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    return DraggableScrollableSheet(
      key: ValueKey(workspace.sheetLevel),
      initialChildSize: workspace.sheetExtent,
      minChildSize: 0.16,
      maxChildSize: 0.82,
      snap: true,
      snapSizes: const [0.16, 0.38, 0.82],
      builder: (context, scrollController) => Container(
        key: const Key('navigation-task-sheet'),
        decoration: const BoxDecoration(
          color: Color(0xF20F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Color(0xFF475569), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: _buildTaskPanel(
          draft,
          workspace,
          scrollController: scrollController,
          showHandle: true,
        ),
      ),
    );
  }

  Widget _buildTaskPanel(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace, {
    required ScrollController? scrollController,
    required bool showHandle,
  }) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(14, showHandle ? 8 : 14, 14, 24),
      children: [
        if (showHandle)
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        _buildMissionSafetyBar(),
        const SizedBox(height: 10),
        _buildModeSelector(workspace),
        const SizedBox(height: 12),
        _buildModePanel(draft, workspace),
        if (widget.navState.error != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.navState.error!,
            style: const TextStyle(color: AppTheme.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildMissionSafetyBar() {
    final state = widget.navState;
    final notifier = ref.read(navigationProvider.notifier);
    final missionActive = state.activeMission?.isActive == true;
    final isNavigating = state.navStatus == NavigationStatus.navigating;
    final isPaused = state.navStatus == NavigationStatus.paused;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                missionActive ? '任务执行中' : '任务控制',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                state.activeMission == null
                    ? _taskStatusLabel(state)
                    : '${state.activeMission?.mode ?? 'mission'} · '
                          '${_missionStatusLabel(state.activeMission!.status)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ),
        if (isNavigating)
          _CompactAction(
            icon: Icons.pause_rounded,
            label: '暂停',
            color: AppTheme.warning,
            busy: state.isPending(NavigationCommand.pause),
            onPressed: notifier.pause,
          )
        else if (isPaused)
          _CompactAction(
            icon: Icons.play_arrow_rounded,
            label: '继续',
            color: AppTheme.primaryColor,
            busy: state.isPending(NavigationCommand.resume),
            onPressed: notifier.resume,
          ),
        const SizedBox(width: 7),
        _CompactAction(
          key: const Key('stop-navigation-task'),
          icon: Icons.stop_rounded,
          label: '停止',
          color: AppTheme.danger,
          busy: state.isPending(NavigationCommand.stop),
          onPressed: notifier.stopTask,
        ),
      ],
    );
  }

  Widget _buildModeSelector(NavigationWorkspaceState workspace) {
    final missionActive = widget.navState.activeMission?.isActive == true;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: NavMode.values.map((mode) {
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              key: Key('nav-mode-${mode.name}'),
              selected: workspace.mode == mode,
              label: Text(_modeLabel(mode)),
              avatar: Icon(_modeIcon(mode), size: 16),
              onSelected: missionActive
                  ? null
                  : (_) => ref
                        .read(navigationWorkspaceProvider.notifier)
                        .setMode(mode),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModePanel(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    return switch (workspace.mode) {
      NavMode.singlePoint => _buildSinglePanel(draft, workspace),
      NavMode.path => _buildPathPanel(draft, workspace),
      NavMode.record => _buildRecordPanel(draft, workspace),
      NavMode.relocalize => _buildRelocalizationPanel(draft, workspace),
      NavMode.savedRoute => _buildSavedRoutesPanel(draft),
    };
  }

  Widget _buildSinglePanel(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    final goal = draft.singleGoal;
    final disabled = _missionSubmitDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          selected: {draft.singleMissionMode},
          showSelectedIcon: false,
          onSelectionChanged: disabled
              ? null
              : (values) => ref
                    .read(navigationDraftProvider.notifier)
                    .setSingleMissionMode(values.first),
        ),
        const SizedBox(height: 10),
        _SelectionSummary(emptyText: '尚未设置导航目标', selection: goal, prefix: '目标'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pick-single-goal'),
                onPressed: disabled ? null : _toggleMapInteraction,
                icon: Icon(
                  workspace.interactionMode == MapInteractionMode.pickGoal
                      ? Icons.close
                      : Icons.add_location_alt_outlined,
                ),
                label: Text(
                  workspace.interactionMode == MapInteractionMode.pickGoal
                      ? '退出选点'
                      : '设置目标',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('start-single-navigation'),
                onPressed: goal == null || disabled
                    ? null
                    : () {
                        final point = Waypoint(
                          x: goal.x,
                          y: goal.y,
                          theta: goal.theta,
                        );
                        unawaited(
                          ref
                              .read(navigationProvider.notifier)
                              .startSingleMission(
                                mode: draft.singleMissionMode,
                                goal: point,
                              ),
                        );
                        _collapseForMission();
                      },
                icon: _missionButtonIcon,
                label: const Text('开始导航'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPathPanel(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    final disabled = _missionSubmitDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WaypointSummary(
          points: draft.pathWaypoints,
          emptyText: '尚未添加路径点',
          onDelete: disabled
              ? null
              : ref.read(navigationDraftProvider.notifier).removePathWaypoint,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pick-path-waypoints'),
                onPressed: disabled ? null : _toggleMapInteraction,
                icon: Icon(
                  workspace.interactionMode == MapInteractionMode.addWaypoint
                      ? Icons.check
                      : Icons.add_location_alt_outlined,
                ),
                label: Text(
                  workspace.interactionMode == MapInteractionMode.addWaypoint
                      ? '完成选点'
                      : '添加路径点',
                ),
              ),
            ),
            IconButton(
              tooltip: '撤销最后一点',
              onPressed: disabled || draft.pathWaypoints.isEmpty
                  ? null
                  : ref.read(navigationDraftProvider.notifier).undoPathWaypoint,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: '清空路径点',
              onPressed: disabled || draft.pathWaypoints.isEmpty
                  ? null
                  : ref.read(navigationDraftProvider.notifier).clearPath,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pathNameController,
                onChanged: ref
                    .read(navigationDraftProvider.notifier)
                    .setPathName,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '路线名称（保存时必填）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 82,
              child: _CyclesField(
                controller: _pathCyclesController,
                onChanged: ref
                    .read(navigationDraftProvider.notifier)
                    .setPathCycles,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    disabled ||
                        draft.pathWaypoints.length < 2 ||
                        _pathNameController.text.trim().isEmpty
                    ? null
                    : () => ref
                          .read(navigationProvider.notifier)
                          .saveCurrentRoute(
                            name: _pathNameController.text,
                            points: draft.pathWaypoints,
                          ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存路线'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('start-path-navigation'),
                onPressed: disabled || draft.pathWaypoints.isEmpty
                    ? null
                    : () {
                        unawaited(
                          ref
                              .read(navigationProvider.notifier)
                              .startPathNav(
                                waypoints: draft.pathWaypoints,
                                cycles: draft.pathCycles,
                              ),
                        );
                        _collapseForMission();
                      },
                icon: _missionButtonIcon,
                label: const Text('执行路径'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordPanel(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    final disabled = _missionSubmitDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '手动记录 ${draft.recordWaypoints.length} 个地图点',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _WaypointSummary(
          points: draft.recordWaypoints,
          emptyText: '点击“记录路径点”后在地图上连续选点',
          onDelete: disabled
              ? null
              : ref.read(navigationDraftProvider.notifier).removeRecordWaypoint,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pick-record-waypoints'),
                onPressed: disabled ? null : _toggleMapInteraction,
                icon: Icon(
                  workspace.interactionMode == MapInteractionMode.addWaypoint
                      ? Icons.check
                      : Icons.fiber_manual_record_outlined,
                ),
                label: Text(
                  workspace.interactionMode == MapInteractionMode.addWaypoint
                      ? '完成记录'
                      : '记录路径点',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '清空记录',
              onPressed: disabled || draft.recordWaypoints.isEmpty
                  ? null
                  : ref.read(navigationDraftProvider.notifier).clearRecord,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _recordNameController,
          onChanged: ref.read(navigationDraftProvider.notifier).setRecordName,
          decoration: const InputDecoration(
            isDense: true,
            labelText: '路线名称',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    disabled ||
                        draft.recordWaypoints.length < 2 ||
                        _recordNameController.text.trim().isEmpty
                    ? null
                    : () => ref
                          .read(navigationProvider.notifier)
                          .saveCurrentRoute(
                            name: _recordNameController.text,
                            points: draft.recordWaypoints,
                          ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存路线'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: disabled || draft.recordWaypoints.isEmpty
                    ? null
                    : () {
                        unawaited(
                          ref
                              .read(navigationProvider.notifier)
                              .startPathNav(
                                waypoints: draft.recordWaypoints,
                                cycles: 1,
                              ),
                        );
                        _collapseForMission();
                      },
                icon: _missionButtonIcon,
                label: const Text('执行路径'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelocalizationPanel(
    NavigationDraftState draft,
    NavigationWorkspaceState workspace,
  ) {
    final pose = draft.relocationPose;
    final disabled = _missionSubmitDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectionSummary(emptyText: '尚未设置初始位姿', selection: pose, prefix: '位姿'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pick-relocalization-pose'),
                onPressed: disabled ? null : _toggleMapInteraction,
                icon: Icon(
                  workspace.interactionMode ==
                          MapInteractionMode.pickRelocalization
                      ? Icons.close
                      : Icons.location_searching,
                ),
                label: Text(
                  workspace.interactionMode ==
                          MapInteractionMode.pickRelocalization
                      ? '退出选点'
                      : '设置初始位姿',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('submit-relocalization'),
                onPressed: pose == null || disabled
                    ? null
                    : () => ref
                          .read(navigationProvider.notifier)
                          .submitRelocalizationPose(
                            Waypoint(x: pose.x, y: pose.y, theta: pose.theta),
                          ),
                icon: widget.navState.isPending(NavigationCommand.relocalize)
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('提交位姿'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSavedRoutesPanel(NavigationDraftState draft) {
    final routes = widget.navState.savedRoutes;
    final disabled = _missionSubmitDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '已保存路线',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: '刷新路线',
              onPressed:
                  widget.navState.isPending(NavigationCommand.refreshRoutes)
                  ? null
                  : ref.read(navigationProvider.notifier).refreshSavedRoutes,
              icon: const Icon(Icons.refresh),
            ),
            SizedBox(
              width: 82,
              child: _CyclesField(
                controller: _savedCyclesController,
                onChanged: ref
                    .read(navigationDraftProvider.notifier)
                    .setSavedRouteCycles,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (routes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              '当前地图暂无保存路线',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ...routes.map(
            (route) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: draft.selectedRoute?.id == route.id
                    ? AppTheme.primaryColor.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.04),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: draft.selectedRoute?.id == route.id
                        ? AppTheme.primaryColor
                        : Colors.white12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  onTap: disabled
                      ? null
                      : () => ref
                            .read(navigationDraftProvider.notifier)
                            .selectSavedRoute(route),
                  title: Text(route.name.isEmpty ? '未命名路线' : route.name),
                  subtitle: Text('${route.points.length} 个点'),
                  trailing: FilledButton(
                    onPressed: disabled
                        ? null
                        : () {
                            ref
                                .read(navigationDraftProvider.notifier)
                                .selectSavedRoute(route);
                            unawaited(
                              ref
                                  .read(navigationProvider.notifier)
                                  .startSavedRoute(
                                    route,
                                    draft.savedRouteCycles,
                                  ),
                            );
                            _collapseForMission();
                          },
                    child: const Text('执行'),
                  ),
                ),
              ),
            ),
          ),
        if (draft.selectedRoute != null)
          OutlinedButton.icon(
            onPressed: disabled
                ? null
                : () {
                    ref
                        .read(navigationDraftProvider.notifier)
                        .loadRouteIntoPath(draft.selectedRoute!);
                    ref
                        .read(navigationWorkspaceProvider.notifier)
                        .setMode(NavMode.path);
                    _pathNameController.text = draft.selectedRoute!.name;
                  },
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: const Text('加载到路径编辑'),
          ),
      ],
    );
  }

  bool get _missionSubmitDisabled =>
      !widget.navState.navReady ||
      widget.navState.activeMission?.isActive == true ||
      widget.navState.isPending(NavigationCommand.submitMission);

  Widget get _missionButtonIcon =>
      widget.navState.isPending(NavigationCommand.submitMission)
      ? const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Icon(Icons.play_arrow_rounded);

  void _toggleMapInteraction() {
    final notifier = ref.read(navigationWorkspaceProvider.notifier);
    final editing =
        ref.read(navigationWorkspaceProvider).interactionMode !=
        MapInteractionMode.browse;
    if (editing) {
      notifier.cancelMapInteraction();
    } else {
      notifier.beginMapInteraction();
    }
  }

  void _collapseForMission() {
    ref.read(navigationWorkspaceProvider.notifier).collapseForMission();
  }

  void _toggleFollowRobot() {
    final notifier = ref.read(navigationWorkspaceProvider.notifier);
    final next = !ref.read(navigationWorkspaceProvider).followRobot;
    notifier.setFollowRobot(next);
    if (next) _centerOnRobot();
  }

  void _centerOnRobot() {
    final robot = widget.navState.robotPose;
    final meta = widget.navState.mapMeta;
    if (robot == null || meta == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.centerOnWorld(meta, robot.x, robot.y);
    });
  }

  Future<void> _confirmCloseNavigation() async {
    final draft = ref.read(navigationDraftProvider);
    final active = widget.navState.activeMission?.isActive == true;
    final details = [
      if (active) '当前任务将被停止',
      if (draft.hasUnsavedDraft) '未保存的地图选点将被清除',
      '导航容器将关闭',
    ].join('；');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关闭导航'),
        content: Text('$details。确认继续？'),
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
    if (confirmed != true || !mounted) return;
    await ref.read(navigationProvider.notifier).closeNavigation();
    if (!mounted) return;
    ref.read(navigationDraftProvider.notifier).clearAll();
    ref.invalidate(navigationWorkspaceProvider);
  }

  Future<void> _openTool(NavigationAuxTool tool) async {
    final workspace = ref.read(navigationWorkspaceProvider.notifier);
    workspace.openTool(tool);
    switch (tool) {
      case NavigationAuxTool.teleop:
        await _showTeleopSheet(ref.read(wsManagerProvider));
        break;
      case NavigationAuxTool.pointCloud:
        final url = _navWsUrl(ref.read(activeConnectionProvider)?.baseUrl);
        if (url != null) await _showPointCloudSheet(url);
        break;
      case NavigationAuxTool.video:
        final url = _janusWsUrl(ref.read(activeConnectionProvider)?.baseUrl);
        if (url != null) await _showVideoSheet(url);
        break;
    }
    if (mounted) workspace.closeTool();
  }

  Future<void> _showPointCloudSheet(String wsUrl) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: _NavigationPointCloudCard(wsUrl: wsUrl),
          ),
        ),
      ),
    );
  }

  Future<void> _showTeleopSheet(WsConnectionManager wsManager) {
    return showModalBottomSheet<void>(
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

  Future<void> _showVideoSheet(String janusWsUrl) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
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

class _SelectionSummary extends StatelessWidget {
  final String emptyText;
  final MapSelection? selection;
  final String prefix;

  const _SelectionSummary({
    required this.emptyText,
    required this.selection,
    required this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final point = selection;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        point == null
            ? emptyText
            : '$prefix  x ${point.x.toStringAsFixed(2)}  '
                  'y ${point.y.toStringAsFixed(2)}  '
                  'θ ${point.theta.toStringAsFixed(2)}',
        style: TextStyle(
          color: point == null ? Colors.white54 : Colors.white,
          fontFamily: point == null ? null : 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}

class _WaypointSummary extends StatelessWidget {
  final List<Waypoint> points;
  final String emptyText;
  final ValueChanged<int>? onDelete;

  const _WaypointSummary({
    required this.points,
    required this.emptyText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          emptyText,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }
    return Wrap(
      spacing: 7,
      runSpacing: 5,
      children: [
        for (var index = 0; index < points.length; index++)
          InputChip(
            label: Text(
              'P${index + 1} '
              '${points[index].x.toStringAsFixed(1)},'
              '${points[index].y.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 11),
            ),
            onDeleted: onDelete == null ? null : () => onDelete!(index),
          ),
      ],
    );
  }
}

class _CyclesField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<int> onChanged;

  const _CyclesField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        isDense: true,
        labelText: '循环',
        border: OutlineInputBorder(),
      ),
      onChanged: (text) => onChanged(int.tryParse(text) ?? 1),
    );
  }
}

class _HudButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  const _HudButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: EdgeInsets.zero,
      selected: selected,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: onPressed == null ? Colors.white30 : Colors.white,
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primaryColor.withValues(alpha: 0.78)
            : const Color(0xD90F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppTheme.primaryColor : Colors.white24,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CompactAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onPressed;

  const _CompactAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.65)),
        backgroundColor: color.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: busy
          ? SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 12)),
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
    } catch (error) {
      controller.status.value = '连接失败: $error';
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
            child: Row(
              children: [
                Expanded(
                  child: _NavigationStreamPane(label: '左', controller: _left),
                ),
                Expanded(
                  child: _NavigationStreamPane(label: '右', controller: _right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _ready && !_busy ? (_playing ? _stop : _play) : null,
                icon: Icon(
                  _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
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
            builder: (context, status, _) => Text(
              '$label · $status',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'monospace',
                fontSize: 11,
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

class _NavigationTeleopCardState extends State<_NavigationTeleopCard>
    with WidgetsBindingObserver {
  static const _maxLinear = 0.75;
  static const _maxAngular = 1.25;

  double _speed = 0.35;
  double _linear = 0;
  double _angular = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _sendStop(updateUi: mounted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sendStop(updateUi: false);
    super.dispose();
  }

  void _move(double x, double y) {
    final linear = -y * _maxLinear * _speed;
    final angular = -x * _maxAngular * _speed;
    setState(() {
      _linear = linear;
      _angular = angular;
    });
    widget.wsManager.sendCmdVel(linear, angular);
  }

  void _sendStop({bool updateUi = true}) {
    if (updateUi) {
      setState(() {
        _linear = 0;
        _angular = 0;
      });
    }
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
            onRelease: _sendStop,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('倍率'),
              Expanded(
                child: Slider(
                  value: _speed,
                  min: 0.1,
                  max: 1,
                  divisions: 9,
                  onChanged: (value) => setState(() => _speed = value),
                ),
              ),
              Text('${(_speed * 100).round()}%'),
            ],
          ),
          Text(
            'V ${_linear.toStringAsFixed(2)}  W ${_angular.toStringAsFixed(2)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sendStop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('急停'),
            ),
          ),
        ],
      ),
    );
  }
}

String _modeLabel(NavMode mode) => switch (mode) {
  NavMode.singlePoint => '单点',
  NavMode.path => '路径',
  NavMode.record => '录制',
  NavMode.relocalize => '重定位',
  NavMode.savedRoute => '路线',
};

IconData _modeIcon(NavMode mode) => switch (mode) {
  NavMode.singlePoint => Icons.near_me_outlined,
  NavMode.path => Icons.route_outlined,
  NavMode.record => Icons.fiber_manual_record_outlined,
  NavMode.relocalize => Icons.location_searching,
  NavMode.savedRoute => Icons.bookmarks_outlined,
};

Color _statusColor(NavigationStatus status) => switch (status) {
  NavigationStatus.navigating => AppTheme.primaryColor,
  NavigationStatus.arrived => AppTheme.success,
  NavigationStatus.failed => AppTheme.danger,
  NavigationStatus.paused => AppTheme.warning,
  NavigationStatus.stopped => AppTheme.slate500,
  NavigationStatus.vacant => AppTheme.slate400,
};

Color _runtimeStatusColor(NavigationState state) {
  if (!state.navReady) return AppTheme.warning;
  return switch (state.navStatus) {
    NavigationStatus.failed ||
    NavigationStatus.navigating ||
    NavigationStatus.paused ||
    NavigationStatus.arrived => _statusColor(state.navStatus),
    NavigationStatus.stopped || NavigationStatus.vacant => AppTheme.success,
  };
}

String _statusLabel(NavigationStatus status) => switch (status) {
  NavigationStatus.navigating => '导航中',
  NavigationStatus.arrived => '已到达',
  NavigationStatus.failed => '失败',
  NavigationStatus.paused => '已暂停',
  NavigationStatus.stopped => '已停止',
  NavigationStatus.vacant => '空闲',
};

String _taskStatusLabel(NavigationState state) {
  if (!state.navReady) return '导航服务启动中';
  return switch (state.navStatus) {
    NavigationStatus.stopped || NavigationStatus.vacant => '空闲',
    _ => _statusLabel(state.navStatus),
  };
}

String _runtimeStatusLabel(NavigationState state) {
  if (!state.navReady) return '导航服务启动中';
  return switch (state.navStatus) {
    NavigationStatus.failed ||
    NavigationStatus.navigating ||
    NavigationStatus.paused ||
    NavigationStatus.arrived => _statusLabel(state.navStatus),
    NavigationStatus.stopped || NavigationStatus.vacant => '导航运行中',
  };
}

String _missionStatusLabel(String status) => switch (status) {
  'pending' => '排队中',
  'running' || 'active' => '执行中',
  'paused' => '已暂停',
  'completed' || 'succeeded' || 'success' => '已完成',
  'failed' || 'error' => '失败',
  'cancelled' || 'canceled' => '已取消',
  'stopping' => '停止中',
  'stopped' => '已停止',
  _ => status,
};
