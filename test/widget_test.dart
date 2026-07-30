import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sysapp/app/app.dart';
import 'package:sysapp/core/websocket/ws_connection_manager.dart';
import 'package:sysapp/features/connection/data/machine_connection_probe.dart';
import 'package:sysapp/features/connection/domain/connection_model.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';
import 'package:sysapp/features/connection/presentation/connection_screen.dart';
import 'package:sysapp/features/connection/presentation/machine_availability_provider.dart';
import 'package:sysapp/features/dashboard/presentation/dashboard_provider.dart';
import 'package:sysapp/features/settings/presentation/settings_screen.dart';
import 'package:sysapp/shared/widgets/console_widgets.dart';

void main() {
  testWidgets(
    'App smoke test - shows connection screen when no robot configured',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      // 没有配置机器时应该看到连接管理页
      expect(find.text('机器列表'), findsOneWidget);
    },
  );

  testWidgets('machine management back button returns to settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'robot_connections': jsonEncode([
        {'id': 'robot-1', 'name': '机器 A', 'baseUrl': 'http://127.0.0.1:8080'},
      ]),
      'active_connection_id': 'robot-1',
    });
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/connection',
          builder: (_, _) => const ConnectionScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('机器列表'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '管理'));
    await tester.pumpAndSettle();

    expect(find.text('机器 A'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('所有机器'), findsOneWidget);
  });

  testWidgets('machine card keeps its address compact on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const address = 'http://192.168.100.100:8898';
    SharedPreferences.setMockInitialValues({
      'robot_connections': jsonEncode([
        {'id': 'robot-1', 'name': '巡检机器人一号', 'baseUrl': address},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ConnectionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final addressText = tester.widget<Text>(find.textContaining(address));
    expect(addressText.maxLines, 1);
    expect(addressText.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(find.byType(ConsoleCard)).height,
      lessThanOrEqualTo(120),
    );

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an offline machine keeps the current page and shows a global warning',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'robot_connections': jsonEncode([
          {
            'id': 'GS-OFFLINE',
            'name': '离线机器',
            'baseUrl': 'http://192.0.2.1:8898',
          },
        ]),
        'active_connection_id': 'GS-OFFLINE',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            machineAvailabilityProvider.overrideWith(
              _OfflineAvailabilityNotifier.new,
            ),
            dashboardProvider.overrideWith(_EmptyDashboardNotifier.new),
            wsManagerProvider.overrideWith((ref) {
              final manager = WsConnectionManager();
              ref.onDispose(manager.dispose);
              return manager;
            }),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('控制中心'), findsOneWidget);
      expect(find.text('机器暂时不可用'), findsNothing);
      expect(find.text('立即重试'), findsNothing);
      expect(find.textContaining('机器「离线机器」：机器未开机'), findsOneWidget);
    },
  );

  testWidgets('a failed card switch keeps the previous machine active', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'robot_connections': jsonEncode([
        {'id': 'GS-ONLINE', 'name': '在线机器', 'baseUrl': 'http://127.0.0.1:8898'},
        {
          'id': 'GS-OFFLINE',
          'name': '离线机器',
          'baseUrl': 'http://192.0.2.1:8898',
        },
      ]),
      'active_connection_id': 'GS-ONLINE',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        machineConnectionProbeProvider.overrideWithValue(const _OfflineProbe()),
        machineAvailabilityProvider.overrideWith(
          _OnlineAvailabilityNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConnectionScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '连接'));
    await tester.pumpAndSettle();

    expect(container.read(connectionProvider).activeId, 'GS-ONLINE');
    expect(find.text('机器未开机，或不在当前网络'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重试'), findsOneWidget);
  });
}

class _OfflineAvailabilityNotifier extends MachineAvailabilityNotifier {
  @override
  MachineAvailabilityState build() {
    Future.microtask(
      () => state = const MachineAvailabilityState(
        connectionId: 'GS-OFFLINE',
        status: MachineAvailabilityStatus.offline,
        message: '机器未开机，或不在当前网络',
        consecutiveFailures: 2,
      ),
    );
    return const MachineAvailabilityState(
      connectionId: 'GS-OFFLINE',
      status: MachineAvailabilityStatus.checking,
      message: '正在连接机器…',
    );
  }
}

class _OnlineAvailabilityNotifier extends MachineAvailabilityNotifier {
  @override
  MachineAvailabilityState build() => const MachineAvailabilityState(
    connectionId: 'GS-ONLINE',
    status: MachineAvailabilityStatus.online,
    message: '机器在线',
  );
}

class _EmptyDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardState> build() async => const DashboardState();
}

class _OfflineProbe implements MachineConnectionProbe {
  const _OfflineProbe();

  @override
  Future<MachineProbeResult> probe(RobotConnection connection) async {
    throw const MachineConnectionException(
      MachineConnectionFailureKind.unreachable,
      '机器未开机，或不在当前网络',
    );
  }
}
