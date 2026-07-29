import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/app_models.dart';
import '../../../shared/widgets/occupancy_map.dart';
import 'navigation_provider.dart';

enum NavigationSheetLevel { summary, defaultView, expanded }

enum NavigationAuxTool { teleop, pointCloud, video }

class NavigationDraftState {
  final SingleMissionMode singleMissionMode;
  final MapSelection? singleGoal;
  final List<Waypoint> pathWaypoints;
  final int pathCycles;
  final String pathName;
  final List<Waypoint> recordWaypoints;
  final String recordName;
  final MapSelection? relocationPose;
  final NavLandmark? selectedRoute;
  final int savedRouteCycles;

  const NavigationDraftState({
    this.singleMissionMode = SingleMissionMode.standard,
    this.singleGoal,
    this.pathWaypoints = const [],
    this.pathCycles = 1,
    this.pathName = '',
    this.recordWaypoints = const [],
    this.recordName = '',
    this.relocationPose,
    this.selectedRoute,
    this.savedRouteCycles = 1,
  });

  bool get hasUnsavedDraft =>
      singleGoal != null ||
      pathWaypoints.isNotEmpty ||
      recordWaypoints.isNotEmpty ||
      relocationPose != null;

  NavigationDraftState copyWith({
    SingleMissionMode? singleMissionMode,
    Object? singleGoal = _sentinel,
    List<Waypoint>? pathWaypoints,
    int? pathCycles,
    String? pathName,
    List<Waypoint>? recordWaypoints,
    String? recordName,
    Object? relocationPose = _sentinel,
    Object? selectedRoute = _sentinel,
    int? savedRouteCycles,
  }) {
    return NavigationDraftState(
      singleMissionMode: singleMissionMode ?? this.singleMissionMode,
      singleGoal: singleGoal == _sentinel
          ? this.singleGoal
          : singleGoal as MapSelection?,
      pathWaypoints: pathWaypoints ?? this.pathWaypoints,
      pathCycles: pathCycles ?? this.pathCycles,
      pathName: pathName ?? this.pathName,
      recordWaypoints: recordWaypoints ?? this.recordWaypoints,
      recordName: recordName ?? this.recordName,
      relocationPose: relocationPose == _sentinel
          ? this.relocationPose
          : relocationPose as MapSelection?,
      selectedRoute: selectedRoute == _sentinel
          ? this.selectedRoute
          : selectedRoute as NavLandmark?,
      savedRouteCycles: savedRouteCycles ?? this.savedRouteCycles,
    );
  }
}

const _sentinel = Object();

class NavigationDraftNotifier extends StateNotifier<NavigationDraftState> {
  NavigationDraftNotifier() : super(const NavigationDraftState());

  void setSingleMissionMode(SingleMissionMode mode) {
    state = state.copyWith(singleMissionMode: mode);
  }

  void setSingleGoal(MapSelection selection) {
    final previousTheta = state.singleGoal?.theta ?? 0;
    state = state.copyWith(
      singleGoal: selection.headingExplicit
          ? selection
          : selection.copyWith(theta: previousTheta),
    );
  }

  void clearSingleGoal() {
    state = state.copyWith(singleGoal: null);
  }

  void addPathWaypoint(MapSelection selection) {
    state = state.copyWith(
      pathWaypoints: [
        ...state.pathWaypoints,
        Waypoint(x: selection.x, y: selection.y, theta: selection.theta),
      ],
    );
  }

  void removePathWaypoint(int index) {
    if (index < 0 || index >= state.pathWaypoints.length) return;
    final next = [...state.pathWaypoints]..removeAt(index);
    state = state.copyWith(pathWaypoints: next);
  }

  void undoPathWaypoint() {
    if (state.pathWaypoints.isEmpty) return;
    removePathWaypoint(state.pathWaypoints.length - 1);
  }

  void clearPath() {
    state = state.copyWith(pathWaypoints: const []);
  }

  void setPathCycles(int cycles) {
    state = state.copyWith(pathCycles: cycles.clamp(1, 999).toInt());
  }

  void setPathName(String name) {
    state = state.copyWith(pathName: name);
  }

  void loadRouteIntoPath(NavLandmark route) {
    state = state.copyWith(
      selectedRoute: route,
      pathWaypoints: List<Waypoint>.unmodifiable(route.points),
      pathName: route.name,
    );
  }

  void addRecordWaypoint(MapSelection selection) {
    state = state.copyWith(
      recordWaypoints: [
        ...state.recordWaypoints,
        Waypoint(x: selection.x, y: selection.y, theta: selection.theta),
      ],
    );
  }

