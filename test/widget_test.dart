import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sysapp/app/app.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';
import 'package:sysapp/features/connection/presentation/connection_screen.dart';
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
}
