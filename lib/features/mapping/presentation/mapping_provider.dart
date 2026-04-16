import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../data/mapping_repository.dart';

// ─── Repository Provider ──────────────────────────────────────

final mappingRepositoryProvider =
    FutureProvider<MappingRepository?>((ref) async {
  final client = await ref.watch(dioClientFutureProvider.future);
  if (client == null) return null;
  return MappingRepository(client);
});

// ─── View State Enum ─────────────────────────────────────────

enum MappingViewState { list, active }

// ─── Mapping State ────────────────────────────────────────────

class MappingState {
  final MappingViewState viewState;
  final List<MapInfo> maps;
  final bool containerRunning;
  final MappingStatus? mappingStatus;
  final String mapName;
  final bool loading;
  final String? error;

  const MappingState({
    this.viewState = MappingViewState.list,
    this.maps = const [],
    this.containerRunning = false,
    this.mappingStatus,
    this.mapName = '',
    this.loading = false,
    this.error,
  });

  MappingState copyWith({
    MappingViewState? viewState,
    List<MapInfo>? maps,
    bool? containerRunning,
    MappingStatus? mappingStatus,
    String? mapName,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearMappingStatus = false,
  }) {
    return MappingState(
      viewState: viewState ?? this.viewState,
      maps: maps ?? this.maps,
      containerRunning: containerRunning ?? this.containerRunning,
      mappingStatus:
          clearMappingStatus ? null : (mappingStatus ?? this.mappingStatus),
      mapName: mapName ?? this.mapName,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Mapping Notifier ─────────────────────────────────────────

class MappingNotifier extends AutoDisposeAsyncNotifier<MappingState> {
  Timer? _pollTimer;

  @override
  Future<MappingState> build() async {
    ref.onDispose(() => _pollTimer?.cancel());
    return await _loadInitial();
  }

  Future<MappingState> _loadInitial() async {
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return const MappingState();

    try {
      final results = await Future.wait([
        repo.fetchMaps(),
        repo.fetchContainerStatus(),
      ]);

      final maps = results[0] as List<MapInfo>;
      final containerStatus = results[1] as Map<String, dynamic>;
      final running = containerStatus['running'] as bool? ?? false;

      MappingStatus? mappingStatus;
      if (running) {
        try {
          mappingStatus = await repo.fetchMappingStatus();
        } catch (_) {}
      }

      final initialState = MappingState(
        maps: maps,
        containerRunning: running,
        mappingStatus: mappingStatus,
        viewState: running ? MappingViewState.active : MappingViewState.list,
      );

      if (running) {
        _startPolling();
      }

      return initialState;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return const MappingState();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final repo = await ref.read(mappingRepositoryProvider.future);
      if (repo == null) return;
      try {
        final mappingStatus = await repo.fetchMappingStatus();
        final current = state.value;
        if (current != null) {
          state = AsyncValue.data(
            current.copyWith(mappingStatus: mappingStatus),
          );
        }
      } catch (_) {}
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> startMapping(String name) async {
    if (name.trim().isEmpty) return;
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));

    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return;

    try {
      await repo.startMapping(name.trim());
      final mappingStatus = await repo.fetchMappingStatus();
      state = AsyncValue.data(
        current.copyWith(
          loading: false,
          containerRunning: true,
          viewState: MappingViewState.active,
          mappingStatus: mappingStatus,
          mapName: name.trim(),
          clearError: true,
        ),
      );
      _startPolling();
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> stopMapping() async {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));

    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return;

    try {
      await repo.stopMapping();
      _stopPolling();
      final maps = await repo.fetchMaps();
      state = AsyncValue.data(
        MappingState(
          maps: maps,
          containerRunning: false,
          viewState: MappingViewState.list,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> deleteMap(String name) async {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));

    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return;

    try {
      await repo.deleteMap(name);
      final maps = await repo.fetchMaps();
      state = AsyncValue.data(
        current.copyWith(maps: maps, loading: false, clearError: true),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final newState = await _loadInitial();
    state = AsyncValue.data(newState);
  }
}

final mappingProvider =
    AsyncNotifierProvider.autoDispose<MappingNotifier, MappingState>(
  MappingNotifier.new,
);
