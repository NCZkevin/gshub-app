import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/map_coords.dart';
import '../../../core/utils/pgm_parser.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../data/navigation_repository.dart';

// ─── Enums ───────────────────────────────────────────────────

enum NavViewState { checking, setup, active }

enum NavMode { singlePoint, path, record, relocalize, savedRoute }

enum SingleMissionMode { standard, direct }

enum NavParamField {
  lidarHeight,
  freeMinObstacleHeight,
  freeMaxObstacleHeight,
  freeLinearSpeed,
  freeAngularSpeed,
  freeXyGoalTolerance,
  freeYawGoalTolerance,
  freeSafetyDistance,
  fixedMaxLinearSpeed,
  fixedMaxAngularSpeed,
  fixedXyGoalTolerance,
  fixedYawGoalTolerance,
  fixedLateralSafetyDistance,
  fixedForwardSafetyDistance,
  robotLength,
  robotWidth,
  deviceFrontDistance,
  deviceLeftDistance,
}

const navParamNames = [
  'robot:lidar_height',
  'robot:footprint',
  'navigation:free_navigation:min_obstacle_height',
  'navigation:free_navigation:max_obstacle_height',
  'navigation:free_navigation:linear_speed',
  'navigation:free_navigation:angular_speed',
  'navigation:free_navigation:xy_goal_tolerance',
  'navigation:free_navigation:yaw_goal_tolerance',
  'navigation:free_navigation:safety_distance',
  'navigation:fixed_point_navigation:max_linear_speed',
  'navigation:fixed_point_navigation:max_angular_speed',
  'navigation:fixed_point_navigation:holonomic',
  'navigation:fixed_point_navigation:xy_goal_tolerance',
  'navigation:fixed_point_navigation:yaw_goal_tolerance',
  'navigation:fixed_point_navigation:lateral_safety_distance',
  'navigation:fixed_point_navigation:forward_safety_distance',
];

class NavParamForm {
  final double lidarHeight;
  final double freeMinObstacleHeight;
  final double freeMaxObstacleHeight;
  final double freeLinearSpeed;
  final double freeAngularSpeed;
  final double freeXyGoalTolerance;
  final double freeYawGoalTolerance;
  final double freeSafetyDistance;
  final double fixedMaxLinearSpeed;
  final double fixedMaxAngularSpeed;
  final bool holonomic;
  final double fixedXyGoalTolerance;
  final double fixedYawGoalTolerance;
  final double fixedLateralSafetyDistance;
  final double fixedForwardSafetyDistance;
  final double robotLength;
  final double robotWidth;
  final double deviceFrontDistance;
  final double deviceLeftDistance;

  const NavParamForm({
    this.lidarHeight = 0.6,
    this.freeMinObstacleHeight = 0.1,
    this.freeMaxObstacleHeight = 1.0,
    this.freeLinearSpeed = 0.5,
    this.freeAngularSpeed = 0.7,
    this.freeXyGoalTolerance = 0.5,
    this.freeYawGoalTolerance = 0.2,
    this.freeSafetyDistance = 0.2,
    this.fixedMaxLinearSpeed = 0.5,
    this.fixedMaxAngularSpeed = 0.7,
    this.holonomic = true,
    this.fixedXyGoalTolerance = 0.5,
    this.fixedYawGoalTolerance = 0.2,
    this.fixedLateralSafetyDistance = 0.2,
    this.fixedForwardSafetyDistance = 0.2,
    this.robotLength = 0.85,
    this.robotWidth = 0.5,
    this.deviceFrontDistance = 0.4,
    this.deviceLeftDistance = 0.25,
  });

