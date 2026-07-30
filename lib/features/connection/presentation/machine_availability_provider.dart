import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/machine_connection_probe.dart';
import '../domain/connection_model.dart';
import 'connection_provider.dart';

enum MachineAvailabilityStatus {
  noMachine,
  checking,
  online,
  reconnecting,
  offline,
  authorizationRequired,
  identityMismatch,
}

class MachineAvailabilityState {
  final String? connectionId;
  final MachineAvailabilityStatus status;
  final String? message;
  final MachineConnectionFailureKind? failureKind;
  final DateTime? lastSeenAt;
  final int consecutiveFailures;

  const MachineAvailabilityState({
    required this.status,
    this.connectionId,
    this.message,
    this.failureKind,
    this.lastSeenAt,
    this.consecutiveFailures = 0,
  });

  const MachineAvailabilityState.noMachine()
    : this(status: MachineAvailabilityStatus.noMachine);

  bool get isUsable => status == MachineAvailabilityStatus.online;

  bool get isUnavailable => switch (status) {
    MachineAvailabilityStatus.reconnecting ||
    MachineAvailabilityStatus.offline ||
    MachineAvailabilityStatus.authorizationRequired ||
    MachineAvailabilityStatus.identityMismatch => true,
    _ => false,
  };
}

class MachineAvailabilityConfig {
  final Duration onlineInterval;
  final Duration reconnectInterval;
  final Duration offlineBaseInterval;
  final Duration maxOfflineInterval;
  final int failuresBeforeOffline;

  const MachineAvailabilityConfig({
    this.onlineInterval = const Duration(seconds: 5),
    this.reconnectInterval = const Duration(seconds: 3),
    this.offlineBaseInterval = const Duration(seconds: 5),
    this.maxOfflineInterval = const Duration(seconds: 30),
    this.failuresBeforeOffline = 2,
  });
}

final machineAvailabilityConfigProvider = Provider<MachineAvailabilityConfig>(
  (ref) => const MachineAvailabilityConfig(),
);

class MachineAvailabilityNotifier extends Notifier<MachineAvailabilityState> {
  Timer? _timer;
  RobotConnection? _connection;
  DateTime? _lastSeenAt;
  int _generation = 0;
  int _consecutiveFailures = 0;
  int? _inFlightGeneration;
  bool _disposeRegistered = false;

  @override
  MachineAvailabilityState build() {
    _timer?.cancel();
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() => _timer?.cancel());
    }

    final connection = ref.watch(activeConnectionProvider);
    _connection = connection;
    final generation = ++_generation;
    _consecutiveFailures = 0;
    _lastSeenAt = null;
    _inFlightGeneration = null;
    if (connection == null) {
      return const MachineAvailabilityState.noMachine();
    }

    scheduleMicrotask(() => _check(connection, generation));
    return MachineAvailabilityState(
      connectionId: connection.id,
      status: MachineAvailabilityStatus.checking,
      message: '正在连接机器…',
    );
  }

  Future<void> retry() async {
    final connection = _connection;
    if (connection == null) return;
    _timer?.cancel();
    ref.invalidate(activeNetworkReadyProvider);
    state = MachineAvailabilityState(
      connectionId: connection.id,
      status: MachineAvailabilityStatus.checking,
      message: '正在重新连接机器…',
      lastSeenAt: _lastSeenAt,
      consecutiveFailures: _consecutiveFailures,
    );
    await _check(connection, _generation);
  }

  Future<void> _check(RobotConnection connection, int generation) async {
    if (generation != _generation || _inFlightGeneration == generation) return;
    _inFlightGeneration = generation;
    try {
      await ref.read(activeNetworkReadyProvider.future);
      await ref.read(machineConnectionProbeProvider).probe(connection);
      if (!_isCurrent(connection, generation)) return;

      _consecutiveFailures = 0;
      _lastSeenAt = DateTime.now();
      state = MachineAvailabilityState(
        connectionId: connection.id,
        status: MachineAvailabilityStatus.online,
        message: '机器在线',
        lastSeenAt: _lastSeenAt,
      );
      _schedule(
        connection,
        generation,
        ref.read(machineAvailabilityConfigProvider).onlineInterval,
      );
    } catch (error) {
      if (!_isCurrent(connection, generation)) return;
      final failure = normalizeMachineConnectionError(error);
      if (failure.kind == MachineConnectionFailureKind.apNetwork) {
        ref.invalidate(activeNetworkReadyProvider);
      }
      _handleFailure(connection, generation, failure);
    } finally {
      if (_inFlightGeneration == generation) {
        _inFlightGeneration = null;
      }
    }
  }

  void _handleFailure(
    RobotConnection connection,
    int generation,
    MachineConnectionException failure,
  ) {
    final config = ref.read(machineAvailabilityConfigProvider);
    _consecutiveFailures++;

    final status = switch (failure.kind) {
      MachineConnectionFailureKind.authorizationRequired =>
        MachineAvailabilityStatus.authorizationRequired,
      MachineConnectionFailureKind.identityMismatch =>
        MachineAvailabilityStatus.identityMismatch,
      _ when _consecutiveFailures < config.failuresBeforeOffline =>
        MachineAvailabilityStatus.reconnecting,
      _ => MachineAvailabilityStatus.offline,
    };
    state = MachineAvailabilityState(
      connectionId: connection.id,
      status: status,
      message: failure.message,
      failureKind: failure.kind,
      lastSeenAt: _lastSeenAt,
      consecutiveFailures: _consecutiveFailures,
    );

    final delay = switch (status) {
      MachineAvailabilityStatus.reconnecting => config.reconnectInterval,
      MachineAvailabilityStatus.online => config.onlineInterval,
      _ => _offlineDelay(config),
    };
    _schedule(connection, generation, delay);
  }

  Duration _offlineDelay(MachineAvailabilityConfig config) {
    final exponent = math.max(
      0,
      _consecutiveFailures - config.failuresBeforeOffline,
    );
    final multiplier = 1 << math.min(exponent, 6);
    final milliseconds = math.min(
      config.maxOfflineInterval.inMilliseconds,
      config.offlineBaseInterval.inMilliseconds * multiplier,
    );
    return Duration(milliseconds: milliseconds);
  }

  void _schedule(RobotConnection connection, int generation, Duration delay) {
    if (!_isCurrent(connection, generation)) return;
    _timer?.cancel();
    _timer = Timer(delay, () => _check(connection, generation));
  }

  bool _isCurrent(RobotConnection connection, int generation) =>
      generation == _generation && _connection?.id == connection.id;
}

final machineAvailabilityProvider =
    NotifierProvider<MachineAvailabilityNotifier, MachineAvailabilityState>(
      MachineAvailabilityNotifier.new,
    );
