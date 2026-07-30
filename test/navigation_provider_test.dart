import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sysapp/core/websocket/ws_connection_manager.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';
import 'package:sysapp/features/navigation/data/navigation_repository.dart';
import 'package:sysapp/features/navigation/presentation/navigation_provider.dart';
import 'package:sysapp/shared/domain/app_models.dart';

class _MockNavigationRepository extends Mock implements NavigationRepository {}

class _RecordingWsManager extends WsConnectionManager {
  int odometryReconnectCount = 0;

  @override
  void reconnectOdometry() {
    odometryReconnectCount++;
  }
}

void main() {
  late _MockNavigationRepository repository;
  late _RecordingWsManager wsManager;

  setUp(() {
    repository = _MockNavigationRepository();
    wsManager = _RecordingWsManager();

    when(
      () => repository.fetchMaps(),
    ).thenAnswer((_) async => const [MapInfo(name: 'demo_map')]);
    when(
      () => repository.getSavedNavParams(any()),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(
      () => repository.getNavParams(any()),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(
      () => repository.fetchCurrentNavigationTaskId(),
    ).thenAnswer((_) async => null);
    when(() => repository.fetchMapPgm(any())).thenAnswer((_) async => null);
    when(
      () => repository.fetchLandmarks(any()),
    ).thenAnswer((_) async => const <Map<String, dynamic>>[]);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWith((ref) async => repository),
        wsManagerProvider.overrideWithValue(wsManager),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(wsManager.dispose);
    return container;
  }

  test('setup relocalization defaults to enabled', () async {
    when(
      () => repository.checkContainerStatus(),
    ).thenAnswer((_) async => {'running': false, 'status': 'not_found'});

    final container = createContainer();
    final subscription = container.listen(
      navigationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final state = await container.read(navigationProvider.future);

    expect(state.useRelocalizationOnStart, isTrue);
  });

  test(
    'setup relocalization changes locally without a running container',
    () async {
      when(
        () => repository.checkContainerStatus(),
      ).thenAnswer((_) async => {'running': false, 'status': 'not_found'});
      when(
        () => repository.toggleRelocalization(any()),
      ).thenThrow(Exception('navigation is not running'));
      when(
        () => repository.startNavContainer(
          any(),
          relocalization: any(named: 'relocalization'),
        ),
      ).thenAnswer((_) async {});

      final container = createContainer();
      final subscription = container.listen(
        navigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final initial = await container.read(navigationProvider.future);

      container
          .read(navigationProvider.notifier)
          .setUseRelocalizationOnStart(false);

      final updated = container.read(navigationProvider).requireValue;
      expect(
        updated.useRelocalizationOnStart,
        isNot(initial.useRelocalizationOnStart),
      );
      expect(updated.error, isNull);

      await container.read(navigationProvider.notifier).startNavContainer();

      verifyNever(() => repository.toggleRelocalization(any()));
      verify(
        () => repository.startNavContainer('demo_map', relocalization: false),
      ).called(1);
    },
  );

  test(
    'start success enters active view without requiring immediate nav status',
    () async {
      when(
        () => repository.checkContainerStatus(),
      ).thenAnswer((_) async => {'running': false, 'status': 'not_found'});
      when(
        () => repository.startNavContainer(
          any(),
          relocalization: any(named: 'relocalization'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repository.fetchNavStatus(),
      ).thenAnswer((_) => Future.error(Exception('HTTP 502')));

      final container = createContainer();
      final subscription = container.listen(
        navigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(navigationProvider.future);

      await container.read(navigationProvider.notifier).startNavContainer();

      final state = container.read(navigationProvider).requireValue;
      expect(state.viewState, NavViewState.active);
      expect(state.navReady, isFalse);
      expect(state.loading, isFalse);
      expect(state.error, isNull);
      expect(wsManager.odometryReconnectCount, 1);
      verify(
        () => repository.startNavContainer('demo_map', relocalization: true),
      ).called(1);
      verifyNever(repository.fetchNavStatus);

      await Future<void>.delayed(const Duration(milliseconds: 2100));

      final polledState = container.read(navigationProvider).requireValue;
      expect(polledState.viewState, NavViewState.active);
      expect(polledState.navReady, isFalse);
      expect(polledState.loading, isFalse);
      expect(polledState.error, isNull);
      verify(repository.fetchNavStatus).called(1);
    },
  );

  test(
    'running container remains active while nav status API is warming up',
    () async {
      when(
        () => repository.checkContainerStatus(),
      ).thenAnswer((_) async => {'running': true, 'status': 'running'});
      when(
        () => repository.fetchNavStatus(),
      ).thenAnswer((_) => Future.error(Exception('HTTP 502')));

      final container = createContainer();
      final subscription = container.listen(
        navigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final state = await container.read(navigationProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(state.viewState, NavViewState.active);
      expect(state.selectedMap, isNull);
      expect(state.navStatus, NavigationStatus.vacant);
      expect(state.navReady, isFalse);
      expect(state.error, isNull);
      expect(wsManager.odometryReconnectCount, 1);
      verify(repository.fetchNavStatus).called(1);
    },
  );

  test(
    'warm-up polling restores the runtime map before enabling missions',
    () async {
      when(() => repository.fetchMaps()).thenAnswer(
        (_) async => const [MapInfo(name: 'map_a'), MapInfo(name: 'map_b')],
      );
      when(
        () => repository.checkContainerStatus(),
      ).thenAnswer((_) async => {'running': true, 'status': 'running'});

      var statusCalls = 0;
      when(() => repository.fetchNavStatus()).thenAnswer((_) {
        statusCalls++;
        if (statusCalls == 1) {
          return Future.error(Exception('HTTP 502'));
        }
        return Future.value(const NavStatus(status: NavigationStatus.vacant));
      });

      var mapCalls = 0;
      when(() => repository.getNavParams(any())).thenAnswer((_) {
        mapCalls++;
        if (mapCalls == 1) {
          return Future.error(Exception('HTTP 502'));
        }
        return Future.value({
          'current_map': {'success': true, 'value': 'map_b'},
        });
      });

      final container = createContainer();
      final subscription = container.listen(
        navigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final warmingState = await container.read(navigationProvider.future);
      expect(warmingState.viewState, NavViewState.active);
      expect(warmingState.selectedMap, isNull);
      expect(warmingState.navReady, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 2100));

      final readyState = container.read(navigationProvider).requireValue;
      expect(readyState.viewState, NavViewState.active);
      expect(readyState.selectedMap, 'map_b');
      expect(readyState.navReady, isTrue);
      verify(() => repository.fetchMapPgm('map_b')).called(1);
    },
  );

  test(
    'leaving the screen during start does not create a polling timer',
    () async {
      when(
        () => repository.checkContainerStatus(),
      ).thenAnswer((_) async => {'running': false, 'status': 'not_found'});
      final startCompleter = Completer<void>();
      when(
        () => repository.startNavContainer(
          any(),
          relocalization: any(named: 'relocalization'),
        ),
      ).thenAnswer((_) => startCompleter.future);

      final localWsManager = WsConnectionManager();
      final container = ProviderContainer(
        overrides: [
          navigationRepositoryProvider.overrideWith((ref) async => repository),
          wsManagerProvider.overrideWithValue(localWsManager),
        ],
      );
      final subscription = container.listen(
        navigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await container.read(navigationProvider.future);

      final startFuture = container
          .read(navigationProvider.notifier)
          .startNavContainer();
      await Future<void>.delayed(Duration.zero);

      subscription.close();
      container.dispose();
      localWsManager.dispose();
      startCompleter.complete();

      await startFuture;
      verifyNever(() => repository.fetchLandmarks(any()));
    },
  );

  test('leaving during initial load does not create a polling timer', () async {
    final mapsCompleter = Completer<List<MapInfo>>();
    when(
      () => repository.checkContainerStatus(),
    ).thenAnswer((_) async => {'running': true, 'status': 'running'});
    when(() => repository.fetchMaps()).thenAnswer((_) => mapsCompleter.future);
    when(
      () => repository.fetchNavStatus(),
    ).thenAnswer((_) async => const NavStatus(status: NavigationStatus.vacant));

    final localWsManager = WsConnectionManager();
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWith((ref) async => repository),
        wsManagerProvider.overrideWithValue(localWsManager),
      ],
    );
    final subscription = container.listen(
      navigationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final buildFuture = container.read(navigationProvider.future);
    await untilCalled(() => repository.fetchMaps());

    subscription.close();
    container.dispose();
    localWsManager.dispose();
    mapsCompleter.complete(const [MapInfo(name: 'demo_map')]);

    await buildFuture;
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    verify(repository.fetchNavStatus).called(1);
  });

  test(
    'runtime polling cannot overwrite an active mission with stopped',
    () async {
      when(
        () => repository.checkContainerStatus(),
      ).thenAnswer((_) async => {'running': true, 'status': 'running'});

      var statusCalls = 0;
      when(() => repository.fetchNavStatus()).thenAnswer((_) async {
        statusCalls++;
        if (statusCalls == 1) {
          return const NavStatus(status: NavigationStatus.vacant);
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return const NavStatus(status: NavigationStatus.stopped);
      });
      when(() => repository.createMission(any())).thenAnswer(
        (_) async => {
          'mission_id': 'mission-1',
          'status': 'running',
          'mode': 'standard',
        },
      );
      when(() => repository.fetchMission('mission-1')).thenAnswer(
        (_) async => {
          'mission_id': 'mission-1',
          'status': 'running',
          'mode': 'standard',
        },
      );

      final container = createContainer();
      final subscription = container.listen(
        navigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(navigationProvider.future);

      await container
          .read(navigationProvider.notifier)
          .startSingleMission(
            mode: SingleMissionMode.standard,
            goal: const Waypoint(x: 1, y: 2),
          );
      expect(
        container.read(navigationProvider).requireValue.navStatus,
        NavigationStatus.navigating,
      );

      await Future<void>.delayed(const Duration(milliseconds: 2300));

      final state = container.read(navigationProvider).requireValue;
      expect(state.activeMission?.status, 'running');
      expect(state.navStatus, NavigationStatus.navigating);
    },
  );

  test('running container restores the current navigation mission', () async {
    when(
      () => repository.checkContainerStatus(),
    ).thenAnswer((_) async => {'running': true, 'status': 'running'});
    when(
      () => repository.fetchNavStatus(),
    ).thenAnswer((_) async => const NavStatus(status: NavigationStatus.vacant));
    when(
      () => repository.fetchCurrentNavigationTaskId(),
    ).thenAnswer((_) async => 'task-current-1');
    when(() => repository.fetchMission('task-current-1')).thenAnswer(
      (_) async => {
        'mission_id': 'task-current-1',
        'status': 'running',
        'mode': 'route',
      },
    );

    final container = createContainer();
    final subscription = container.listen(
      navigationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final state = await container.read(navigationProvider.future);

    expect(state.activeMission?.id, 'task-current-1');
    expect(state.activeMission?.status, 'running');
    expect(state.navStatus, NavigationStatus.navigating);
    verify(repository.fetchCurrentNavigationTaskId).called(1);
    verify(() => repository.fetchMission('task-current-1')).called(1);
  });

  test('saved route uses the mission API and keeps its mission id', () async {
    when(
      () => repository.checkContainerStatus(),
    ).thenAnswer((_) async => {'running': true, 'status': 'running'});
    when(
      () => repository.fetchNavStatus(),
    ).thenAnswer((_) async => const NavStatus(status: NavigationStatus.vacant));
    when(() => repository.getNavParams(any())).thenAnswer(
      (_) async => {
        'current_map': {'success': true, 'value': 'demo_map'},
      },
    );
    when(() => repository.createMission(any())).thenAnswer(
      (_) async => {
        'mission_id': 'route-mission-1',
        'status': 'running',
        'mode': 'route',
      },
    );

    final container = createContainer();
    final subscription = container.listen(
      navigationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(navigationProvider.future);

    const route = NavLandmark(
      id: 7,
      name: '巡检路线',
      sceneName: 'demo_map',
      kind: 'route',
      points: [
        Waypoint(x: 1, y: 2, theta: 0.1),
        Waypoint(x: 3, y: 4, theta: 0.2),
      ],
    );
    await container.read(navigationProvider.notifier).startSavedRoute(route, 3);

    final request =
        verify(() => repository.createMission(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(request['mode'], 'route');
    expect(request['frame_id'], 'map');
    expect(request['cycles'], 3);
    expect(request['waypoints'], [
      {'x': 1.0, 'y': 2.0, 'theta': 0.1},
      {'x': 3.0, 'y': 4.0, 'theta': 0.2},
    ]);
    verifyNever(() => repository.startLandmark(any(), any()));
    expect(
      container.read(navigationProvider).requireValue.activeMission?.id,
      'route-mission-1',
    );
  });

  test(
    'cancel keeps mission in stopping state until polling is terminal',
    () async {
      when(
        () => repository.checkContainerStatus(),
      ).thenAnswer((_) async => {'running': true, 'status': 'running'});
      when(() => repository.fetchNavStatus()).thenAnswer(
        (_) async => const NavStatus(status: NavigationStatus.vacant),
      );
      when(() => repository.getNavParams(any())).thenAnswer(
        (_) async => {
          'current_map': {'success': true, 'value': 'demo_map'},
        },
      );
      when(() => repository.createMission(any())).thenAnswer(
        (_) async => {
          'mission_id': 'mission-stop-1',
          'status': 'running',
          'mode': 'standard',
        },
      );
      when(
        () => repository.cancelMission('mission-stop-1'),
      ).thenAnswer((_) async {});
      when(() => repository.fetchMission('mission-stop-1')).thenAnswer(
        (_) async => {
          'mission_id': 'mission-stop-1',
          'status': 'cancelled',
          'mode': 'standard',
        },
      );

      final container = createContainer();
      final subscription = container.listen(
        navigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(navigationProvider.future);
      await container
          .read(navigationProvider.notifier)
          .startSingleMission(
            mode: SingleMissionMode.standard,
            goal: const Waypoint(x: 1, y: 2),
          );

      await container.read(navigationProvider.notifier).stopTask();

      final stopping = container.read(navigationProvider).requireValue;
      expect(stopping.activeMission?.id, 'mission-stop-1');
      expect(stopping.activeMission?.status, 'stopping');
      expect(stopping.navStatus, NavigationStatus.navigating);

      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final terminal = container.read(navigationProvider).requireValue;
      expect(terminal.activeMission?.status, 'cancelled');
      expect(terminal.navStatus, NavigationStatus.stopped);
    },
  );

  test(
    'runtime navigation status refreshes plan without a local mission',
    () async {
      when(
        () => repository.checkContainerStatus(),
      ).thenAnswer((_) async => {'running': true, 'status': 'running'});
      when(() => repository.fetchNavStatus()).thenAnswer(
        (_) async => const NavStatus(status: NavigationStatus.navigating),
      );
      when(() => repository.getNavParams(any())).thenAnswer(
        (_) async => {
          'current_map': {'success': true, 'value': 'demo_map'},
        },
      );
      when(
        () => repository.fetchPlanPath(),
      ).thenAnswer((_) async => const [(1.0, 2.0), (3.0, 4.0)]);

      final container = createContainer();
      final subscription = container.listen(
        navigationProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(navigationProvider.future);

      await Future<void>.delayed(const Duration(milliseconds: 2100));

      expect(
        container.read(navigationProvider).requireValue.plannedPath,
        const [(1.0, 2.0), (3.0, 4.0)],
      );
      verify(repository.fetchPlanPath).called(1);
    },
  );

  test('running container never guesses the first map', () async {
    when(() => repository.fetchMaps()).thenAnswer(
      (_) async => const [MapInfo(name: 'map_a'), MapInfo(name: 'map_b')],
    );
    when(
      () => repository.checkContainerStatus(),
    ).thenAnswer((_) async => {'running': true, 'status': 'running'});
    when(
      () => repository.fetchNavStatus(),
    ).thenAnswer((_) async => const NavStatus(status: NavigationStatus.vacant));
    when(
      () => repository.getNavParams(any()),
    ).thenAnswer((_) async => <String, dynamic>{});

    final container = createContainer();
    final subscription = container.listen(
      navigationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final state = await container.read(navigationProvider.future);

    expect(state.selectedMap, isNull);
    expect(state.navReady, isFalse);
    verifyNever(() => repository.fetchMapPgm(any()));
  });

  test('navigation params use canonical obstacle height keys', () {
    expect(navParamNames, contains('general:min_obstacle_height'));
    expect(navParamNames, contains('general:max_obstacle_height'));
    expect(
      navParamNames,
      isNot(contains('navigation:free_navigation:min_obstacle_height')),
    );
    expect(
      navParamNames,
      isNot(contains('navigation:free_navigation:max_obstacle_height')),
    );

    final form = NavParamForm.fromSavedParams({
      'general:min_obstacle_height': {'success': true, 'value': 0.25},
      'general:max_obstacle_height': {'success': true, 'value': 1.75},
    });
    expect(form.freeMinObstacleHeight, 0.25);
    expect(form.freeMaxObstacleHeight, 1.75);

    final payload = form.toPayload()!;
    expect(payload['general:min_obstacle_height'], 0.25);
    expect(payload['general:max_obstacle_height'], 1.75);
    expect(
      payload,
      isNot(contains('navigation:free_navigation:min_obstacle_height')),
    );
    expect(
      payload,
      isNot(contains('navigation:free_navigation:max_obstacle_height')),
    );
  });

  test('saving params does not overwrite an unread footprint', () async {
    when(
      () => repository.checkContainerStatus(),
    ).thenAnswer((_) async => {'running': false, 'status': 'not_found'});
    when(
      () => repository.setNavParams(any()),
    ).thenAnswer((_) async => <String, dynamic>{});

    final container = createContainer();
    final subscription = container.listen(
      navigationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(navigationProvider.future);

    container
        .read(navigationProvider.notifier)
        .updateNavParam(NavParamField.lidarHeight, 0.75);
    await container.read(navigationProvider.notifier).applyNavParams();

    final payload =
        verify(() => repository.setNavParams(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(payload, isNot(contains('robot:footprint')));
    expect(
      container.read(navigationProvider).requireValue.navParamsMessage,
      '参数已保存',
    );
  });

  test('saving an edited footprint includes the new footprint', () async {
    when(
      () => repository.checkContainerStatus(),
    ).thenAnswer((_) async => {'running': false, 'status': 'not_found'});
    when(
      () => repository.setNavParams(any()),
    ).thenAnswer((_) async => <String, dynamic>{});

    final container = createContainer();
    final subscription = container.listen(
      navigationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(navigationProvider.future);

    container
        .read(navigationProvider.notifier)
        .updateNavParam(NavParamField.robotLength, 1.0);
    await container.read(navigationProvider.notifier).applyNavParams();

    final payload =
        verify(() => repository.setNavParams(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(payload['robot:footprint'], [
      [0.4, 0.25],
      [0.4, -0.25],
      [-0.6, -0.25],
      [-0.6, 0.25],
    ]);
    final state = container.read(navigationProvider).requireValue;
    expect(state.savedFootprintLoaded, isTrue);
    expect(state.footprintDirty, isFalse);
  });
}