  NavParamForm copyWith({
    double? lidarHeight,
    double? freeMinObstacleHeight,
    double? freeMaxObstacleHeight,
    double? freeLinearSpeed,
    double? freeAngularSpeed,
    double? freeXyGoalTolerance,
    double? freeYawGoalTolerance,
    double? freeSafetyDistance,
    double? fixedMaxLinearSpeed,
    double? fixedMaxAngularSpeed,
    bool? holonomic,
    double? fixedXyGoalTolerance,
    double? fixedYawGoalTolerance,
    double? fixedLateralSafetyDistance,
    double? fixedForwardSafetyDistance,
    double? robotLength,
    double? robotWidth,
    double? deviceFrontDistance,
    double? deviceLeftDistance,
  }) {
    return NavParamForm(
      lidarHeight: lidarHeight ?? this.lidarHeight,
      freeMinObstacleHeight:
          freeMinObstacleHeight ?? this.freeMinObstacleHeight,
      freeMaxObstacleHeight:
          freeMaxObstacleHeight ?? this.freeMaxObstacleHeight,
      freeLinearSpeed: freeLinearSpeed ?? this.freeLinearSpeed,
      freeAngularSpeed: freeAngularSpeed ?? this.freeAngularSpeed,
      freeXyGoalTolerance: freeXyGoalTolerance ?? this.freeXyGoalTolerance,
      freeYawGoalTolerance: freeYawGoalTolerance ?? this.freeYawGoalTolerance,
      freeSafetyDistance: freeSafetyDistance ?? this.freeSafetyDistance,
      fixedMaxLinearSpeed: fixedMaxLinearSpeed ?? this.fixedMaxLinearSpeed,
      fixedMaxAngularSpeed: fixedMaxAngularSpeed ?? this.fixedMaxAngularSpeed,
      holonomic: holonomic ?? this.holonomic,
      fixedXyGoalTolerance: fixedXyGoalTolerance ?? this.fixedXyGoalTolerance,
      fixedYawGoalTolerance:
          fixedYawGoalTolerance ?? this.fixedYawGoalTolerance,
      fixedLateralSafetyDistance:
          fixedLateralSafetyDistance ?? this.fixedLateralSafetyDistance,
      fixedForwardSafetyDistance:
          fixedForwardSafetyDistance ?? this.fixedForwardSafetyDistance,
      robotLength: robotLength ?? this.robotLength,
      robotWidth: robotWidth ?? this.robotWidth,
      deviceFrontDistance: deviceFrontDistance ?? this.deviceFrontDistance,
      deviceLeftDistance: deviceLeftDistance ?? this.deviceLeftDistance,
    );
  }

  double valueOf(NavParamField field) {
    switch (field) {
      case NavParamField.lidarHeight:
        return lidarHeight;
      case NavParamField.freeMinObstacleHeight:
        return freeMinObstacleHeight;
      case NavParamField.freeMaxObstacleHeight:
        return freeMaxObstacleHeight;
      case NavParamField.freeLinearSpeed:
        return freeLinearSpeed;
      case NavParamField.freeAngularSpeed:
        return freeAngularSpeed;
      case NavParamField.freeXyGoalTolerance:
        return freeXyGoalTolerance;
      case NavParamField.freeYawGoalTolerance:
        return freeYawGoalTolerance;
      case NavParamField.freeSafetyDistance:
        return freeSafetyDistance;
      case NavParamField.fixedMaxLinearSpeed:
        return fixedMaxLinearSpeed;
      case NavParamField.fixedMaxAngularSpeed:
        return fixedMaxAngularSpeed;
      case NavParamField.fixedXyGoalTolerance:
        return fixedXyGoalTolerance;
      case NavParamField.fixedYawGoalTolerance:
        return fixedYawGoalTolerance;
      case NavParamField.fixedLateralSafetyDistance:
        return fixedLateralSafetyDistance;
      case NavParamField.fixedForwardSafetyDistance:
        return fixedForwardSafetyDistance;
      case NavParamField.robotLength:
        return robotLength;
      case NavParamField.robotWidth:
        return robotWidth;
      case NavParamField.deviceFrontDistance:
        return deviceFrontDistance;
      case NavParamField.deviceLeftDistance:
        return deviceLeftDistance;
    }
  }

  NavParamForm withField(NavParamField field, double value) {
    switch (field) {
      case NavParamField.lidarHeight:
        return copyWith(lidarHeight: value);
      case NavParamField.freeMinObstacleHeight:
        return copyWith(freeMinObstacleHeight: value);
      case NavParamField.freeMaxObstacleHeight:
        return copyWith(freeMaxObstacleHeight: value);
      case NavParamField.freeLinearSpeed:
        return copyWith(freeLinearSpeed: value);
      case NavParamField.freeAngularSpeed:
        return copyWith(freeAngularSpeed: value);
      case NavParamField.freeXyGoalTolerance:
        return copyWith(freeXyGoalTolerance: value);
      case NavParamField.freeYawGoalTolerance:
        return copyWith(freeYawGoalTolerance: value);
      case NavParamField.freeSafetyDistance:
        return copyWith(freeSafetyDistance: value);
      case NavParamField.fixedMaxLinearSpeed:
        return copyWith(fixedMaxLinearSpeed: value);
      case NavParamField.fixedMaxAngularSpeed:
        return copyWith(fixedMaxAngularSpeed: value);
      case NavParamField.fixedXyGoalTolerance:
        return copyWith(fixedXyGoalTolerance: value);
      case NavParamField.fixedYawGoalTolerance:
        return copyWith(fixedYawGoalTolerance: value);
      case NavParamField.fixedLateralSafetyDistance:
        return copyWith(fixedLateralSafetyDistance: value);
      case NavParamField.fixedForwardSafetyDistance:
        return copyWith(fixedForwardSafetyDistance: value);
      case NavParamField.robotLength:
        return copyWith(robotLength: value);
      case NavParamField.robotWidth:
        return copyWith(robotWidth: value);
      case NavParamField.deviceFrontDistance:
        return copyWith(deviceFrontDistance: value);
      case NavParamField.deviceLeftDistance:
        return copyWith(deviceLeftDistance: value);
    }
  }

