import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/core/websocket/ws_connection_manager.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';
import 'package:sysapp/features/dashboard/presentation/dashboard_provider.dart';
import 'package:sysapp/features/remote/presentation/remote_screen.dart';
import 'package:sysapp/shared/domain/app_models.dart';

class _FakeDashboardNotifier extends DashboardNotifier {
  static int startMotionCount = 0;

  static void reset() {
    startMotionCount = 0;
  }

  @override
  Future<DashboardState> build() async {
    return const DashboardState(
      robotInfo: RobotInfo(robotType: 'go2', connected: true, battery: 72),
      servicesStatus: {
        'motion': {'status': 'stopped'},
      },
      motionAdapters: ['go2'],
      selectedMotionAdapter: 'go2',
    );
  }

  @override
  Future<void> toggleMotion(bool start, {String adapter = 'go2'}) async {
    if (start) startMotionCount++;
  }
}

void main() {
  setUp(_FakeDashboardNotifier.reset);

  testWidgets('remote screen gates controls when motion is stopped', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeConnectionProvider.overrideWithValue(null),
          wsManagerProvider.overrideWithValue(WsConnectionManager()),
          dashboardProvider.overrideWith(_FakeDashboardNotifier.new),
        ],
        child: const MaterialApp(home: RemoteScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('motion 未运行，无法遥控'), findsOneWidget);
    expect(find.text('启动 motion'), findsOneWidget);

    await tester.tap(find.text('启动 motion'));
    await tester.pump();

    expect(_FakeDashboardNotifier.startMotionCount, 1);
    expect(tester.takeException(), isNull);
  });
}
