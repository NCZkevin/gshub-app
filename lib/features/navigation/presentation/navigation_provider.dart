import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/map_coords.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../data/navigation_repository.dart';

// ─── Enums ───────────────────────────────────────────────────

enum NavViewState { checking, setup, active }

enum NavMode { singlePoint, path, record }

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
  final (double x, double y, double theta)? goalPoint;
  final List<Waypoint> waypoints;
  final List<(double x, double y)> plannedPath;
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
    this.goalPoint,
    this.waypoints = const [],
    this.plannedPath = const [],
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
    Object? goalPoint = _sentinel,
    List<Waypoint>? waypoints,
    List<(double, double)>? plannedPath,
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
      goalPoint: goalPoint == _sentinel
          ? this.goalPoint
          : goalPoint as (double, double, double)?,
      waypoints: waypoints ?? this.waypoints,
      plannedPath: plannedPath ?? this.plannedPath,
      relocalization: relocalization ?? this.relocalization,
      loading: loading ?? this.loading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

// ─── Repository Provider ──────────────────────────────────────

final navigationRepositoryProvider =
    FutureProvider<NavigationRepository?>((ref) async {
  final client = await ref.watch(dioClientFutureProvider.future);
  if (client == null) return null;
  return NavigationRepository(client);
});

// ─── Notifier ────────────────────────────────────────────────

class NavigationNotifier
    extends AutoDisposeAsyncNotifier<NavigationState> {
  StreamSubscription<RobotOdometry>? _odoSub;
  Timer? _statusPollTimer;

  @override
  Future<NavigationState> build() async {
    ref.onDispose(() {
      _odoSub?.cancel();
      _statusPollTimer?.cancel();
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
        final initialState = NavigationState(
          viewState: NavViewState.active,
          maps: maps,
          navStatus: navStatus?.status ?? NavigationStatus.vacant,
          relocalization: navStatus?.relocalizationRaw.isNotEmpty ?? false,
        );
        _startStatusPolling(repo);
        return initialState;
      } else {
        final maps = await repo.fetchMaps();
        return NavigationState(
          viewState: NavViewState.setup,
          maps: maps,
          selectedMap: maps.isNotEmpty ? maps.first.name : null,
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
      // Default MapMeta: resolution 0.05 m/px, origin (-10, -10)
      // Width/height derived from PGM if available, otherwise use 400x400
      const meta = MapMeta(
        resolution: 0.05,
        originX: -10.0,
        originY: -10.0,
        width: 400,
        height: 400,
      );

      state = AsyncValue.data(
        current.copyWith(
          selectedMap: name,
          pgmBytes: pgmBytes,
          mapMeta: meta,
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

  Future<void> startNavContainer() async {
    final current = state.value;
    if (current == null) return;

    final mapName = current.selectedMap;
    if (mapName == null) return;

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      await repo.startNavContainer(mapName, relocalization: current.relocalization);

      // Wait briefly then check status
      await Future<void>.delayed(const Duration(seconds: 1));
      final navStatus = await repo.fetchNavStatus();

      state = AsyncValue.data(
        current.copyWith(
          viewState: NavViewState.active,
          navStatus: navStatus?.status ?? NavigationStatus.vacant,
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

  Future<void> navigateTo(double wx, double wy) async {
    final current = state.value;
    if (current == null) return;

    const theta = 0.0;
    state = AsyncValue.data(
      current.copyWith(
        goalPoint: (wx, wy, theta),
        plannedPath: [],
        error: null,
      ),
    );

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      await repo.startNavigateTo(wx, wy, theta);

      // Fetch planned path
      try {
        final path = await repo.fetchPlanPath();
        final cur = state.value;
        if (cur != null) {
          state = AsyncValue.data(cur.copyWith(plannedPath: path));
        }
      } catch (_) {}
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(cur.copyWith(error: e.toString()));
    }
  }

  Future<void> startPathNav(int cycles) async {
    final current = state.value;
    if (current == null || current.waypoints.isEmpty) return;

    state = AsyncValue.data(current.copyWith(loading: true, error: null));

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      await repo.startPathNavigation(current.waypoints, cycles);

      final cur = state.value ?? current;
      state = AsyncValue.data(cur.copyWith(loading: false));
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

  Future<void> stopNav() async {
    final current = state.value;
    if (current == null) return;

    try {
      final repo = await ref.read(navigationRepositoryProvider.future);
      if (repo == null) return;

      await repo.stopNavigating();
      await repo.stopNavContainer();

      _statusPollTimer?.cancel();

      state = AsyncValue.data(
        current.copyWith(
          viewState: NavViewState.setup,
          navStatus: NavigationStatus.stopped,
          goalPoint: null,
          plannedPath: [],
        ),
      );
    } catch (e) {
      final cur = state.value ?? current;
      state = AsyncValue.data(cur.copyWith(error: e.toString()));
    }
  }

  Future<void> returnToOrigin() async {
    // Navigate to world origin (0, 0) with heading 0
    await navigateTo(0.0, 0.0);
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