  factory NavParamForm.fromSavedParams(Map<String, dynamic> params) {
    var form = const NavParamForm();

    double? numberValue(String key) {
      final item = params[key];
      if (item is! Map<String, dynamic> || item['success'] != true) return null;
      final value = item['value'];
      return value is num ? value.toDouble() : null;
    }

    form = form.copyWith(
      lidarHeight: numberValue('robot:lidar_height'),
      freeMinObstacleHeight: numberValue(
        'navigation:free_navigation:min_obstacle_height',
      ),
      freeMaxObstacleHeight: numberValue(
        'navigation:free_navigation:max_obstacle_height',
      ),
      freeLinearSpeed: numberValue('navigation:free_navigation:linear_speed'),
      freeAngularSpeed: numberValue('navigation:free_navigation:angular_speed'),
      freeXyGoalTolerance: numberValue(
        'navigation:free_navigation:xy_goal_tolerance',
      ),
      freeYawGoalTolerance: numberValue(
        'navigation:free_navigation:yaw_goal_tolerance',
      ),
      freeSafetyDistance: numberValue(
        'navigation:free_navigation:safety_distance',
      ),
      fixedMaxLinearSpeed: numberValue(
        'navigation:fixed_point_navigation:max_linear_speed',
      ),
      fixedMaxAngularSpeed: numberValue(
        'navigation:fixed_point_navigation:max_angular_speed',
      ),
      fixedXyGoalTolerance: numberValue(
        'navigation:fixed_point_navigation:xy_goal_tolerance',
      ),
      fixedYawGoalTolerance: numberValue(
        'navigation:fixed_point_navigation:yaw_goal_tolerance',
      ),
      fixedLateralSafetyDistance: numberValue(
        'navigation:fixed_point_navigation:lateral_safety_distance',
      ),
      fixedForwardSafetyDistance: numberValue(
        'navigation:fixed_point_navigation:forward_safety_distance',
      ),
    );

    final holonomic = params['navigation:fixed_point_navigation:holonomic'];
    if (holonomic is Map<String, dynamic> &&
        holonomic['success'] == true &&
        holonomic['value'] is bool) {
      form = form.copyWith(holonomic: holonomic['value'] as bool);
    }

    final footprint = params['robot:footprint'];
    if (footprint is Map<String, dynamic> &&
        footprint['success'] == true &&
        footprint['value'] is List) {
      final points = (footprint['value'] as List)
          .whereType<List>()
          .map(
            (point) => point
                .whereType<num>()
                .map((value) => value.toDouble())
                .toList(),
          )
          .toList();
      if (points.length == 4 && points.every((point) => point.length == 2)) {
        final front = points[0][0];
        final left = points[0][1];
        final width = left - points[1][1];
        final length = front - points[2][0];
        if (length > 0 && width > 0) {
          form = form.copyWith(
            robotLength: length,
            robotWidth: width,
            deviceFrontDistance: front,
            deviceLeftDistance: left,
          );
        }
      }
    }

    return form;
  }

  Map<String, dynamic>? toPayload() {
    if (robotLength <= 0 || robotWidth <= 0) return null;
    final footprint = [
      [deviceFrontDistance, deviceLeftDistance],
      [deviceFrontDistance, deviceLeftDistance - robotWidth],
      [deviceFrontDistance - robotLength, deviceLeftDistance - robotWidth],
      [deviceFrontDistance - robotLength, deviceLeftDistance],
    ];

    return {
      'robot:lidar_height': lidarHeight,
      'robot:footprint': footprint,
      'navigation:free_navigation:min_obstacle_height': freeMinObstacleHeight,
      'navigation:free_navigation:max_obstacle_height': freeMaxObstacleHeight,
      'navigation:free_navigation:linear_speed': freeLinearSpeed,
      'navigation:free_navigation:angular_speed': freeAngularSpeed,
      'navigation:free_navigation:xy_goal_tolerance': freeXyGoalTolerance,
      'navigation:free_navigation:yaw_goal_tolerance': freeYawGoalTolerance,
      'navigation:free_navigation:safety_distance': freeSafetyDistance,
      'navigation:fixed_point_navigation:max_linear_speed': fixedMaxLinearSpeed,
      'navigation:fixed_point_navigation:max_angular_speed':
          fixedMaxAngularSpeed,
      'navigation:fixed_point_navigation:holonomic': holonomic,
      'navigation:fixed_point_navigation:xy_goal_tolerance':
          fixedXyGoalTolerance,
      'navigation:fixed_point_navigation:yaw_goal_tolerance':
          fixedYawGoalTolerance,
      'navigation:fixed_point_navigation:lateral_safety_distance':
          fixedLateralSafetyDistance,
      'navigation:fixed_point_navigation:forward_safety_distance':
          fixedForwardSafetyDistance,
    };
  }
}

