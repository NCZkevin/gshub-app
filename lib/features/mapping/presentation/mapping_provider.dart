import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/connection/presentation/connection_provider.dart';
import '../../../core/utils/file_download.dart';
import '../../../shared/domain/app_models.dart';
import '../data/mapping_repository.dart';

final mappingRepositoryProvider = FutureProvider<MappingRepository?>((
  ref,
) async {
  final client = await ref.watch(dioClientFutureProvider.future);
  if (client == null) return null;
  return MappingRepository(client);
});

enum MappingViewState { list, starting, active, saving, detail, edit }

class MappingState {
  final MappingViewState viewState;
  final List<MapInfo> maps;
  final Map<String, dynamic>? containerState;
  final MappingStatus? mappingStatus;
  final String mapName;
  final String? selectedMap;
  final List<FileInfo> mapFiles;
  final Uint8List? mapPgmBytes;
  final double? mapResolution;
  final bool loading;
  final bool filesLoading;
  final bool initTimeout;
  final String? error;

  const MappingState({
    this.viewState = MappingViewState.list,
    this.maps = const [],
    this.containerState,
    this.mappingStatus,
    this.mapName = '',
    this.selectedMap,
    this.mapFiles = const [],
    this.mapPgmBytes,
    this.mapResolution,
    this.loading = false,
    this.filesLoading = false,
    this.initTimeout = false,
    this.error,
  });

  bool get containerRunning => containerState?['running'] as bool? ?? false;

