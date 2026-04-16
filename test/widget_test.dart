import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sysapp/app/app.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';

void main() {
  testWidgets('App smoke test - shows connection screen when no robot configured',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    // 没有配置展位时应该看到连接管理页
    expect(find.text('机器人展位管理'), findsOneWidget);
  });
}