  void removeRecordWaypoint(int index) {
    if (index < 0 || index >= state.recordWaypoints.length) return;
    final next = [...state.recordWaypoints]..removeAt(index);
    state = state.copyWith(recordWaypoints: next);
  }

  void clearRecord() {
    state = state.copyWith(recordWaypoints: const []);
  }

  void setRecordName(String name) {
    state = state.copyWith(recordName: name);
  }

  void setRelocationPose(MapSelection selection) {
    final previousTheta = state.relocationPose?.theta ?? 0;
    state = state.copyWith(
      relocationPose: selection.headingExplicit
          ? selection
          : selection.copyWith(theta: previousTheta),
    );
  }

  void clearRelocationPose() {
    state = state.copyWith(relocationPose: null);
  }

  void selectSavedRoute(NavLandmark? route) {
    state = state.copyWith(selectedRoute: route);
  }

  void setSavedRouteCycles(int cycles) {
    state = state.copyWith(savedRouteCycles: cycles.clamp(1, 999).toInt());
  }

  void clearAll() {
    state = const NavigationDraftState();
  }
}

final navigationDraftProvider =
    StateNotifierProvider.autoDispose<
      NavigationDraftNotifier,
      NavigationDraftState
    >((ref) => NavigationDraftNotifier());

class NavigationWorkspaceState {
  final NavMode mode;
  final MapInteractionMode interactionMode;
  final NavigationSheetLevel sheetLevel;
  final bool followRobot;
  final NavigationAuxTool? activeTool;

  const NavigationWorkspaceState({
    this.mode = NavMode.singlePoint,
    this.interactionMode = MapInteractionMode.browse,
    this.sheetLevel = NavigationSheetLevel.defaultView,
    this.followRobot = false,
    this.activeTool,
  });

  double get sheetExtent => switch (sheetLevel) {
    NavigationSheetLevel.summary => 0.16,
    NavigationSheetLevel.defaultView => 0.38,
    NavigationSheetLevel.expanded => 0.82,
  };

  NavigationWorkspaceState copyWith({
    NavMode? mode,
    MapInteractionMode? interactionMode,
    NavigationSheetLevel? sheetLevel,
    bool? followRobot,
    Object? activeTool = _sentinel,
  }) {
    return NavigationWorkspaceState(
      mode: mode ?? this.mode,
      interactionMode: interactionMode ?? this.interactionMode,
      sheetLevel: sheetLevel ?? this.sheetLevel,
      followRobot: followRobot ?? this.followRobot,
      activeTool: activeTool == _sentinel
          ? this.activeTool
          : activeTool as NavigationAuxTool?,
    );
  }
}

class NavigationWorkspaceNotifier
    extends StateNotifier<NavigationWorkspaceState> {
  NavigationWorkspaceNotifier() : super(const NavigationWorkspaceState());

  void setMode(NavMode mode) {
    state = state.copyWith(
      mode: mode,
      interactionMode: MapInteractionMode.browse,
      sheetLevel: NavigationSheetLevel.defaultView,
    );
  }

  void beginMapInteraction() {
    final interactionMode = switch (state.mode) {
      NavMode.singlePoint => MapInteractionMode.pickGoal,
      NavMode.path => MapInteractionMode.addWaypoint,
      NavMode.record => MapInteractionMode.addWaypoint,
      NavMode.relocalize => MapInteractionMode.pickRelocalization,
      NavMode.savedRoute => MapInteractionMode.browse,
    };
    state = state.copyWith(interactionMode: interactionMode);
  }

  void cancelMapInteraction() {
    state = state.copyWith(interactionMode: MapInteractionMode.browse);
  }

  void setSheetLevel(NavigationSheetLevel level) {
    state = state.copyWith(sheetLevel: level);
  }

  void collapseForMission() {
    state = state.copyWith(
      interactionMode: MapInteractionMode.browse,
      sheetLevel: NavigationSheetLevel.summary,
    );
  }

  void setFollowRobot(bool enabled) {
    state = state.copyWith(followRobot: enabled);
  }

  void disableFollowRobot() {
    if (!state.followRobot) return;
    state = state.copyWith(followRobot: false);
  }

  void openTool(NavigationAuxTool tool) {
    state = state.copyWith(activeTool: tool);
  }

  void closeTool() {
    state = state.copyWith(activeTool: null);
  }
}

final navigationWorkspaceProvider =
    StateNotifierProvider.autoDispose<
      NavigationWorkspaceNotifier,
      NavigationWorkspaceState
    >((ref) => NavigationWorkspaceNotifier());
