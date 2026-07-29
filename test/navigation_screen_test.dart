import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sysapp/app/adaptive_shell.dart';
import 'package:sysapp/core/utils/map_coords.dart';
import 'package:sysapp/core/websocket/ws_connection_manager.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';
import 'package:sysapp/features/navigation/presentation/navigation_provider.dart';
import 'package:sysapp/features/navigation/presentation/navigation_screen.dart';
import 'package:sysapp/shared/domain/app_models.dart';

Uint8List _tinyPgm() => Uint8List.fromList([
  80,
  53,
  10,
  50,
  32,
  50,
  10,
  50,
  53,
  53,
  10,
  0,
  205,
  254,
  254,
]);

class _FakeNavigationNotifier extends NavigationNotifier {
  static int startMissionCount = 0;
  static int stopTaskCount = 0;
  static int closeNavigationCount = 0;
  static int submitRelocalizationCount = 0;
  static int startSavedRouteCount = 0;
  static bool navReady = true;
  static NavigationStatus navStatus = NavigationStatus.vacant;
  static MissionInfo? activeMission;

  static void reset() {
    startMissionCount = 0;
    stopTaskCount = 0;
    closeNavigationCount = 0;
    submitRelocalizationCount = 0;
    startSavedRouteCount = 0;
    navReady = true;
    navStatus = NavigationStatus.vacant;
    activeMission = null;
  }

  @override
  Future<NavigationState> build() async {
    return NavigationState(
      viewState: NavViewState.active,
      navReady: navReady,
      navStatus: navStatus,
      activeMission: activeMission,
      selectedMap: 'demo_map',
      savedRoutes: const [
        NavLandmark(
          id: 1,
          name: '巡检线',
          sceneName: 'demo_map',
          kind: 'route',
          points: [Waypoint(x: 1, y: 1), Waypoint(x: 2, y: 2)],
        ),
      ],
      pgmBytes: _tinyPgm(),
      mapMeta: const MapMeta(
        resolution: 0.05,
        originX: 0,
        originY: 0,
        width: 2,
        height: 2,
      ),
    );
  }

  @override
  Future<void> startSingleMission({
    required SingleMissionMode mode,
    required Waypoint goal,
  }) async {
    startMissionCount++;
    final current = state.value ?? const NavigationState();
    state = AsyncValue.data(
      current.copyWith(
        activeMission: MissionInfo(
          id: 'mission-1',
          status: 'running',
          mode: mode.name,
        ),
        navStatus: NavigationStatus.navigating,
      ),
    );
  }

  @override
  Future<void> stopTask() async {
    stopTaskCount++;
    final current = state.value ?? const NavigationState();
    state = AsyncValue.data(
      current.copyWith(
        activeMission: null,
        navStatus: NavigationStatus.stopped,
      ),
    );
  }

  @override
  Future<void> closeNavigation() async {
    closeNavigationCount++;
    final current = state.value ?? const NavigationState();
    state = AsyncValue.data(current.copyWith(viewState: NavViewState.setup));
  }

  @override
  Future<void> submitRelocalizationPose(Waypoint pose) async {
    submitRelocalizationCount++;
  }

  @override
  Future<void> startSavedRoute(NavLandmark route, int cycles) async {
    startSavedRouteCount++;
  }
}

class _SetupNavigationNotifier extends NavigationNotifier {
  static int applyParamsCount = 0;

  static void reset() {
    applyParamsCount = 0;
  }

  @override
  Future<NavigationState> build() async {
    return const NavigationState(
      viewState: NavViewState.setup,
      maps: [MapInfo(name: 'demo_map')],
      selectedMap: 'demo_map',
    );
  }

  @override
  void updateNavParam(NavParamField field, double value) {
    final current = state.value ?? const NavigationState();
    state = AsyncValue.data(
      current.copyWith(
        navParams: current.navParams.withField(field, value),
        navParamsDirty: true,
      ),
    );
  }

