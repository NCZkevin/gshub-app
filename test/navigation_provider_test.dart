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

void main() {
  late _MockNavigationRepository repository;
  late WsConnectionManager wsManager;

  setUp(() {
    repository = _MockNavigationRepository();
    wsManager = WsConnectionManager();

    when(
      () => repository.fetchMaps(),
    ).thenAnswer((_) async => const [MapInfo(name: 'demo_map')]);
    when(
      () => repository.getSavedNavParams(any()),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(
      () => repository.getNavParams(any()),
    ).thenAnswer((_) async => <String, dynamic>{});
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
      verify(
        () => repository.startNavContainer('demo_map', relocalization: false),
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

      expect(state.viewState, NavViewState.active);
      expect(state.selectedMap, 'demo_map');
      expect(state.navStatus, NavigationStatus.vacant);
      expect(state.navReady, isFalse);
      expect(state.error, isNull);
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
}
