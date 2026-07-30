import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sysapp/features/connection/data/machine_connection_probe.dart';
import 'package:sysapp/features/connection/domain/connection_model.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';
import 'package:sysapp/features/connection/presentation/machine_availability_provider.dart';

void main() {
  test('an unreachable target never replaces the current machine', () async {
    final preferences = await _preferences();
    final probe = _FakeMachineConnectionProbe()
      ..handler = (_) async => throw const MachineConnectionException(
        MachineConnectionFailureKind.unreachable,
        '机器未开机，或不在当前网络',
      );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        machineConnectionProbeProvider.overrideWithValue(probe),
      ],
    );
    addTearDown(container.dispose);

    final switched = await container
        .read(connectionProvider.notifier)
        .activate('GS-OFFLINE');

    expect(switched, isFalse);
    expect(container.read(connectionProvider).activeId, 'GS-ONLINE');
    expect(preferences.getString('active_connection_id'), 'GS-ONLINE');
    expect(container.read(connectionProvider).switchError, '机器未开机，或不在当前网络');
  });

  test('a stale probe cannot overwrite a newer machine switch', () async {
    final preferences = await _preferences(includeThirdMachine: true);
    final first = Completer<MachineProbeResult>();
    final second = Completer<MachineProbeResult>();
    final probe = _FakeMachineConnectionProbe()
      ..handler = (connection) => switch (connection.id) {
        'GS-OFFLINE' => first.future,
        'GS-THIRD' => second.future,
        _ => throw StateError('Unexpected connection ${connection.id}'),
      };
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        machineConnectionProbeProvider.overrideWithValue(probe),
      ],
    );
    addTearDown(container.dispose);

    final firstSwitch = container
        .read(connectionProvider.notifier)
        .activate('GS-OFFLINE');
    final secondSwitch = container
        .read(connectionProvider.notifier)
        .activate('GS-THIRD');
    second.complete(const MachineProbeResult(sn: 'GS-THIRD'));
    expect(await secondSwitch, isTrue);
    first.complete(const MachineProbeResult(sn: 'GS-OFFLINE'));
    expect(await firstSwitch, isFalse);

    expect(container.read(connectionProvider).activeId, 'GS-THIRD');
    expect(preferences.getString('active_connection_id'), 'GS-THIRD');
  });

  test(
    'the active machine becomes offline after two failures and recovers',
    () async {
      var attempts = 0;
      final probe = _FakeMachineConnectionProbe()
        ..handler = (_) async {
          attempts++;
          if (attempts <= 2) {
            throw const MachineConnectionException(
              MachineConnectionFailureKind.timeout,
              '连接机器超时',
            );
          }
          return const MachineProbeResult(sn: 'GS-ONLINE');
        };
      final container = ProviderContainer(
        overrides: [
          activeConnectionProvider.overrideWithValue(
            const RobotConnection(
              id: 'GS-ONLINE',
              name: '在线机器',
              baseUrl: 'http://127.0.0.1:8898',
            ),
          ),
          machineConnectionProbeProvider.overrideWithValue(probe),
          machineAvailabilityConfigProvider.overrideWithValue(
            const MachineAvailabilityConfig(
              onlineInterval: Duration(days: 1),
              reconnectInterval: Duration(days: 1),
              maxOfflineInterval: Duration(days: 1),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(
        machineAvailabilityProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await pumpEventQueue();
      expect(
        container.read(machineAvailabilityProvider).status,
        MachineAvailabilityStatus.reconnecting,
      );

      await container.read(machineAvailabilityProvider.notifier).retry();
      expect(
        container.read(machineAvailabilityProvider).status,
        MachineAvailabilityStatus.offline,
      );

      await container.read(machineAvailabilityProvider.notifier).retry();
      final recovered = container.read(machineAvailabilityProvider);
      expect(recovered.status, MachineAvailabilityStatus.online);
      expect(recovered.lastSeenAt, isNotNull);
    },
  );
}

class _FakeMachineConnectionProbe implements MachineConnectionProbe {
  late Future<MachineProbeResult> Function(RobotConnection connection) handler;

  @override
  Future<MachineProbeResult> probe(RobotConnection connection) =>
      handler(connection);
}

Future<SharedPreferences> _preferences({
  bool includeThirdMachine = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'robot_connections': jsonEncode([
      {'id': 'GS-ONLINE', 'name': '在线机器', 'baseUrl': 'http://127.0.0.1:8898'},
      {'id': 'GS-OFFLINE', 'name': '离线机器', 'baseUrl': 'http://192.0.2.1:8898'},
      if (includeThirdMachine)
        {'id': 'GS-THIRD', 'name': '第三台机器', 'baseUrl': 'http://192.0.2.2:8898'},
    ]),
    'active_connection_id': 'GS-ONLINE',
  });
  return SharedPreferences.getInstance();
}