  @override
  Future<void> applyNavParams() async {
    applyParamsCount++;
    final current = state.value ?? const NavigationState();
    state = AsyncValue.data(
      current.copyWith(navParamsDirty: false, navParamsMessage: '参数已应用'),
    );
  }
}

Future<WsConnectionManager> _pumpNavigation(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final manager = WsConnectionManager();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        navigationProvider.overrideWith(_FakeNavigationNotifier.new),
        wsManagerProvider.overrideWithValue(manager),
        activeConnectionProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(home: NavigationScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return manager;
}

void main() {
  setUp(() {
    _FakeNavigationNotifier.reset();
    _SetupNavigationNotifier.reset();
  });

  testWidgets('portrait uses immersive map and draggable task sheet', (
    tester,
  ) async {
    final manager = await _pumpNavigation(tester);

    expect(find.byKey(const Key('navigation-map')), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byKey(const Key('navigation-side-panel')), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('landscape uses map and fixed task side panel', (tester) async {
    final manager = await _pumpNavigation(tester, size: const Size(1024, 600));

    expect(find.byKey(const Key('navigation-map')), findsOneWidget);
    expect(find.byKey(const Key('navigation-side-panel')), findsOneWidget);
    expect(find.byKey(const Key('navigation-task-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('warming navigation disables mission editing and shows status', (
    tester,
  ) async {
    _FakeNavigationNotifier.navReady = false;
    final manager = await _pumpNavigation(tester);

    expect(find.text('导航服务启动中'), findsNWidgets(2));
    final pickGoal = tester.widget<OutlinedButton>(
      find.byKey(const Key('pick-single-goal')),
    );
    expect(pickGoal.onPressed, isNull);
    manager.dispose();
  });

  testWidgets(
    'ready runtime is not presented as a stopped navigation service',
    (tester) async {
      _FakeNavigationNotifier.navStatus = NavigationStatus.stopped;
      final manager = await _pumpNavigation(tester);

      expect(find.text('导航运行中'), findsOneWidget);
      expect(find.text('空闲'), findsOneWidget);
      expect(find.text('已停止'), findsNothing);
      manager.dispose();
    },
  );

  testWidgets('stopped mission remains visible as a task result', (
    tester,
  ) async {
    _FakeNavigationNotifier.navStatus = NavigationStatus.stopped;
    _FakeNavigationNotifier.activeMission = const MissionInfo(
      id: 'mission-1',
      status: 'stopped',
      mode: 'standard',
    );
    final manager = await _pumpNavigation(tester);

    expect(find.text('导航运行中'), findsOneWidget);
    expect(find.text('standard · 已停止'), findsOneWidget);
    manager.dispose();
  });

  testWidgets('stopping mission is localized as an in-progress task', (
    tester,
  ) async {
    _FakeNavigationNotifier.navStatus = NavigationStatus.navigating;
    _FakeNavigationNotifier.activeMission = const MissionInfo(
      id: 'mission-1',
      status: 'stopping',
      mode: 'standard',
    );
    final manager = await _pumpNavigation(tester);

    expect(find.text('导航中'), findsOneWidget);
    expect(find.text('standard · 停止中'), findsOneWidget);
    manager.dispose();
  });

  testWidgets(
    'app shell hides all global navigation only in active workspace',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final manager = WsConnectionManager();
      final router = GoRouter(
        initialLocation: '/navigation',
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                AdaptiveShell(state: state, child: child),
            routes: [
              GoRoute(
                path: '/navigation',
                builder: (_, _) => const NavigationScreen(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            navigationProvider.overrideWith(_FakeNavigationNotifier.new),
            wsManagerProvider.overrideWithValue(manager),
            activeConnectionProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byKey(const Key('navigation-map')), findsOneWidget);
      manager.dispose();
    },
  );

  testWidgets('app shell remains visible on navigation setup page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: '/navigation',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AdaptiveShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/navigation',
              builder: (_, _) => const NavigationScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationProvider.overrideWith(_SetupNavigationNotifier.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('导航配置'), findsOneWidget);
  });

  testWidgets('map browsing does not edit until explicit goal mode', (
    tester,
  ) async {
    final manager = await _pumpNavigation(tester);

    await tester.tap(find.byKey(const Key('navigation-map')));
    await tester.pumpAndSettle();
    expect(find.textContaining('目标  x'), findsNothing);

    await tester.tap(find.byKey(const Key('pick-single-goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navigation-map')));
    await tester.pumpAndSettle();

    expect(find.textContaining('目标  x'), findsOneWidget);
    expect(_FakeNavigationNotifier.startMissionCount, 0);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('target selection remains draft until explicit mission start', (
    tester,
  ) async {
    final manager = await _pumpNavigation(tester);

    await tester.tap(find.byKey(const Key('pick-single-goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navigation-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-single-navigation')));
    await tester.pumpAndSettle();

    expect(_FakeNavigationNotifier.startMissionCount, 1);
    expect(find.text('任务执行中'), findsOneWidget);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('persistent stop and close actions control active navigation', (
    tester,
  ) async {
    final manager = await _pumpNavigation(tester);

    await tester.tap(find.byKey(const Key('stop-navigation-task')));
    await tester.pumpAndSettle();
    expect(_FakeNavigationNotifier.stopTaskCount, 1);

    await tester.tap(find.byKey(const Key('close-navigation')));
    await tester.pumpAndSettle();
    expect(find.text('关闭导航'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '关闭'));
    await tester.pumpAndSettle();

    expect(_FakeNavigationNotifier.closeNavigationCount, 1);
    expect(find.text('导航配置'), findsOneWidget);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('relocalization uses explicit map mode and submit action', (
    tester,
  ) async {
    final manager = await _pumpNavigation(tester);

    await tester.tap(find.byKey(const Key('nav-mode-relocalize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-relocalization-pose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navigation-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-relocalization')));
    await tester.pumpAndSettle();

    expect(_FakeNavigationNotifier.submitRelocalizationCount, 1);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('saved route can execute and load into independent path draft', (
    tester,
  ) async {
    final manager = await _pumpNavigation(tester, size: const Size(1024, 600));

    final savedMode = find.byKey(const Key('nav-mode-savedRoute'));
    await tester.ensureVisible(savedMode);
    await tester.pumpAndSettle();
    await tester.tap(savedMode);
    await tester.pumpAndSettle();
    expect(find.text('巡检线'), findsOneWidget);

    await tester.tap(find.text('巡检线'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '加载到路径编辑'));
    await tester.pumpAndSettle();
    expect(find.text('P1 1.0,1.0'), findsOneWidget);

    await tester.tap(savedMode);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '执行'));
    await tester.pumpAndSettle();
    expect(_FakeNavigationNotifier.startSavedRouteCount, 1);

    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('auxiliary menu opens teleoperation sheet', (tester) async {
    final manager = await _pumpNavigation(tester);

    await tester.tap(find.byKey(const Key('navigation-tools')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('遥控器'));
    await tester.pumpAndSettle();

    expect(find.text('急停'), findsOneWidget);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('advanced setup params are collapsed, editable and applicable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationProvider.overrideWith(_SetupNavigationNotifier.new),
        ],
        child: const MaterialApp(home: NavigationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('高级导航参数'), findsOneWidget);
    expect(find.text('雷达高度'), findsNothing);

    await tester.tap(find.text('高级导航参数'));
    await tester.pumpAndSettle();
    expect(find.text('雷达高度'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '0.60'), '0.70');
    await tester.pumpAndSettle();
    expect(find.textContaining('参数有未应用修改'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, '应用参数'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '应用参数'));
    await tester.pumpAndSettle();

    expect(_SetupNavigationNotifier.applyParamsCount, 1);
    expect(find.text('参数已应用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
