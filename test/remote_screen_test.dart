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

class _RunningDashboardNotifier extends DashboardNotifier {
  @override
  Future<DashboardState> build() async {
    return const DashboardState(
      robotInfo: RobotInfo(robotType: 'go2', connected: true, battery: 72),
      servicesStatus: {
        'motion': {'status': 'running'},
      },
    );
  }
}

class _RecordingWsManager extends WsConnectionManager {
  final commands = <({double linearX, double linearY, double angularZ})>[];

  @override
  void sendCmdVel(
    double linearX,
    double angularZ, {
    double linearY = 0,
    bool force = false,
  }) {
    commands.add((linearX: linearX, linearY: linearY, angularZ: angularZ));
  }

  @override
  void sendStop() {
    sendCmdVel(0, 0, force: true);
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

  testWidgets('left joystick drag sends positive lateral velocity', (
    tester,
  ) async {
    final ws = _RecordingWsManager();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeConnectionProvider.overrideWithValue(null),
          wsManagerProvider.overrideWithValue(ws),
          dashboardProvider.overrideWith(_RunningDashboardNotifier.new),
        ],
        child: const MaterialApp(home: RemoteScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('解锁控制'));
    await tester.pump();
    expect(find.text('遥控已解锁，松手会自动停止'), findsOneWidget);

    final joystick = find.byKey(const ValueKey('remote_translation_joystick'));
    await tester.dragFrom(tester.getCenter(joystick), const Offset(-54, 0));
    await tester.pump();

    expect(
      ws.commands.any((cmd) => cmd.linearY > 0),
      isTrue,
      reason: ws.commands.toString(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('right joystick drag sends negative lateral velocity', (
    tester,
  ) async {
    final ws = _RecordingWsManager();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeConnectionProvider.overrideWithValue(null),
          wsManagerProvider.overrideWithValue(ws),
          dashboardProvider.overrideWith(_RunningDashboardNotifier.new),
        ],
        child: const MaterialApp(home: RemoteScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('解锁控制'));
    await tester.pump();
    expect(find.text('遥控已解锁，松手会自动停止'), findsOneWidget);

    final joystick = find.byKey(const ValueKey('remote_translation_joystick'));
    await tester.dragFrom(tester.getCenter(joystick), const Offset(54, 0));
    await tester.pump();

    expect(
      ws.commands.any((cmd) => cmd.linearY < 0),
      isTrue,
      reason: ws.commands.toString(),
    );
    expect(tester.takeException(), isNull);
  });
}
