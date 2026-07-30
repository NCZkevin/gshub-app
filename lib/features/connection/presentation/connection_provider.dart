import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../data/connection_repository.dart';
import '../data/device_discovery_repository.dart';
import '../data/ap_network_service.dart';
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

final deviceDiscoveryRepositoryProvider = Provider<DeviceDiscoveryRepository>(
  (ref) => DeviceDiscoveryRepository(),
);

class AuthPromptNotifier extends Notifier<String?> {
  final Set<String> _suppressed = <String>{};

  @override
  String? build() => null;

  void requireToken(String connectionId) {
    if (_suppressed.contains(connectionId)) return;
    state ??= connectionId;
  }

  void dismiss() {
    if (state case final connectionId?) {
      _suppressed.add(connectionId);
    }
    state = null;
  }

  void reset(String connectionId) {
    _suppressed.remove(connectionId);
    if (state == connectionId) state = null;
  }
}

final authPromptProvider = NotifierProvider<AuthPromptNotifier, String?>(
  AuthPromptNotifier.new,
);

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
    required String id,
    required String name,
    required String baseUrl,
    String apiToken = '',
    String? terminalToken,
  }) async {
    final repo = ref.read(connectionRepositoryProvider);
    final conn = RobotConnection(id: id, name: name, baseUrl: baseUrl);
    await repo.save(conn);
    await repo.saveApiToken(id, apiToken);
    ref.read(authPromptProvider.notifier).reset(id);
    if (terminalToken != null && terminalToken.isNotEmpty) {
      await repo.saveTerminalToken(id, terminalToken);
    }
    state = state.copyWith(connections: repo.loadAll());
    // 自动选为活跃机器（如果是第一个）
    if (state.activeId == null) await activate(id);
  }

  Future<void> addDiscovered(DiscoveredRobot robot) async {
    final existing = state.connections
        .where((c) => c.id == robot.sn)
        .firstOrNull;
    final repo = ref.read(connectionRepositoryProvider);
    final keepAPMetadata =
        existing?.networkKind == ConnectionNetworkKind.ap &&
        Uri.tryParse(existing!.baseUrl)?.host ==
            Uri.tryParse(robot.baseUrl)?.host;
    final conn = RobotConnection(
      id: robot.sn,
      name: existing?.name ?? robot.sn,
      baseUrl: robot.baseUrl,
      networkKind: keepAPMetadata
          ? ConnectionNetworkKind.ap
          : ConnectionNetworkKind.lan,
      apSsid: keepAPMetadata ? existing.apSsid : null,
    );
    await repo.save(conn);
    if (!keepAPMetadata) await repo.deleteAPPassword(robot.sn);
    state = state.copyWith(connections: repo.loadAll());
    if (state.activeId == null) await activate(robot.sn);
    if (state.activeId == robot.sn) {
      ref.invalidate(dioClientProvider);
      ref.invalidate(dioClientFutureProvider);
      ref.invalidate(wsManagerProvider);
    }
  }

  Future<void> addProvisioned(DiscoveredRobot robot) async {
    final existing = state.connections
        .where((connection) => connection.id == robot.sn)
        .firstOrNull;
    final repo = ref.read(connectionRepositoryProvider);
    await repo.save(
      RobotConnection(
        id: robot.sn,
        name: existing?.name ?? robot.sn,
        baseUrl: robot.baseUrl,
        networkKind: ConnectionNetworkKind.lan,
      ),
    );
    await repo.deleteAPPassword(robot.sn);
    state = state.copyWith(connections: repo.loadAll());
    await activate(robot.sn);
    ref.invalidate(dioClientFutureProvider);
  }

  Future<void> addProvisionedAP({
    required DiscoveredRobot robot,
    required String ssid,
    required String password,
  }) async {
    final existing = state.connections
        .where((connection) => connection.id == robot.sn)
        .firstOrNull;
    final repo = ref.read(connectionRepositoryProvider);
    await repo.save(
      RobotConnection(
        id: robot.sn,
        name: existing?.name ?? robot.sn,
        baseUrl: robot.baseUrl,
        networkKind: ConnectionNetworkKind.ap,
        apSsid: ssid,
      ),
    );
    await repo.saveAPPassword(robot.sn, password);
    state = state.copyWith(connections: repo.loadAll());
    await activate(robot.sn);
    ref.invalidate(dioClientFutureProvider);
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
    final existing = state.connections
        .where((connection) => connection.id == id)
        .firstOrNull;
    final conn = RobotConnection(
      id: id,
      name: name,
      baseUrl: baseUrl,
      networkKind: existing?.networkKind ?? ConnectionNetworkKind.lan,
      apSsid: existing?.apSsid,
    );
    await repo.save(conn);
    await repo.saveApiToken(id, apiToken);
    ref.read(authPromptProvider.notifier).reset(id);
    state = state.copyWith(connections: repo.loadAll());
    // Re-init active connection if this is the active one
    if (state.activeId == id) {
      ref.invalidate(dioClientProvider);
      ref.invalidate(dioClientFutureProvider);
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

final activeNetworkReadyProvider = FutureProvider<void>((ref) async {
  final connection = ref.watch(activeConnectionProvider);
  final service = ref.read(apNetworkServiceProvider);
  if (connection == null ||
      connection.networkKind != ConnectionNetworkKind.ap) {
    await service.release(forget: true);
    return;
  }
  final ssid = connection.apSsid?.trim() ?? '';
  if (ssid.isEmpty) {
    throw const APNetworkException('AP_SSID_MISSING', '机器人热点名称缺失');
  }
  final repository = ref.read(connectionRepositoryProvider);
  final password = await repository.getAPPassword(connection.id) ?? '';
  if (password.isEmpty) {
    throw const APNetworkException('AP_PASSWORD_MISSING', '机器人热点密码缺失');
  }
  await service.join(ssid: ssid, password: password);
});

final dioClientProvider = Provider<DioClient?>((ref) {
  // Token 是异步读取的，通过 dioClientFutureProvider 使用
  return null;
});

final dioClientFutureProvider = FutureProvider<DioClient?>((ref) async {
  final conn = ref.watch(activeConnectionProvider);
  if (conn == null) return null;
  await ref.watch(activeNetworkReadyProvider.future);
  final repo = ref.read(connectionRepositoryProvider);
  final token = await repo.getApiToken(conn.id);
  return DioClient.create(
    baseUrl: conn.baseUrl,
    authToken: token,
    onUnauthorized: () {
      ref.read(authPromptProvider.notifier).requireToken(conn.id);
    },
  );
});

final wsManagerProvider = Provider<WsConnectionManager>((ref) {
  final manager = WsConnectionManager();
  final conn = ref.watch(activeConnectionProvider);
  final networkReady = ref.watch(activeNetworkReadyProvider);
  if (conn != null && networkReady.hasValue) {
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
