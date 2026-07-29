import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/core/utils/map_coords.dart';
import 'package:sysapp/shared/widgets/occupancy_map.dart';

Uint8List _rectangularPgm() => Uint8List.fromList([
  80,
  53,
  10,
  52,
  32,
  50,
  10,
  50,
  53,
  53,
  10,
  0,
  64,
  128,
  255,
  255,
  128,
  64,
  0,
]);

void main() {
  test('viewport preserves ratio and inverts fit, zoom and pan transforms', () {
    final controller = MapViewportController();
    addTearDown(controller.dispose);

    controller.configure(
      viewportSize: const Size(400, 300),
      contentSize: const Size(200, 100),
    );

    expect(controller.fitScale, 2);
    var pixel = controller.toMapPixel(const Offset(200, 150));
    expect(pixel.dx, closeTo(100, 0.0001));
    expect(pixel.dy, closeTo(50, 0.0001));
    expect(
      controller.containsMapPixel(controller.toMapPixel(const Offset(200, 20))),
      isFalse,
    );

    controller.zoomBy(2);
    expect(controller.scale, closeTo(4, 0.0001));
    pixel = controller.toMapPixel(const Offset(200, 150));
    expect(pixel.dx, closeTo(100, 0.0001));
    expect(pixel.dy, closeTo(50, 0.0001));

    controller.centerOnPixel(const Offset(25, 30), preferredScale: 5);
    pixel = controller.toMapPixel(const Offset(200, 150));
    expect(pixel.dx, closeTo(25, 0.0001));
    expect(pixel.dy, closeTo(30, 0.0001));
  });

  test('pixel/world conversion is an inverse on a non-square map', () {
    const meta = MapMeta(
      resolution: 0.05,
      originX: -12.5,
      originY: -4,
      width: 640,
      height: 320,
    );
    const worldX = 3.275;
    const worldY = 6.125;

    final pixel = worldToPixel(worldX, worldY, meta);
    final restored = pixelToWorld(pixel.dx, pixel.dy, meta);

    expect(restored.$1, closeTo(worldX, 0.000001));
    expect(restored.$2, closeTo(worldY, 0.000001));
  });

  testWidgets(
    'map rejects letterbox taps and selects through zoomed transform',
    (tester) async {
      final controller = MapViewportController();
      addTearDown(controller.dispose);
      final selections = <MapSelection>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 400,
                child: OccupancyMap(
                  pgmBytes: _rectangularPgm(),
                  meta: const MapMeta(
                    resolution: 0.5,
                    originX: -1,
                    originY: -2,
                    width: 4,
                    height: 2,
                  ),
                  interactionMode: MapInteractionMode.pickGoal,
                  viewportController: controller,
                  onSelection: selections.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byType(OccupancyMap));
      expect(controller.configured, isTrue);
      final centerPixel = controller.toMapPixel(rect.center - rect.topLeft);
      expect(centerPixel.dx, closeTo(2, 0.001));
      expect(centerPixel.dy, closeTo(1, 0.001));
      await tester.tapAt(Offset(rect.center.dx, rect.top + 20));
      await tester.pump();
      expect(selections, isEmpty);

      await tester.tapAt(rect.center);
      await tester.pump();
      expect(selections, hasLength(1));
      expect(selections.single.x, closeTo(0, 0.001));
      expect(selections.single.y, closeTo(-1.5, 0.001));

      controller.centerOnPixel(const Offset(1, 0.5), preferredScale: 200);
      await tester.pump();
      await tester.tapAt(rect.center);
      await tester.pump();

      expect(selections, hasLength(2));
      expect(selections.last.x, closeTo(-0.5, 0.001));
      expect(selections.last.y, closeTo(-1.25, 0.001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long press drag records an explicit heading', (tester) async {
    final selections = <MapSelection>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.square(
            dimension: 300,
            child: OccupancyMap(
              pgmBytes: _rectangularPgm(),
              meta: const MapMeta(
                resolution: 1,
                originX: 0,
                originY: 0,
                width: 4,
                height: 2,
              ),
              interactionMode: MapInteractionMode.pickGoal,
              onSelection: selections.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(OccupancyMap));
    final gesture = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(45, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(selections, hasLength(1));
    expect(selections.single.headingExplicit, isTrue);
    expect(selections.single.theta.abs(), lessThan(0.05));
    expect(tester.takeException(), isNull);
  });
}
