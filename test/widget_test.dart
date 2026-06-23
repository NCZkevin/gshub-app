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
}
