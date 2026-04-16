import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../data/logs_repository.dart';

// ─── Repository Provider ──────────────────────────────────────

final logsRepositoryProvider = FutureProvider<LogsRepository?>((ref) async {
  final client = await ref.watch(dioClientFutureProvider.future);
  if (client == null) return null;
  return LogsRepository(client);
});

// ─── Logs State ───────────────────────────────────────────────

class LogsState {
  final List<LogFileInfo> files;
  final String? selected;
  final String? content;
  final String searchQuery;
  final bool loading;
  final bool contentLoading;
  final String? error;

  const LogsState({
    this.files = const [],
    this.selected,
    this.content,
    this.searchQuery = '',
    this.loading = false,
    this.contentLoading = false,
    this.error,
  });

  List<LogFileInfo> get filteredFiles {
    if (searchQuery.isEmpty) return files;
    final q = searchQuery.toLowerCase();
    return files.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  LogsState copyWith({
    List<LogFileInfo>? files,
    String? selected,
    String? content,
    String? searchQuery,
    bool? loading,
    bool? contentLoading,
    String? error,
    bool clearError = false,
    bool clearSelected = false,
    bool clearContent = false,
  }) {
    return LogsState(
      files: files ?? this.files,
      selected: clearSelected ? null : (selected ?? this.selected),
      content: clearContent ? null : (content ?? this.content),
      searchQuery: searchQuery ?? this.searchQuery,
      loading: loading ?? this.loading,
      contentLoading: contentLoading ?? this.contentLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Logs Notifier ────────────────────────────────────────────

class LogsNotifier extends AutoDisposeAsyncNotifier<LogsState> {
  @override
  Future<LogsState> build() async {
    final repo = await ref.read(logsRepositoryProvider.future);
    if (repo == null) return const LogsState();
    try {
      final files = await repo.fetchList();
      return LogsState(files: files);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return const LogsState();
    }
  }

  Future<void> selectFile(String filename) async {
    final current = state.value ?? const LogsState();
    state = AsyncValue.data(
      current.copyWith(selected: filename, contentLoading: true, clearContent: true),
    );

    final repo = await ref.read(logsRepositoryProvider.future);
    if (repo == null) return;

    try {
      final content = await repo.fetchContent(filename);
      final updated = state.value ?? current;
      state = AsyncValue.data(
        updated.copyWith(content: content, contentLoading: false),
      );
    } catch (e) {
      final updated = state.value ?? current;
      state = AsyncValue.data(
        updated.copyWith(contentLoading: false, error: e.toString()),
      );
    }
  }

  Future<void> deleteFile(String filename) async {
    final current = state.value ?? const LogsState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));

    final repo = await ref.read(logsRepositoryProvider.future);
    if (repo == null) return;

    try {
      await repo.deleteLog(filename);
      final files = await repo.fetchList();
      final updated = state.value ?? current;
      state = AsyncValue.data(
        updated.copyWith(
          files: files,
          loading: false,
          clearSelected: updated.selected == filename,
          clearContent: updated.selected == filename,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<void> cleanup() async {
    final current = state.value ?? const LogsState();
    state = AsyncValue.data(current.copyWith(loading: true, clearError: true));

    final repo = await ref.read(logsRepositoryProvider.future);
    if (repo == null) return;

    try {
      await repo.cleanup();
      final files = await repo.fetchList();
      state = AsyncValue.data(
        LogsState(files: files),
      );
    } catch (e) {
      state = AsyncValue.data(
        current.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  void setSearch(String query) {
    final current = state.value ?? const LogsState();
    state = AsyncValue.data(current.copyWith(searchQuery: query));
  }
}

final logsProvider =
    AsyncNotifierProvider.autoDispose<LogsNotifier, LogsState>(
  LogsNotifier.new,
);
