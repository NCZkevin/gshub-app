import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../data/connection_repository.dart';
import '../data/device_discovery_repository.dart';
import '../data/ap_network_service.dart';
import '../data/machine_connection_probe.dart';
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
  final String? switchingId;
  final String? switchErrorId;
  final String? switchError;
  final MachineConnectionFailureKind? switchFailureKind;

  const ConnectionState({
    required this.connections,
    required this.activeId,
    this.switchingId,
    this.switchErrorId,
    this.switchError,
    this.switchFailureKind,
  });

  RobotConnection? get active =>
      connections.where((c) => c.id == activeId).firstOrNull;

  ConnectionState copyWith({
    List<RobotConnection>? connections,
    String? activeId,
    String? switchingId,
    bool clearSwitching = false,
    String? switchErrorId,
    String? switchError,
    MachineConnectionFailureKind? switchFailureKind,
    bool clearSwitchError = false,
  }) => ConnectionState(
    connections: connections ?? this.connections,
    activeId: activeId ?? this.activeId,
    switchingId: clearSwitching ? null : (switchingId ?? this.switchingId),
    switchErrorId: clearSwitchError
        ? null
        : (switchErrorId ?? this.switchErrorId),
    switchError: clearSwitchError ? null : (switchError ?? this.switchError),
    switchFailureKind: clearSwitchError
        ? null
        : (switchFailureKind ?? this.switchFailureKind),
  );
}

class ConnectionNotifier extends Notifier<ConnectionState> {
  int _switchGeneration = 0;
  Future<void> _commitTail = Future<void>.value();

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
    if (state.activeId == null) {
      final switched = await activate(id);
      if (!switched) throw StateError(state.switchError ?? '无法连接机器');
    }
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
    if (state.activeId == null) {
      final switched = await activate(robot.sn);
      if (!switched) throw StateError(state.switchError ?? '无法连接机器');
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
    final switched = await activate(robot.sn);
    if (!switched) throw StateError(state.switchError ?? '无法连接机器');
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
    final switched = await activate(robot.sn);
    if (!switched) throw StateError(state.switchError ?? '无法连接机器');
  }

  Future<bool> activate(String id) async {
    final candidate = state.connections
        .where((item) => item.id == id)
        .firstOrNull;
    if (candidate == null) return false;
    if (state.activeId == id && state.switchingId == null) return true;

    final previous = state.active;
    final generation = ++_switchGeneration;
    state = state.copyWith(switchingId: id, clearSwitchError: true);
    final repo = ref.read(connectionRepositoryProvider);
    try {
      await _prepareNetwork(candidate, repo);
      await ref.read(machineConnectionProbeProvider).probe(candidate);
      if (generation != _switchGeneration) return false;

      return _commitActive(id, generation, repo);
    } catch (error) {
      if (generation != _switchGeneration) return false;
      final failure = normalizeMachineConnectionError(error);
      await _restoreNetwork(previous, repo);
      if (generation != _switchGeneration) return false;
      state = state.copyWith(
        clearSwitching: true,
        switchErrorId: id,
        switchError: failure.message,
        switchFailureKind: failure.kind,
      );
      return false;
    }
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
    if (state.activeId == id && existing?.baseUrl != baseUrl) {
      await ref.read(machineConnectionProbeProvider).probe(conn);
    }
    await repo.save(conn);
    await repo.saveApiToken(id, apiToken);
    ref.read(authPromptProvider.notifier).reset(id);
    state = state.copyWith(connections: repo.loadAll());
  }

  Future<void> delete(String id) async {
    if (state.switchingId == id) _switchGeneration++;
    final repo = ref.read(connectionRepositoryProvider);
    await repo.delete(id);
    state = ConnectionState(
      connections: repo.loadAll(),
      activeId: repo.getActiveId(),
    );
  }

  void clearSwitchError(String id) {
    if (state.switchErrorId != id) return;
    state = state.copyWith(clearSwitchError: true);
  }

  Future<void> _prepareNetwork(
    RobotConnection connection,
    ConnectionRepository repository,
  ) async {
    final service = ref.read(apNetworkServiceProvider);
    if (connection.networkKind != ConnectionNetworkKind.ap) {
      await service.release(forget: true);
      return;
    }
    final ssid = connection.apSsid?.trim() ?? '';
    if (ssid.isEmpty) {
      throw const APNetworkException('AP_SSID_MISSING', '机器人热点名称缺失');
    }
    final password = await repository.getAPPassword(connection.id) ?? '';
    if (password.isEmpty) {
      throw const APNetworkException('AP_PASSWORD_MISSING', '机器人热点密码缺失');
    }
    await service.join(ssid: ssid, password: password);
  }

  Future<void> _restoreNetwork(
    RobotConnection? previous,
    ConnectionRepository repository,
  ) async {
    try {
      if (previous == null ||
          previous.networkKind != ConnectionNetworkKind.ap) {
        await ref.read(apNetworkServiceProvider).release(forget: true);
        return;
      }
      await _prepareNetwork(previous, repository);
    } catch (_) {
      // Keep the original switch failure. The availability monitor will
      // report if restoring the previous machine also failed.
    }
  }

  Future<bool> _commitActive(
    String id,
    int generation,
    ConnectionRepository repository,
  ) async {
    final previousCommit = _commitTail;
    final completed = Completer<void>();
    _commitTail = completed.future;
    await previousCommit;
    try {
      if (generation != _switchGeneration) return false;
      final previousActiveId = state.activeId;
      await repository.setActive(id);
      if (generation != _switchGeneration) {
        if (previousActiveId == null) {
          await repository.clearActive();
        } else {
          await repository.setActive(previousActiveId);
        }
        return false;
      }
      state = state.copyWith(
        activeId: id,
        clearSwitching: true,
        clearSwitchError: true,
      );
      return true;
    } finally {
      completed.complete();
    }
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