class MissionInfo {
  final String id;
  final String status;
  final String? mode;
  final int? currentStep;
  final int? totalSteps;

  const MissionInfo({
    required this.id,
    required this.status,
    this.mode,
    this.currentStep,
    this.totalSteps,
  });

  bool get isActive => !{
    'completed',
    'succeeded',
    'success',
    'failed',
    'error',
    'cancelled',
    'canceled',
    'stopped',
  }.contains(status);

  factory MissionInfo.fromJson(Map<String, dynamic> json) {
    return MissionInfo(
      id: json['mission_id'] as String? ?? json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      mode: json['mode'] as String?,
      currentStep: (json['current_step'] as num?)?.toInt(),
      totalSteps: (json['total_steps'] as num?)?.toInt(),
    );
  }
}

class NavLandmark {
  final int id;
  final String name;
  final String sceneName;
  final String kind;
  final List<Waypoint> points;

  const NavLandmark({
    required this.id,
    required this.name,
    required this.sceneName,
    required this.kind,
    required this.points,
  });

  factory NavLandmark.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return NavLandmark(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      sceneName: json['scene_name'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      points: rawPoints is List
          ? rawPoints
                .whereType<Map<String, dynamic>>()
                .map(Waypoint.fromJson)
                .toList()
          : const [],
    );
  }
}

// ─── State ───────────────────────────────────────────────────

class NavigationState {
  final NavViewState viewState;
  final List<MapInfo> maps;
  final String? selectedMap;
  final Uint8List? pgmBytes;
  final MapMeta? mapMeta;
  final RobotOdometry? robotPose;
  final List<RobotOdometry> trajectory;
  final NavigationStatus navStatus;
  final NavMode navMode;
  final SingleMissionMode singleMissionMode;
  final MissionInfo? activeMission;
  final (double x, double y, double theta)? goalPoint;
  final (double x, double y, double theta)? relocalizationPose;
  final List<NavLandmark> savedRoutes;
  final List<Waypoint> waypoints;
  final List<(double x, double y)> plannedPath;
  final NavParamForm navParams;
  final bool navParamsDirty;
  final String? navParamsMessage;
  final bool relocalization;
  final bool loading;
  final String? error;

  const NavigationState({
    this.viewState = NavViewState.checking,
    this.maps = const [],
    this.selectedMap,
    this.pgmBytes,
    this.mapMeta,
    this.robotPose,
    this.trajectory = const [],
    this.navStatus = NavigationStatus.vacant,
    this.navMode = NavMode.singlePoint,
    this.singleMissionMode = SingleMissionMode.standard,
    this.activeMission,
    this.goalPoint,
    this.relocalizationPose,
    this.savedRoutes = const [],
    this.waypoints = const [],
    this.plannedPath = const [],
    this.navParams = const NavParamForm(),
    this.navParamsDirty = false,
    this.navParamsMessage,
    this.relocalization = false,
    this.loading = false,
    this.error,
  });

