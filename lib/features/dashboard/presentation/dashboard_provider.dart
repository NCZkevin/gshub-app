import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../data/dashboard_repository.dart';

// ─── Repository Provider ──────────────────────────────────────

final dashboardRepositoryProvider = FutureProvider<DashboardRepository?>((ref) async {
  final client = await ref.watch(dioClientFutureProvider.future);
  if (client == null) return null;
  return DashboardRepository(client);
});

// ─── Dashboard State ──────────────────────────────────────────

class DashboardState {
  final HubInfo? hubInfo;
  final RobotInfo? robotInfo;
  final List<ContainerInfo> modelContainers;
  final Map<String, dynamic>? servicesStatus;
  final List<String> motionAdapters;
  final bool loading;
  final String? error;

  const DashboardState({
    this.hubInfo,
    this.robotInfo,
    this.modelContainers = const [],
    this.servicesStatus,
    this.motionAdapters = const [],
    this.loading = false,
    this.error,
  });

  DashboardState copyWith({
    HubInfo? hubInfo,
    RobotInfo? robotInfo,
    List<ContainerInfo>? modelContainers,
    Map<String, dynamic>? servicesStatus,
    List<String>? motionAdapters,
    bool? loading,
    String? error,
  }) =>
      DashboardState(
        hubInfo: hubInfo ?? this.hubInfo,
        robotInfo: robotInfo ?? this.robotInfo,
        modelContainers: modelContainers ?? this.modelContainers,
        servicesStatus: servicesStatus ?? this.servicesStatus,
        motionAdapters: motionAdapters ?? this.motionAdapters,
        loading: loading ?? this.loading,
        error: error,
      );
}

class DashboardNotifier extends AutoDisposeAsyncNotifier<DashboardState> {
  Timer? _pollTimer;

  @override
  Future<DashboardState> build() async {
    ref.onDispose(() => _pollTimer?.cancel());
    await _load();
    _startPolling();
    return state.value ?? const DashboardState();
  }

  Future<void> _load() async {
    final repo = await ref.read(dashboardRepositoryProvider.future);
    if (repo == null) return;

    try {
      final results = await Future.wait([
        repo.fetchHubInfo(),
        repo.fetchRobotInfo(),
        repo.fetchContainers(serviceClass: 'model'),
        repo.fetchServicesStatus(),
        repo.fetchMotionAdapters(),
      ]);

      state = AsyncValue.data(DashboardState(
        hubInfo: results[0] as HubInfo?,
        robotInfo: results[1] as RobotInfo?,
        modelContainers: results[2] as List<ContainerInfo>,
        servicesStatus: results[3] as Map<String, dynamic>?,
        motionAdapters: results[4] as List<String>,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final repo = await ref.read(dashboardRepositoryProvider.future);
      if (repo == null) return;
      try {
        final info = await repo.fetchHubInfo();
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(current.copyWith(hubInfo: info));
        }
      } catch (_) {}
    });
  }

  Future<void> toggleContainer(ContainerInfo container) async {
    final repo = await ref.read(dashboardRepositoryProvider.future);
    if (repo == null) return;
    try {
      if (container.state == 'running') {
        await repo.stopContainer(container.name);
      } else {
        await repo.startContainer(container.name);
      }
      await _load();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> toggleMotion(bool start, {String adapter = 'go2'}) async {
    final repo = await ref.read(dashboardRepositoryProvider.future);
    if (repo == null) return;
    if (start) {
      await repo.startMotion(adapter);
    } else {
      await repo.stopMotion();
    }
    await _load();
  }
}

final dashboardProvider =
    AsyncNotifierProvider.autoDispose<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);
