import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../data/dashboard_repository.dart';

// ─── Repository Provider ──────────────────────────────────────

final dashboardRepositoryProvider = FutureProvider<DashboardRepository?>((
  ref,
) async {
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
  final List<Map<String, dynamic>> motionItems;
  final String selectedMotionAdapter;
  final String activeMotionAdapter;
  final Set<String> pendingActions;
  final bool scanStarting;
  final bool loading;
  final String? error;

  const DashboardState({
    this.hubInfo,
    this.robotInfo,
    this.modelContainers = const [],
    this.servicesStatus,
    this.motionAdapters = const [],
    this.motionItems = const [],
    this.selectedMotionAdapter = 'go2',
    this.activeMotionAdapter = '',
    this.pendingActions = const {},
    this.scanStarting = false,
    this.loading = false,
    this.error,
  });

  DashboardState copyWith({
    HubInfo? hubInfo,
    RobotInfo? robotInfo,
    List<ContainerInfo>? modelContainers,
    Map<String, dynamic>? servicesStatus,
    List<String>? motionAdapters,
    List<Map<String, dynamic>>? motionItems,
    String? selectedMotionAdapter,
    String? activeMotionAdapter,
    Set<String>? pendingActions,
    bool? scanStarting,
    bool? loading,
    String? error,
  }) => DashboardState(
    hubInfo: hubInfo ?? this.hubInfo,
    robotInfo: robotInfo ?? this.robotInfo,
    modelContainers: modelContainers ?? this.modelContainers,
    servicesStatus: servicesStatus ?? this.servicesStatus,
    motionAdapters: motionAdapters ?? this.motionAdapters,
    motionItems: motionItems ?? this.motionItems,
    selectedMotionAdapter: selectedMotionAdapter ?? this.selectedMotionAdapter,
    activeMotionAdapter: activeMotionAdapter ?? this.activeMotionAdapter,
    pendingActions: pendingActions ?? this.pendingActions,
    scanStarting: scanStarting ?? this.scanStarting,
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
      final results = await Future.wait<dynamic>([
        _safe(() => repo.fetchHubInfo(), null),
        _safe(() => repo.fetchRobotInfo(), null),
        _safe(
          () => repo.fetchContainers(serviceClass: 'model'),
          <ContainerInfo>[],
        ),
        _safe(() => repo.fetchServicesStatus(), null),
        _safe(() => repo.fetchMotionAdapters(), <String>[]),
        _safe(() => repo.fetchMotionItems(), <Map<String, dynamic>>[]),
      ]);

      final servicesStatus = results[3] as Map<String, dynamic>?;
      final adapters = results[4] as List<String>;
      final motionItems = results[5] as List<Map<String, dynamic>>;
      final current = state.value;
      final selected = adapters.contains(current?.selectedMotionAdapter)
          ? current!.selectedMotionAdapter
          : (adapters.isNotEmpty ? adapters.first : 'go2');
      final motionDetail = servicesStatus?['motion']?['detail'];
      final activeAdapter = motionDetail is Map<String, dynamic>
          ? motionDetail['active_adapter']?.toString() ?? ''
          : '';

      state = AsyncValue.data(
        DashboardState(
          hubInfo: results[0] as HubInfo?,
          robotInfo: results[1] as RobotInfo?,
          modelContainers: results[2] as List<ContainerInfo>,
          servicesStatus: servicesStatus,
          motionAdapters: adapters.isEmpty ? const ['go2'] : adapters,
          motionItems: motionItems,
          selectedMotionAdapter: selected,
          activeMotionAdapter: activeAdapter,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<T> _safe<T>(Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } catch (_) {
      return fallback;
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final repo = await ref.read(dashboardRepositoryProvider.future);
      if (repo == null) return;
      try {
        final info = await repo.fetchHubInfo();
        final servicesStatus = await repo.fetchServicesStatus();
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(
            current.copyWith(
              hubInfo: info,
              servicesStatus: servicesStatus,
              activeMotionAdapter: _activeMotionAdapter(servicesStatus),
            ),
          );
        }
      } catch (_) {}
    });
  }

  String _activeMotionAdapter(Map<String, dynamic>? servicesStatus) {
    final motionDetail = servicesStatus?['motion']?['detail'];
    if (motionDetail is! Map<String, dynamic>) return '';
    return motionDetail['active_adapter']?.toString() ?? '';
  }

  void selectMotionAdapter(String adapter) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(selectedMotionAdapter: adapter));
  }

  void _setPending(String id, bool pending) {
    final current = state.value;
    if (current == null) return;
    final next = Set<String>.from(current.pendingActions);
    if (pending) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = AsyncValue.data(current.copyWith(pendingActions: next));
  }

  Future<void> toggleContainer(ContainerInfo container) async {
    final repo = await ref.read(dashboardRepositoryProvider.future);
    if (repo == null) return;
    try {
      _setPending('container:${container.name}', true);
      final containerState = container.state.toUpperCase();
      if (containerState == 'RUNNING' || containerState == 'HEALTHY') {
        await repo.stopContainer(container.name);
      } else {
        await repo.startContainer(container.name);
      }
      await _load();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _setPending('container:${container.name}', false);
    }
  }

  Future<void> toggleMotion(bool start, {String adapter = 'go2'}) async {
    final repo = await ref.read(dashboardRepositoryProvider.future);
    if (repo == null) return;
    try {
      _setPending('motion', true);
      if (start) {
        await repo.startMotion(adapter);
      } else {
        await repo.stopMotion();
      }
      await _load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _setPending('motion', false);
    }
  }

  Future<void> toggleScan(bool start) async {
    final repo = await ref.read(dashboardRepositoryProvider.future);
    if (repo == null) return;
    try {
      _setPending('scan', true);
      if (start) {
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(current.copyWith(scanStarting: true));
        }
        await repo.startScan();
        await _waitForScanRunning(repo);
      } else {
        await repo.stopScan();
      }
      await _load();
    } finally {
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.copyWith(scanStarting: false));
      }
      _setPending('scan', false);
    }
  }

  Future<void> _waitForScanRunning(DashboardRepository repo) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final scan = await repo.fetchScanStatus();
      final current = state.value;
      if (current != null && scan != null) {
        final merged = Map<String, dynamic>.from(current.servicesStatus ?? {});
        merged['scan'] = scan;
        state = AsyncValue.data(current.copyWith(servicesStatus: merged));
      }
      if (scan?['status'] == 'running') return;
    }
  }

  Future<void> toggleSemantic(bool start) async {
    final repo = await ref.read(dashboardRepositoryProvider.future);
    if (repo == null) return;
    try {
      _setPending('semantic', true);
      if (start) {
        await repo.startSemantic();
      } else {
        await repo.stopSemantic();
      }
      await _load();
    } finally {
      _setPending('semantic', false);
    }
  }

  Future<void> triggerMotion(String id) async {
    final repo = await ref.read(dashboardRepositoryProvider.future);
    if (repo == null) return;
    try {
      _setPending('motion-action:$id', true);
      await repo.triggerMotion(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _setPending('motion-action:$id', false);
    }
  }
}

final dashboardProvider =
    AsyncNotifierProvider.autoDispose<DashboardNotifier, DashboardState>(
      DashboardNotifier.new,
    );