  NavigationState copyWith({
    NavViewState? viewState,
    List<MapInfo>? maps,
    Object? selectedMap = _sentinel,
    Object? pgmBytes = _sentinel,
    Object? mapMeta = _sentinel,
    Object? robotPose = _sentinel,
    List<RobotOdometry>? trajectory,
    NavigationStatus? navStatus,
    NavMode? navMode,
    SingleMissionMode? singleMissionMode,
    Object? activeMission = _sentinel,
    Object? goalPoint = _sentinel,
    Object? relocalizationPose = _sentinel,
    List<NavLandmark>? savedRoutes,
    List<Waypoint>? waypoints,
    List<(double, double)>? plannedPath,
    NavParamForm? navParams,
    bool? navParamsDirty,
    Object? navParamsMessage = _sentinel,
    bool? relocalization,
    bool? loading,
    Object? error = _sentinel,
  }) {
    return NavigationState(
      viewState: viewState ?? this.viewState,
      maps: maps ?? this.maps,
      selectedMap: selectedMap == _sentinel
          ? this.selectedMap
          : selectedMap as String?,
      pgmBytes: pgmBytes == _sentinel ? this.pgmBytes : pgmBytes as Uint8List?,
      mapMeta: mapMeta == _sentinel ? this.mapMeta : mapMeta as MapMeta?,
      robotPose: robotPose == _sentinel
          ? this.robotPose
          : robotPose as RobotOdometry?,
      trajectory: trajectory ?? this.trajectory,
      navStatus: navStatus ?? this.navStatus,
      navMode: navMode ?? this.navMode,
      singleMissionMode: singleMissionMode ?? this.singleMissionMode,
      activeMission: activeMission == _sentinel
          ? this.activeMission
          : activeMission as MissionInfo?,
      goalPoint: goalPoint == _sentinel
          ? this.goalPoint
          : goalPoint as (double, double, double)?,
      relocalizationPose: relocalizationPose == _sentinel
          ? this.relocalizationPose
          : relocalizationPose as (double, double, double)?,
      savedRoutes: savedRoutes ?? this.savedRoutes,
      waypoints: waypoints ?? this.waypoints,
      plannedPath: plannedPath ?? this.plannedPath,
      navParams: navParams ?? this.navParams,
      navParamsDirty: navParamsDirty ?? this.navParamsDirty,
      navParamsMessage: navParamsMessage == _sentinel
          ? this.navParamsMessage
          : navParamsMessage as String?,
      relocalization: relocalization ?? this.relocalization,
      loading: loading ?? this.loading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

// ─── Repository Provider ──────────────────────────────────────

final navigationRepositoryProvider = FutureProvider<NavigationRepository?>((
  ref,
) async {
  final client = await ref.watch(dioClientFutureProvider.future);
  if (client == null) return null;
  return NavigationRepository(client);
});

// ─── Notifier ────────────────────────────────────────────────

class NavigationNotifier extends AutoDisposeAsyncNotifier<NavigationState> {
  StreamSubscription<RobotOdometry>? _odoSub;
  Timer? _statusPollTimer;
  Timer? _missionPollTimer;

  @override
  Future<NavigationState> build() async {
    ref.onDispose(() {
      _odoSub?.cancel();
      _statusPollTimer?.cancel();
      _missionPollTimer?.cancel();
    });

    // Subscribe to odometry
    final wsManager = ref.watch(wsManagerProvider);
    _odoSub = wsManager.odometryStream.listen(_onOdometry);

    // Initial container check
    final repo = await ref.read(navigationRepositoryProvider.future);
    if (repo == null) {
      return const NavigationState(viewState: NavViewState.setup);
    }

    try {
      final status = await repo.checkContainerStatus();
      final running = status['running'] as bool? ?? false;

      if (running) {
        final maps = await repo.fetchMaps();
        final navStatus = await repo.fetchNavStatus();
        final navParams = await _fetchSavedNavParams(repo);
        final selectedMap = await _fetchCurrentMapName(repo, maps);
        final pgmBytes = selectedMap == null
            ? null
            : await repo.fetchMapPgm(selectedMap);
        final mapMeta = selectedMap == null
            ? null
            : _buildMapMeta(
                mapName: selectedMap,
                pgmBytes: pgmBytes,
                maps: maps,
              );
        final savedRoutes = selectedMap == null
            ? const <NavLandmark>[]
            : await _fetchSavedRoutes(repo, selectedMap);
        final initialState = NavigationState(
          viewState: NavViewState.active,
          maps: maps,
          selectedMap: selectedMap,
          pgmBytes: pgmBytes,
          mapMeta: mapMeta,
          navStatus: navStatus?.status ?? NavigationStatus.vacant,
          relocalization: navStatus?.relocalizationRaw.isNotEmpty ?? false,
          navParams: navParams,
          savedRoutes: savedRoutes,
        );
        _startStatusPolling(repo);
        return initialState;
      } else {
        final maps = await repo.fetchMaps();
        final navParams = await _fetchSavedNavParams(repo);
        return NavigationState(
          viewState: NavViewState.setup,
          maps: maps,
          selectedMap: maps.isNotEmpty ? maps.first.name : null,
          navParams: navParams,
        );
      }
    } catch (e) {
      return NavigationState(
        viewState: NavViewState.setup,
        error: e.toString(),
      );
    }
  }

  void _onOdometry(RobotOdometry odom) {
    final current = state.value;
    if (current == null) return;
    final traj = List<RobotOdometry>.from(current.trajectory)..add(odom);
    if (traj.length > 500) traj.removeRange(0, traj.length - 500);
    state = AsyncValue.data(
      current.copyWith(robotPose: odom, trajectory: traj),
    );
  }

  Future<NavParamForm> _fetchSavedNavParams(NavigationRepository repo) async {
    try {
      final params = await repo.getSavedNavParams(navParamNames);
      return NavParamForm.fromSavedParams(params);
    } catch (_) {
      return const NavParamForm();
    }
  }

  Future<String?> _fetchCurrentMapName(
    NavigationRepository repo,
    List<MapInfo> maps,
  ) async {
    try {
      final params = await repo.getNavParams(['current_map']);
      final entry = params['current_map'];
      if (entry is Map<String, dynamic> &&
          entry['success'] == true &&
          entry['value'] != null) {
        return entry['value'].toString();
      }
    } catch (_) {}
    return maps.isNotEmpty ? maps.first.name : null;
  }

  Future<List<NavLandmark>> _fetchSavedRoutes(
    NavigationRepository repo,
    String sceneName,
  ) async {
    try {
      final landmarks = await repo.fetchLandmarks(sceneName);
      return landmarks
          .map(NavLandmark.fromJson)
          .where(
            (landmark) =>
                landmark.kind == 'route' && landmark.points.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  MapMeta _buildMapMeta({
    required String mapName,
    required Uint8List? pgmBytes,
    required List<MapInfo> maps,
  }) {
    var width = 500;
    var height = 500;
    if (pgmBytes != null) {
      try {
        final pgm = parsePgm(pgmBytes);
        width = pgm.width;
        height = pgm.height;
      } catch (_) {}
    }

    MapInfo? info;
    for (final map in maps) {
      if (map.name == mapName) {
        info = map;
        break;
      }
    }

    final resolution = info?.resolution ?? 0.05;
    final origin = info?.origin;

    return MapMeta(
      width: width,
      height: height,
      resolution: resolution,
      originX: origin != null && origin.length >= 2 ? origin[0] : -12.5,
      originY: origin != null && origin.length >= 2 ? origin[1] : -12.5,
    );
  }

  void _startStatusPolling(NavigationRepository repo) {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final navStatus = await repo.fetchNavStatus();
        final current = state.value;
        if (current != null && navStatus != null) {
          state = AsyncValue.data(
            current.copyWith(navStatus: navStatus.status),
          );
        }
      } catch (_) {}
    });
  }

  void _startMissionPolling(NavigationRepository repo, String missionId) {
    _missionPollTimer?.cancel();
    _missionPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final mission = MissionInfo.fromJson(
          await repo.fetchMission(missionId),
        );
        final current = state.value;
        if (current == null) return;
        state = AsyncValue.data(
          current.copyWith(
            activeMission: mission.id.isEmpty ? current.activeMission : mission,
            navStatus: _statusFromMission(mission.status, current.navStatus),
          ),
        );
        if (!mission.isActive) {
          _missionPollTimer?.cancel();
        }
      } catch (_) {}
    });
  }