  MappingState copyWith({
    MappingViewState? viewState,
    List<MapInfo>? maps,
    Map<String, dynamic>? containerState,
    MappingStatus? mappingStatus,
    String? mapName,
    String? selectedMap,
    List<FileInfo>? mapFiles,
    Uint8List? mapPgmBytes,
    double? mapResolution,
    bool? loading,
    bool? filesLoading,
    bool? initTimeout,
    String? error,
    bool clearContainerState = false,
    bool clearMappingStatus = false,
    bool clearSelectedMap = false,
    bool clearMapFiles = false,
    bool clearMapPgmBytes = false,
    bool clearMapResolution = false,
    bool clearError = false,
  }) {
    return MappingState(
      viewState: viewState ?? this.viewState,
      maps: maps ?? this.maps,
      containerState: clearContainerState
          ? null
          : (containerState ?? this.containerState),
      mappingStatus: clearMappingStatus
          ? null
          : (mappingStatus ?? this.mappingStatus),
      mapName: mapName ?? this.mapName,
      selectedMap: clearSelectedMap ? null : (selectedMap ?? this.selectedMap),
      mapFiles: clearMapFiles ? const [] : (mapFiles ?? this.mapFiles),
      mapPgmBytes: clearMapPgmBytes ? null : (mapPgmBytes ?? this.mapPgmBytes),
      mapResolution: clearMapResolution
          ? null
          : (mapResolution ?? this.mapResolution),
      loading: loading ?? this.loading,
      filesLoading: filesLoading ?? this.filesLoading,
      initTimeout: initTimeout ?? this.initTimeout,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MappingNotifier extends AutoDisposeAsyncNotifier<MappingState> {
  Timer? _statusTimer;
  Timer? _savingTimer;
  int _initializingPolls = 0;

  @override
  Future<MappingState> build() async {
    ref.onDispose(_cancelTimers);
    return _loadInitial();
  }

  Future<MappingState> _loadInitial() async {
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return const MappingState();

    try {
      final maps = await repo.fetchMaps();
      final containerState = await repo.fetchContainerStatus();
      return MappingState(
        maps: _sortMaps(maps),
        containerState: containerState,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return const MappingState();
    }
  }

  Future<void> refresh() async {
    _cancelTimers();
    state = const AsyncValue.loading();
    final next = await _loadInitial();
    state = AsyncValue.data(next);
  }

  Future<void> refreshMaps() async {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return _setNotConnected(current);

    try {
      final maps = await repo.fetchMaps();
      final containerState = await repo.fetchContainerStatus();
      state = AsyncValue.data(
        current.copyWith(
          maps: _sortMaps(maps),
          containerState: containerState,
          loading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> startMapping(String name) async {
    final trimmed = name.trim();
    final current = state.value ?? const MappingState();
    if (trimmed.isEmpty) {
      state = AsyncValue.data(current.copyWith(error: '请输入地图名称'));
      return;
    }
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      state = AsyncValue.data(current.copyWith(error: '地图名称不能为纯数字'));
      return;
    }

    state = AsyncValue.data(
      current.copyWith(
        loading: true,
        mapName: trimmed,
        clearMappingStatus: true,
        clearError: true,
        initTimeout: false,
      ),
    );

    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return _setNotConnected(current);

    try {
      await repo.startMapping(trimmed);
      _initializingPolls = 0;
      state = AsyncValue.data(
        current.copyWith(
          viewState: MappingViewState.starting,
          mapName: trimmed,
          loading: false,
          initTimeout: false,
          clearMappingStatus: true,
          clearError: true,
        ),
      );
      _startStartingPolling();
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> resumeMapping() async {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));

    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return _setNotConnected(current);

    try {
      final mappingStatus = await repo.fetchMappingStatus();
      final nextView = mappingStatus?.status == 'initializing'
          ? MappingViewState.starting
          : MappingViewState.active;
      state = AsyncValue.data(
        current.copyWith(
          viewState: nextView,
          mappingStatus: mappingStatus,
          mapName: mappingStatus?.sceneName ?? current.mapName,
          loading: false,
          initTimeout: false,
          clearError: true,
        ),
      );
      if (nextView == MappingViewState.starting) {
        _startStartingPolling();
      } else {
        _startActivePolling();
      }
    } catch (_) {
      state = AsyncValue.data(
        current.copyWith(
          viewState: MappingViewState.starting,
          loading: false,
          initTimeout: false,
          clearError: true,
        ),
      );
      _startStartingPolling();
    }
  }

  Future<void> cancelStarting() async {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return _setNotConnected(current);

    try {
      await repo.stopMapping();
    } catch (_) {
      // Best effort: startup may still be half-initialized.
    } finally {
      _cancelTimers();
      final maps = await _fetchMapsOrKeep(repo, current.maps);
      final containerState = await _fetchContainerOrNull(repo);
      state = AsyncValue.data(
        current.copyWith(
          viewState: MappingViewState.list,
          maps: maps,
          containerState: containerState,
          loading: false,
          initTimeout: false,
          clearMappingStatus: true,
          clearError: true,
        ),
      );
    }
  }

  Future<void> stopMapping() async {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return _setNotConnected(current);

    try {
      await repo.stopMapping();
      _statusTimer?.cancel();
      state = AsyncValue.data(
        current.copyWith(
          viewState: MappingViewState.saving,
          loading: false,
          clearError: true,
        ),
      );
      _startSavingPolling();
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
    if (repo == null) return _setNotConnected(current);

    try {
      await repo.deleteMap(name);
      final maps = await repo.fetchMaps();
      state = AsyncValue.data(
        current.copyWith(
          maps: _sortMaps(maps),
          loading: false,
          clearSelectedMap: current.selectedMap == name,
          clearMapFiles: current.selectedMap == name,
          clearMapPgmBytes: current.selectedMap == name,
          clearMapResolution: current.selectedMap == name,
          clearError: true,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> openDetail(String name) async {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(
      current.copyWith(
        viewState: MappingViewState.detail,
        selectedMap: name,
        filesLoading: true,
        clearMapFiles: true,
        clearMapPgmBytes: true,
        clearMapResolution: true,
        clearError: true,
      ),
    );

    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return _setNotConnected(current);

    try {
      final files = await repo.fetchMapFiles(name);
      final pgm = _findPgm(files);
      final yaml = _findYaml(files);
      Uint8List? pgmBytes;
      double? resolution = _mapInfo(name, current.maps)?.resolution;

      if (pgm != null) {
        pgmBytes = await repo.fetchMapFile(name, pgm.path);
      }
      if (resolution == null && yaml != null) {
        final yamlBytes = await repo.fetchMapFile(name, yaml.path);
        resolution = _parseResolution(yamlBytes);
      }

      final updated = state.value ?? current;
      state = AsyncValue.data(
        updated.copyWith(
          mapFiles: files,
          mapPgmBytes: pgmBytes,
          mapResolution: resolution,
          filesLoading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      final updated = state.value ?? current;
      state = AsyncValue.data(
        updated.copyWith(filesLoading: false, error: e.toString()),
      );
    }
  }

  void backToList() {
    _cancelTimers();
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(
      current.copyWith(
        viewState: MappingViewState.list,
        clearSelectedMap: true,
        clearMapFiles: true,
        clearMapPgmBytes: true,
        clearMapResolution: true,
        clearError: true,
      ),
    );
  }

  void openEditor() {
    final current = state.value ?? const MappingState();
    if (current.selectedMap == null || current.mapPgmBytes == null) return;
    state = AsyncValue.data(
      current.copyWith(viewState: MappingViewState.edit, clearError: true),
    );
  }

  void closeEditor() {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(
      current.copyWith(viewState: MappingViewState.detail, clearError: true),
    );
  }

  Future<void> saveEditedPgm(Uint8List bytes) async {
    final current = state.value ?? const MappingState();
    final name = current.selectedMap;
    if (name == null) return;
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));

    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return _setNotConnected(current);

    try {
      await repo.updateMapPgm(name, bytes);
      state = AsyncValue.data(
        current.copyWith(
          viewState: MappingViewState.detail,
          loading: false,
          mapPgmBytes: bytes,
          clearError: true,
        ),
      );
      await openDetail(name);
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<String> downloadArchive(String name) async {
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) throw StateError('未连接机器人');
    final bytes = await repo.fetchArchive(name);
    return saveDownloadedFile(filename: '$name.zip', bytes: bytes);
  }

  void _startStartingPolling() {
    _statusTimer?.cancel();
    _savingTimer?.cancel();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollStartingStatus(),
    );
    unawaited(_pollStartingStatus());
  }

  Future<void> _pollStartingStatus() async {
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return;

    try {
      final mappingStatus = await repo.fetchMappingStatus();
      if (mappingStatus == null) return;
      final current = state.value ?? const MappingState();
      if (mappingStatus.status != 'initializing') {
        _initializingPolls = 0;
        state = AsyncValue.data(
          current.copyWith(
            viewState: MappingViewState.active,
            mappingStatus: mappingStatus,
            mapName: mappingStatus.sceneName ?? current.mapName,
            initTimeout: false,
            loading: false,
            clearError: true,
          ),
        );
        _startActivePolling();
      } else {
        _initializingPolls += 1;
        state = AsyncValue.data(
          current.copyWith(
            mappingStatus: mappingStatus,
            initTimeout: _initializingPolls >= 30,
            loading: false,
          ),
        );
      }
    } catch (_) {
      // Container may still be coming up; keep polling.
    }
  }

  void _startActivePolling() {
    _statusTimer?.cancel();
    _savingTimer?.cancel();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollActiveStatus(),
    );
  }

  Future<void> _pollActiveStatus() async {
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return;
    try {
      final mappingStatus = await repo.fetchMappingStatus();
      final current = state.value;
      if (mappingStatus != null && current != null) {
        state = AsyncValue.data(
          current.copyWith(mappingStatus: mappingStatus, clearError: true),
        );
      }
    } catch (_) {}
  }

  void _startSavingPolling() {
    _savingTimer?.cancel();
    _savingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollSavingStatus(),
    );
    unawaited(_pollSavingStatus());
  }

  Future<void> _pollSavingStatus() async {
    final repo = await ref.read(mappingRepositoryProvider.future);
    if (repo == null) return;
    try {
      final containerState = await repo.fetchContainerStatus();
      final current = state.value ?? const MappingState();
      if (containerState['running'] as bool? ?? false) {
        state = AsyncValue.data(
          current.copyWith(containerState: containerState),
        );
        return;
      }

      _savingTimer?.cancel();
      final maps = await repo.fetchMaps();
      state = AsyncValue.data(
        current.copyWith(
          viewState: MappingViewState.list,
          maps: _sortMaps(maps),
          containerState: containerState,
          loading: false,
          clearMappingStatus: true,
          clearError: true,
        ),
      );
    } catch (_) {
      _savingTimer?.cancel();
      final current = state.value ?? const MappingState();
      final maps = await _fetchMapsOrKeep(repo, current.maps);
      state = AsyncValue.data(
        current.copyWith(
          viewState: MappingViewState.list,
          maps: maps,
          loading: false,
          clearMappingStatus: true,
          clearContainerState: true,
          clearError: true,
        ),
      );
    }
  }

  void _setNotConnected(MappingState fallback) {
    state = AsyncValue.data(
      fallback.copyWith(loading: false, filesLoading: false, error: '未连接机器人'),
    );
  }

  void _cancelTimers() {
    _statusTimer?.cancel();
    _savingTimer?.cancel();
    _statusTimer = null;
    _savingTimer = null;
  }

  List<MapInfo> _sortMaps(List<MapInfo> maps) {
    return [...maps]
      ..sort((a, b) => (b.modifiedTime ?? 0).compareTo(a.modifiedTime ?? 0));
  }

  Future<List<MapInfo>> _fetchMapsOrKeep(
    MappingRepository repo,
    List<MapInfo> fallback,
  ) async {
    try {
      return _sortMaps(await repo.fetchMaps());
    } catch (_) {
      return fallback;
    }
  }

  Future<Map<String, dynamic>?> _fetchContainerOrNull(
    MappingRepository repo,
  ) async {
    try {
      return await repo.fetchContainerStatus();
    } catch (_) {
      return null;
    }
  }

  MapInfo? _mapInfo(String name, List<MapInfo> maps) {
    for (final map in maps) {
      if (map.name == name) return map;
    }
    return null;
  }

  FileInfo? _findPgm(List<FileInfo> files) {
    for (final file in files) {
      if (file.name.toLowerCase().endsWith('.pgm')) return file;
    }
    return null;
  }

  FileInfo? _findYaml(List<FileInfo> files) {
    for (final file in files) {
      final lower = file.name.toLowerCase();
      if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return file;
    }
    return null;
  }

  double? _parseResolution(Uint8List yamlBytes) {
    final text = utf8.decode(yamlBytes, allowMalformed: true);
    final match = RegExp(
      r'^\s*resolution\s*:\s*([0-9.eE+-]+)',
      multiLine: true,
    ).firstMatch(text);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1)!);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }
}

final mappingProvider =
    AsyncNotifierProvider.autoDispose<MappingNotifier, MappingState>(
      MappingNotifier.new,
    );
