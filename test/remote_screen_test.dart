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
  static int triggerMotionCount = 0;
  static String? lastMotionId;

  static void reset() {
    triggerMotionCount = 0;
    lastMotionId = null;
  }

  @override
  Future<DashboardState> build() async {
    return const DashboardState(
      robotInfo: RobotInfo(robotType: 'go2', connected: true, battery: 72),
      servicesStatus: {
        'motion': {'status': 'running'},
      },
      motionItems: [
        {'id': 'stand_up', 'display_name': '站起', 'description': '机器人恢复站立姿态'},
        {'id': 'sit_down', 'display_name': '蹲下'},
        {'id': 'wave'},
      ],
    );
  }

  @override
  Future<void> triggerMotion(String id) async {
    triggerMotionCount++;
    lastMotionId = id;
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
  setUp(() {
    _FakeDashboardNotifier.reset();
    _RunningDashboardNotifier.reset();
  });

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

  testWidgets('velocity overlay is visible by default and can be hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeConnectionProvider.overrideWithValue(null),
          wsManagerProvider.overrideWithValue(_RecordingWsManager()),
          dashboardProvider.overrideWith(_RunningDashboardNotifier.new),
        ],
        child: const MaterialApp(home: RemoteScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('remote_velocity_overlay')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('remote_settings_panel')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('remote_settings_button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('remote_settings_panel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remote_actions_button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('remote_settings_panel')), findsNothing);
    expect(find.byKey(const ValueKey('remote_actions_panel')), findsOneWidget);
    expect(find.text('wave'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remote_settings_button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('remote_velocity_toggle')));
    await tester.pump();

    expect(find.byKey(const ValueKey('remote_velocity_overlay')), findsNothing);
    expect(find.byKey(const ValueKey('remote_settings_panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('velocity overlay tracks commands and resets on release', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeConnectionProvider.overrideWithValue(null),
          wsManagerProvider.overrideWithValue(_RecordingWsManager()),
          dashboardProvider.overrideWith(_RunningDashboardNotifier.new),
        ],
        child: const MaterialApp(home: RemoteScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('解锁控制'));
    await tester.pump();

    final joystick = find.byKey(const ValueKey('remote_translation_joystick'));
    final gesture = await tester.startGesture(tester.getCenter(joystick));
    await gesture.moveBy(const Offset(-54, 0));
    await tester.pump();

    expect(find.text('Y 0.59 m/s'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.text('Y 0.00 m/s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('motion actions require unlock and confirmation', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('remote_actions_button')));
    await tester.pump();

    expect(find.text('解锁控制后可执行动作'), findsOneWidget);
    final lockedAction = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '站起'),
    );
    expect(lockedAction.onPressed, isNull);

    await tester.tap(find.text('解锁控制'));
    await tester.pump();
    final unlockedAction = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '站起'),
    );
    expect(unlockedAction.onPressed, isNotNull);

    final commandCount = ws.commands.length;
    await tester.tap(find.widgetWithText(OutlinedButton, '站起'));
    await tester.pumpAndSettle();

    expect(find.text('执行“站起”？'), findsOneWidget);
    expect(find.text('机器人恢复站立姿态'), findsOneWidget);
    expect(ws.commands.length, greaterThan(commandCount));
    expect(ws.commands.last.linearX, 0);
    expect(ws.commands.last.linearY, 0);
    expect(ws.commands.last.angularZ, 0);

    await tester.tap(find.text('确认执行'));
    await tester.pumpAndSettle();

    expect(_RunningDashboardNotifier.triggerMotionCount, 1);
    expect(_RunningDashboardNotifier.lastMotionId, 'stand_up');
    expect(find.text('站起 执行成功'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact landscape layout opens settings without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeConnectionProvider.overrideWithValue(null),
          wsManagerProvider.overrideWithValue(_RecordingWsManager()),
          dashboardProvider.overrideWith(_RunningDashboardNotifier.new),
        ],
        child: const MaterialApp(home: RemoteScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('remote_settings_button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('remote_settings_panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