  NavigationStatus _statusFromMission(
    String status,
    NavigationStatus fallback,
  ) {
    switch (status) {
      case 'pending':
      case 'running':
      case 'active':
        return NavigationStatus.navigating;
      case 'paused':
        return NavigationStatus.paused;
      case 'completed':
      case 'succeeded':
      case 'success':
        return NavigationStatus.arrived;
      case 'failed':
      case 'error':
        return NavigationStatus.failed;
      case 'cancelled':
      case 'canceled':
      case 'stopped':
        return NavigationStatus.stopped;
      default:
        return fallback;
    }
  }

  // ─── Map selection ─────────────────────────────────────────

  Future<void> selectMap(String name) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(selectedMap: name, loading: true, error: null),
    );

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      final pgmBytes = await repo.fetchMapPgm(name);
      final savedRoutes = await _fetchSavedRoutes(repo, name);
      final meta = _buildMapMeta(
        mapName: name,
        pgmBytes: pgmBytes,
        maps: current.maps,
      );

      state = AsyncValue.data(
        current.copyWith(
          selectedMap: name,
          pgmBytes: pgmBytes,
          mapMeta: meta,
          savedRoutes: savedRoutes,
          loading: false,
        ),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  // ─── Container control ─────────────────────────────────────

  void updateNavParam(NavParamField field, double value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        navParams: current.navParams.withField(field, value),
        navParamsDirty: true,
        navParamsMessage: null,
      ),
    );
  }

  void setHolonomic(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        navParams: current.navParams.copyWith(holonomic: value),
        navParamsDirty: true,
        navParamsMessage: null,
      ),
    );
  }

  Future<void> reloadSavedNavParams() async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(loading: true, navParamsMessage: null, error: null),
    );

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;
      final params = await _fetchSavedNavParams(repo);
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(
          navParams: params,
          navParamsDirty: false,
          navParamsMessage: '已加载已保存参数',
          loading: false,
        ),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> applyNavParams() async {
    final current = state.value;
    if (current == null) return;
    final payload = current.navParams.toPayload();
    if (payload == null) {
      state = AsyncValue.data(
        current.copyWith(navParamsMessage: '本体长度和宽度必须大于 0'),
      );
      return;
    }

    state = AsyncValue.data(
      current.copyWith(loading: true, navParamsMessage: null, error: null),
    );

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;
      await repo.setNavParams(payload);
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(
          loading: false,
          navParamsDirty: false,
          navParamsMessage: '参数已应用',
        ),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> startNavContainer() async {
    final current = state.value;
    if (current == null) return;

    final mapName = current.selectedMap;
    if (mapName == null) return;

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      await repo.startNavContainer(
        mapName,
        relocalization: current.relocalization,
      );

      // Wait briefly then check status
      await Future<void>.delayed(const Duration(seconds: 1));
      final navStatus = await repo.fetchNavStatus();
      final savedRoutes = await _fetchSavedRoutes(repo, mapName);

      state = AsyncValue.data(
        current.copyWith(
          viewState: NavViewState.active,
          navStatus: navStatus?.status ?? NavigationStatus.vacant,
          savedRoutes: savedRoutes,
          loading: false,
        ),
      );
      _startStatusPolling(repo);
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  // ─── Navigation control ────────────────────────────────────

  void setGoalPoint(double wx, double wy, {double? theta}) {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        goalPoint: (wx, wy, theta ?? current.goalPoint?.$3 ?? 0.0),
        plannedPath: [],
        error: null,
      ),
    );
  }

  void setRelocalizationPose(double wx, double wy, {double? theta}) {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        relocalizationPose: (
          wx,
          wy,
          theta ?? current.relocalizationPose?.$3 ?? 0.0,
        ),
        error: null,
      ),
    );
  }

  Future<void> submitRelocalizationPose() async {
    final current = state.value;
    final pose = current?.relocalizationPose;
    if (current == null || pose == null) return;

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;
      await repo.setRelocalizationPose(pose.$1, pose.$2, pose.$3);
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, navParamsMessage: '初始位姿已提交'),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  void setSingleMissionMode(SingleMissionMode mode) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(singleMissionMode: mode));
  }

  Future<void> startSingleMission() async {
    final current = state.value;
    final goal = current?.goalPoint;
    if (current == null ||
        goal == null ||
        current.activeMission?.isActive == true) {
      return;
    }

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      final mode = current.singleMissionMode == SingleMissionMode.direct
          ? 'direct'
          : 'standard';
      final mission = MissionInfo.fromJson(
        await repo.createMission({
          'mode': mode,
          'frame_id': 'map',
          'target': {'x': goal.$1, 'y': goal.$2, 'theta': goal.$3},
        }),
      );

      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(
          loading: false,
          activeMission: mission,
          navStatus: _statusFromMission(
            mission.status,
            NavigationStatus.navigating,
          ),
        ),
      );
      if (mission.id.isNotEmpty) {
        _startMissionPolling(repo, mission.id);
      }
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> navigateTo(double wx, double wy) async {
    setGoalPoint(wx, wy);
    await startSingleMission();
  }

  Future<void> startPathNav(int cycles) async {
    final current = state.value;
    if (current == null ||
        current.waypoints.isEmpty ||
        current.activeMission?.isActive == true) {
      return;
    }

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      final mission = MissionInfo.fromJson(
        await repo.createMission({
          'mode': 'route',
          'frame_id': 'map',
          'waypoints': current.waypoints
              .map((w) => {'x': w.x, 'y': w.y, 'theta': w.theta})
              .toList(),
          'cycles': cycles,
        }),
      );

      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(
          loading: false,
          activeMission: mission,
          navStatus: _statusFromMission(
            mission.status,
            NavigationStatus.navigating,
          ),
        ),
      );
      if (mission.id.isNotEmpty) {
        _startMissionPolling(repo, mission.id);
      }
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> refreshSavedRoutes() async {
    final current = state.value;
    final sceneName = current?.selectedMap;
    if (current == null || sceneName == null) return;

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;
      final routes = await _fetchSavedRoutes(repo, sceneName);
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(savedRoutes: routes, loading: false),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  void loadSavedRoute(NavLandmark route) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        navMode: NavMode.path,
        waypoints: route.points,
        error: null,
      ),
    );
  }

  Future<void> startSavedRoute(NavLandmark route, int cycles) async {
    final current = state.value;
    if (current == null || current.activeMission?.isActive == true) return;

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;
      final result = await repo.startLandmark(route.id, cycles);
      final mission = MissionInfo.fromJson(result);
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(
          loading: false,
          activeMission: mission.id.isEmpty ? cur.activeMission : mission,
          navStatus: mission.id.isEmpty
              ? NavigationStatus.navigating
              : _statusFromMission(mission.status, NavigationStatus.navigating),
        ),
      );
      if (mission.id.isNotEmpty) {
        _startMissionPolling(repo, mission.id);
      }
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> saveCurrentRoute(String name) async {
    final current = state.value;
    final sceneName = current?.selectedMap;
    if (current == null ||
        sceneName == null ||
        name.trim().isEmpty ||
        current.waypoints.length < 2) {
      return;
    }

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;
      await repo.saveLandmark(
        name: name.trim(),
        sceneName: sceneName,
        kind: 'route',
        points: current.waypoints,
      );
      final routes = await _fetchSavedRoutes(repo, sceneName);
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(savedRoutes: routes, loading: false),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> pause() async {
    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      await repo?.pauseNav();
    } catch (e) {
      final cur = state.value;
      if (cur != null) {
        state = AsyncValue.data(cur.copyWith(error: e.toString()));
      }
    }
  }

  Future<void> resume() async {
    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      await repo?.resumeNav();
    } catch (e) {
      final cur = state.value;
      if (cur != null) {
        state = AsyncValue.data(cur.copyWith(error: e.toString()));
      }
    }
  }

  Future<void> stopTask() async {
    final current = state.value;
    if (current == null) return;

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      final mission = current.activeMission;
      if (mission != null && mission.isActive && mission.id.isNotEmpty) {
        await repo.cancelMission(mission.id);
      } else {
        await repo.stopNavigating();
      }

      _missionPollTimer?.cancel();

      state = AsyncValue.data(
        current.copyWith(
          navStatus: NavigationStatus.stopped,
          activeMission: null,
          plannedPath: [],
        ),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(cur.copyWith(error: e.toString()));
    }
  }

  Future<void> closeNavigation() async {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      final mission = current.activeMission;
      if (mission != null && mission.isActive && mission.id.isNotEmpty) {
        await repo.cancelMission(mission.id);
      } else {
        await repo.stopNavigating();
      }
      await repo.stopNavContainer();

      _missionPollTimer?.cancel();
      _statusPollTimer?.cancel();

      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(
          viewState: NavViewState.setup,
          navStatus: NavigationStatus.stopped,
          activeMission: null,
          goalPoint: null,
          waypoints: [],
          plannedPath: [],
          loading: false,
        ),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> returnToOrigin() async {
    // Navigate to world origin (0, 0) with heading 0
    setGoalPoint(0.0, 0.0, theta: 0.0);
    await startSingleMission();
  }

  // ─── Waypoint management ───────────────────────────────────

  void addWaypoint(double wx, double wy) {
    final current = state.value;
    if (current == null) return;
    final updated = List<Waypoint>.from(current.waypoints)
      ..add(Waypoint(x: wx, y: wy, theta: 0.0));
    state = AsyncValue.data(current.copyWith(waypoints: updated));
  }

  void removeWaypoint(int index) {
    final current = state.value;
    if (current == null) return;
    if (index < 0 || index >= current.waypoints.length) return;
    final updated = List<Waypoint>.from(current.waypoints)..removeAt(index);
    state = AsyncValue.data(current.copyWith(waypoints: updated));
  }

  // ─── Mode & settings ──────────────────────────────────────

  void setNavMode(NavMode mode) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(navMode: mode));
  }

  Future<void> toggleRelocalization() async {
    final current = state.value;
    if (current == null) return;

    final next = !current.relocalization;
    state = AsyncValue.data(current.copyWith(relocalization: next));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      await repo?.toggleRelocalization(next);
    } catch (e) {
      // Revert on error
      final cur = state.value ?? current;
      state = AsyncValue.data(
        cur.copyWith(relocalization: !next, error: e.toString()),
      );
    }
  }
}

final navigationProvider =
    AsyncNotifierProvider.autoDispose<NavigationNotifier, NavigationState>(
      NavigationNotifier.new,
    );
