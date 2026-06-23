import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../data/connection_repository.dart';
import '../domain/connection_model.dart';

// ─── Infrastructure Providers ────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override this provider in ProviderScope');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return ConnectionRepository(
    prefs: ref.watch(sharedPreferencesProvider),
    secure: ref.watch(secureStorageProvider),
  );
});

// ─── Connection State ─────────────────────────────────────────

class ConnectionState {
  final List<RobotConnection> connections;
  final String? activeId;

  const ConnectionState({required this.connections, required this.activeId});

  RobotConnection? get active =>
      connections.where((c) => c.id == activeId).firstOrNull;

  ConnectionState copyWith({
    List<RobotConnection>? connections,
    String? activeId,
  }) => ConnectionState(
    connections: connections ?? this.connections,
    activeId: activeId ?? this.activeId,
  );
}

class ConnectionNotifier extends Notifier<ConnectionState> {
  @override
  ConnectionState build() {
    final repo = ref.watch(connectionRepositoryProvider);
    return ConnectionState(
      connections: repo.loadAll(),
      activeId: repo.getActiveId(),
    );
  }

  Future<void> add({
    required String name,
    required String baseUrl,
    required String apiToken,
    String? terminalToken,
  }) async {
    final repo = ref.read(connectionRepositoryProvider);
    final id = repo.generateId();
    final conn = RobotConnection(id: id, name: name, baseUrl: baseUrl);
    await repo.save(conn);
    await repo.saveApiToken(id, apiToken);
    if (terminalToken != null && terminalToken.isNotEmpty) {
      await repo.saveTerminalToken(id, terminalToken);
    }
    state = state.copyWith(connections: repo.loadAll());
    // 自动选为活跃展位（如果是第一个）
    if (state.connections.length == 1) await activate(id);
  }

  Future<void> activate(String id) async {
    final repo = ref.read(connectionRepositoryProvider);
    await repo.setActive(id);
    state = state.copyWith(activeId: id);
    // 重建依赖 active connection 的 provider
    ref.invalidate(dioClientProvider);
    ref.invalidate(wsManagerProvider);
  }

  Future<void> update({
    required String id,
    required String name,
    required String baseUrl,
    required String apiToken,
  }) async {
    final repo = ref.read(connectionRepositoryProvider);
    final conn = RobotConnection(id: id, name: name, baseUrl: baseUrl);
    await repo.save(conn);
    await repo.saveApiToken(id, apiToken);
    state = state.copyWith(connections: repo.loadAll());
    // Re-init active connection if this is the active one
    if (state.activeId == id) {
      ref.invalidate(dioClientProvider);
      ref.invalidate(wsManagerProvider);
    }
  }

  Future<void> delete(String id) async {
    final repo = ref.read(connectionRepositoryProvider);
    await repo.delete(id);
    state = ConnectionState(
      connections: repo.loadAll(),
      activeId: repo.getActiveId(),
    );
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionState>(
      ConnectionNotifier.new,
    );

// ─── Active Connection Derived Providers ─────────────────────

final activeConnectionProvider = Provider<RobotConnection?>((ref) {
  return ref.watch(connectionProvider).active;
});

final dioClientProvider = Provider<DioClient?>((ref) {
  // Token 是异步读取的，通过 dioClientFutureProvider 使用
  return null;
});

final dioClientFutureProvider = FutureProvider<DioClient?>((ref) async {
  final conn = ref.watch(activeConnectionProvider);
  if (conn == null) return null;
  final repo = ref.read(connectionRepositoryProvider);
  final token = await repo.getApiToken(conn.id) ?? '';
  return DioClient.create(baseUrl: conn.baseUrl, authToken: token);
});

final wsManagerProvider = Provider<WsConnectionManager>((ref) {
  final manager = WsConnectionManager();
  final conn = ref.watch(activeConnectionProvider);
  if (conn != null) {
    final wsUrl = conn.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = Uri.parse(conn.baseUrl);
    final controlScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final controlWsUrl = Uri(
      scheme: controlScheme,
      host: uri.host,
      port: 9099,
    ).toString();
    manager.connect(odometryWsBaseUrl: wsUrl, controlWsUrl: controlWsUrl);
  }
  ref.onDispose(manager.dispose);
  return manager;
});
