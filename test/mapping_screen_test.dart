import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sysapp/core/websocket/ws_connection_manager.dart';
import 'package:sysapp/features/connection/presentation/connection_provider.dart';
import 'package:sysapp/features/mapping/presentation/mapping_provider.dart';
import 'package:sysapp/features/mapping/presentation/mapping_screen.dart';
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

class _ListMappingNotifier extends MappingNotifier {
  @override
  Future<MappingState> build() async {
    return MappingState(
      containerState: const {'running': true, 'status': 'running'},
      maps: [
        for (var i = 0; i < 6; i++)
          MapInfo(
            name: 'map_$i',
            size: 1024 * (i + 1),
            modifiedTime: 1000.0 + i,
          ),
      ],
    );
  }
}

class _DetailMappingNotifier extends MappingNotifier {
  @override
  Future<MappingState> build() async {
    return MappingState(
      viewState: MappingViewState.detail,
      selectedMap: 'demo_map',
      mapFiles: const [
        FileInfo(name: 'demo_map.pgm', path: 'demo_map.pgm', size: 4096),
        FileInfo(name: 'demo_map.yaml', path: 'demo_map.yaml', size: 256),
      ],
      mapPgmBytes: _tinyPgm(),
      mapResolution: 0.05,
    );
  }
}

class _ActiveMappingNotifier extends MappingNotifier {
  @override
  Future<MappingState> build() async {
    return const MappingState(
      viewState: MappingViewState.active,
      mapName: 'active_map',
      mappingStatus: MappingStatus(
        status: 'mapping',
        perceptionAvailable: true,
        mapAvailable: true,
        pointsCollected: 1024,
        sceneName: 'active_map',
      ),
    );
  }
}

class _DeleteMappingNotifier extends MappingNotifier {
  @override
  Future<MappingState> build() async {
    return const MappingState(
      maps: [MapInfo(name: 'delete_me', size: 2048, modifiedTime: 1000.0)],
    );
  }

  @override
  Future<void> deleteMap(String name) async {
    final current = state.value ?? const MappingState();
    state = AsyncValue.data(
      current.copyWith(
        maps: current.maps.where((map) => map.name != name).toList(),
      ),
    );
  }
}

void main() {
  testWidgets('mapping list shows resume banner and saved maps', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mappingProvider.overrideWith(_ListMappingNotifier.new)],
        child: const MaterialApp(home: MappingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('检测到建图任务正在运行'), findsOneWidget);
    expect(find.text('map_0'), findsOneWidget);
    expect(find.text('map_4'), findsOneWidget);
    expect(find.text('map_5'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mapping detail shows file list and resolution', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mappingProvider.overrideWith(_DetailMappingNotifier.new)],
        child: const MaterialApp(home: MappingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('demo_map'), findsOneWidget);
    expect(find.text('demo_map.pgm'), findsOneWidget);
    expect(find.text('demo_map.yaml'), findsOneWidget);
    expect(find.text('0.050 m/px'), findsOneWidget);
    expect(find.byTooltip('编辑 PGM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mapping active view shows workbench cards', (tester) async {
    final manager = WsConnectionManager();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mappingProvider.overrideWith(_ActiveMappingNotifier.new),
          wsManagerProvider.overrideWithValue(manager),
          activeConnectionProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: MappingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MAP: active_map'), findsOneWidget);
    expect(find.text('遥控器'), findsOneWidget);
    expect(find.text('视频流'), findsOneWidget);
    expect(find.text('点云视图'), findsOneWidget);
    expect(tester.takeException(), isNull);
    manager.dispose();
  });

  testWidgets('mapping detail opens pgm editor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mappingProvider.overrideWith(_DetailMappingNotifier.new)],
        child: const MaterialApp(home: MappingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑 PGM'));
    await tester.pumpAndSettle();

    expect(find.text('PGM 编辑'), findsOneWidget);
    expect(find.text('空闲'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system back returns mapping detail to list without popping route',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mappingProvider.overrideWith(_DetailMappingNotifier.new)],
          child: const MaterialApp(home: MappingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('demo_map.pgm'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('开始建图'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delete dialog closes itself without popping go_router page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const MappingScreen())],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mappingProvider.overrideWith(_DeleteMappingNotifier.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('delete_me'), findsOneWidget);

    await tester.tap(find.byTooltip('删除地图'));
    await tester.pumpAndSettle();
    expect(find.text('确认删除地图「delete_me」？此操作不可撤销。'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('delete_me'), findsNothing);
    expect(find.text('开始建图'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
