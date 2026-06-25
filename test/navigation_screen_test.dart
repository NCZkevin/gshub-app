import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sysapp/core/utils/map_coords.dart';
import 'package:sysapp/core/websocket/ws_connection_manager.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';
import 'package:sysapp/features/navigation/presentation/navigation_provider.dart';
import 'package:sysapp/features/navigation/presentation/navigation_screen.dart';
import 'package:sysapp/shared/domain/app_models.dart';
import 'package:sysapp/shared/widgets/occupancy_map.dart';

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
  static int loadSavedRouteCount = 0;

  static void reset() {
    startMissionCount = 0;
    stopTaskCount = 0;
    closeNavigationCount = 0;
    submitRelocalizationCount = 0;
    startSavedRouteCount = 0;
    loadSavedRouteCount = 0;
  }

  @override
  Future<NavigationState> build() async {
    return NavigationState(
      viewState: NavViewState.active,
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
  void setGoalPoint(double wx, double wy, {double? theta}) {
    final current = state.value ?? const NavigationState();
    state = AsyncValue.data(
      current.copyWith(goalPoint: (wx, wy, theta ?? 0.0)),
    );
  }

  @override
  Future<void> startSingleMission() async {
    startMissionCount++;
    final current = state.value ?? const NavigationState();
    state = AsyncValue.data(
      current.copyWith(
        activeMission: const MissionInfo(
          id: 'mission-1',
          status: 'running',
          mode: 'standard',
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
  Future<void> submitRelocalizationPose() async {
    submitRelocalizationCount++;
  }

  @override
  void loadSavedRoute(NavLandmark route) {
    loadSavedRouteCount++;
    final current = state.value ?? const NavigationState();
    state = AsyncValue.data(current.copyWith(waypoints: route.points));
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

void main() {
  setUp(() {
    _FakeNavigationNotifier.reset();
    _SetupNavigationNotifier.reset();
  });

  testWidgets('map tap selects target without starting mission', (
    tester,
  ) async {
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

    await tester.tap(find.byType(OccupancyMap));
    await tester.pumpAndSettle();

    expect(find.textContaining('目标: x='), findsOneWidget);
    expect(_FakeNavigationNotifier.startMissionCount, 0);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('start navigation sends mission after target selection', (
    tester,
  ) async {
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

    await tester.tap(find.byType(OccupancyMap));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '开始导航'));
    await tester.pumpAndSettle();

    expect(_FakeNavigationNotifier.startMissionCount, 1);
    expect(find.text('任务执行中'), findsOneWidget);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('stop and close controls stay on navigation route', (
    tester,
  ) async {
    final manager = WsConnectionManager();
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const NavigationScreen())],
    );

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

    await tester.tap(find.widgetWithText(FilledButton, '停止任务'));
    await tester.pumpAndSettle();
    expect(_FakeNavigationNotifier.stopTaskCount, 1);
    expect(find.text('导航'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '关闭导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '关闭'));
    await tester.pumpAndSettle();

    expect(_FakeNavigationNotifier.closeNavigationCount, 1);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('relocalization tab selects and submits pose', (tester) async {
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

    await tester.tap(find.text('重定位'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OccupancyMap));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '提交初始位姿'));
    await tester.pumpAndSettle();

    expect(_FakeNavigationNotifier.submitRelocalizationCount, 1);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('saved route tab starts and loads route', (tester) async {
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

    await tester.tap(find.text('路线'));
    await tester.pumpAndSettle();

    expect(find.text('巡检线'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '执行'));
    await tester.pumpAndSettle();
    expect(_FakeNavigationNotifier.startSavedRouteCount, 1);

    await tester.tap(find.byTooltip('加载到路径'));
    await tester.pumpAndSettle();
    expect(_FakeNavigationNotifier.loadSavedRouteCount, 1);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('setup params show dirty warning and apply action', (
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

    expect(find.text('导航参数'), findsOneWidget);

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
