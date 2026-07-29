import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/map_coords.dart';
import '../../core/utils/pgm_parser.dart';
import '../../core/websocket/ws_connection_manager.dart';

enum MapInteractionMode { browse, pickGoal, addWaypoint, pickRelocalization }

class MapSelection {
  final double x;
  final double y;
  final double theta;
  final bool headingExplicit;

  const MapSelection({
    required this.x,
    required this.y,
    this.theta = 0,
    this.headingExplicit = false,
  });

  MapSelection copyWith({
    double? x,
    double? y,
    double? theta,
    bool? headingExplicit,
  }) {
    return MapSelection(
      x: x ?? this.x,
      y: y ?? this.y,
      theta: theta ?? this.theta,
      headingExplicit: headingExplicit ?? this.headingExplicit,
    );
  }
}

/// Owns the map transformation independently from the responsive page layout.
///
/// The child scene uses native PGM pixels. The controller converts viewport
/// coordinates to that scene before map pixels are converted to world space.
class MapViewportController {
  final TransformationController transformationController;

  Size _viewportSize = Size.zero;
  Size _contentSize = Size.zero;
  bool _configured = false;

  MapViewportController({TransformationController? transformationController})
    : transformationController =
          transformationController ?? TransformationController();

  bool get configured => _configured;
  Size get viewportSize => _viewportSize;
  Size get contentSize => _contentSize;

  double get scale {
    if (!_configured) return 1;
    return transformationController.value.getMaxScaleOnAxis();
  }

  double get fitScale {
    if (_viewportSize.isEmpty || _contentSize.isEmpty) return 1;
    return math.min(
      _viewportSize.width / _contentSize.width,
      _viewportSize.height / _contentSize.height,
    );
  }

  void configure({required Size viewportSize, required Size contentSize}) {
    if (viewportSize.isEmpty || contentSize.isEmpty) return;
    if (_configured &&
        viewportSize == _viewportSize &&
        contentSize == _contentSize) {
      return;
    }

    final contentChanged = _configured && contentSize != _contentSize;
    final previousCenter = _configured
        ? transformationController.toScene(_viewportSize.center(Offset.zero))
        : null;
    final previousScale = scale;

    _viewportSize = viewportSize;
    _contentSize = contentSize;

    if (!_configured || contentChanged || previousCenter == null) {
      _configured = true;
      reset();
      return;
    }

    _configured = true;
    final clampedScale = previousScale.clamp(
      fitScale * 0.5,
      math.max(fitScale * 12, fitScale),
    );
    _setView(center: previousCenter, scale: clampedScale.toDouble());
  }

  Offset toMapPixel(Offset viewportPosition) =>
      transformationController.toScene(viewportPosition);

  bool containsMapPixel(Offset pixel) =>
      pixel.dx >= 0 &&
      pixel.dy >= 0 &&
      pixel.dx < _contentSize.width &&
      pixel.dy < _contentSize.height;

  void reset() {
    if (!_configured) return;
    _setView(center: _contentSize.center(Offset.zero), scale: fitScale);
  }

  void centerOnPixel(Offset pixel, {double? preferredScale}) {
    if (!_configured || !containsMapPixel(pixel)) return;
    _setView(
      center: pixel,
      scale: preferredScale ?? math.max(scale, fitScale * 1.6),
    );
  }

  void centerOnWorld(MapMeta meta, double x, double y) {
    centerOnPixel(worldToPixel(x, y, meta));
  }

  void zoomBy(double factor) {
    if (!_configured || factor <= 0) return;
    final center = transformationController.toScene(
      _viewportSize.center(Offset.zero),
    );
    final nextScale = (scale * factor).clamp(
      fitScale * 0.5,
      math.max(fitScale * 12, fitScale),
    );
    _setView(center: center, scale: nextScale.toDouble());
  }

  void _setView({required Offset center, required double scale}) {
    final translation = _viewportSize.center(Offset.zero) - center * scale;
    transformationController.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void dispose() {
    transformationController.dispose();
  }
}

/// Occupancy-grid map with a ratio-preserving, transform-aware viewport.
///
/// Defaults to browse-only behavior so existing read-only callers continue to
/// work. Navigation enables an explicit interaction mode before selections are
/// accepted.
class OccupancyMap extends StatefulWidget {
  final Uint8List? pgmBytes;
  final MapMeta? meta;
  final RobotOdometry? robotPose;
  final List<RobotOdometry> trajectory;
  final MapSelection? goalPoint;
  final List<MapSelection> waypoints;
  final List<(double x, double y)> plannedPath;
  final MapInteractionMode interactionMode;
  final ValueChanged<MapSelection>? onSelection;
  final VoidCallback? onViewportInteraction;
  final MapViewportController? viewportController;

  const OccupancyMap({
    super.key,
    this.pgmBytes,
    this.meta,
    this.robotPose,
    this.trajectory = const [],
    this.goalPoint,
    this.waypoints = const [],
    this.plannedPath = const [],
    this.interactionMode = MapInteractionMode.browse,
    this.onSelection,
    this.onViewportInteraction,
    this.viewportController,
  });

  @override
  State<OccupancyMap> createState() => _OccupancyMapState();
}

class _OccupancyMapState extends State<OccupancyMap> {
  late MapViewportController _ownedController;
  ui.Image? _mapImage;
  PgmImage? _pgm;
  MapSelection? _dragSelection;
  int _decodeGeneration = 0;
  double _viewportScale = 1;
  bool _configurationScheduled = false;

  MapViewportController get _controller =>
      widget.viewportController ?? _ownedController;

  @override
  void initState() {
    super.initState();
    _ownedController = MapViewportController();
    _controller.transformationController.addListener(_onTransformChanged);
    _decodeImage();
  }

  @override
  void didUpdateWidget(covariant OccupancyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewportController != oldWidget.viewportController) {
      (oldWidget.viewportController ?? _ownedController)
          .transformationController
          .removeListener(_onTransformChanged);
      _controller.transformationController.addListener(_onTransformChanged);
    }
    if (!identical(widget.pgmBytes, oldWidget.pgmBytes)) {
      _decodeImage();
    }
    if (widget.interactionMode == MapInteractionMode.browse &&
        oldWidget.interactionMode != MapInteractionMode.browse) {
      _dragSelection = null;
    }
  }

  @override
  void dispose() {
    _controller.transformationController.removeListener(_onTransformChanged);
    _mapImage?.dispose();
    _ownedController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final nextScale = _controller.scale;
    if (!mounted || (nextScale - _viewportScale).abs() < 0.002) return;
    setState(() => _viewportScale = nextScale);
  }

  void _decodeImage() {
    final generation = ++_decodeGeneration;
    final bytes = widget.pgmBytes;
    if (bytes == null) {
      _mapImage?.dispose();
      _mapImage = null;
      _pgm = null;
      return;
    }

    PgmImage pgm;
    try {
      pgm = parsePgm(bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _mapImage?.dispose();
          _mapImage = null;
          _pgm = null;
        });
      }
      return;
    }
    _mapImage?.dispose();
    _mapImage = null;
    _pgm = pgm;

    final rgba = Uint8List(pgm.width * pgm.height * 4);
    for (var i = 0; i < pgm.pixels.length; i++) {
      final value = pgm.pixels[i];
      rgba[i * 4] = value;
      rgba[i * 4 + 1] = value;
      rgba[i * 4 + 2] = value;
      rgba[i * 4 + 3] = 255;
    }

    ui.decodeImageFromPixels(
      rgba,
      pgm.width,
      pgm.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (!mounted || generation != _decodeGeneration) {
          image.dispose();
          return;
        }
        setState(() {
          _mapImage?.dispose();
          _mapImage = image;
          _pgm = pgm;
        });
      },
    );
  }

  void _scheduleConfigure(Size viewport, Size content) {
    if (_configurationScheduled) return;
    if (_controller.configured &&
        _controller.viewportSize == viewport &&
        _controller.contentSize == content) {
      return;
    }
    _configurationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configurationScheduled = false;
      if (!mounted) return;
      _controller.configure(viewportSize: viewport, contentSize: content);
      if (mounted) {
        setState(() => _viewportScale = _controller.scale);
      }
    });
  }

  MapSelection? _selectionAt(Offset viewportPosition) {
    final meta = widget.meta;
    if (meta == null || _pgm == null || !_controller.configured) return null;
    final pixel = _controller.toMapPixel(viewportPosition);
    if (!_controller.containsMapPixel(pixel)) return null;
    final world = pixelToWorld(pixel.dx, pixel.dy, meta);
    return MapSelection(x: world.$1, y: world.$2);
  }

  void _handleTap(TapUpDetails details) {
    if (widget.interactionMode == MapInteractionMode.browse) return;
    final selection = _selectionAt(details.localPosition);
    if (selection == null) return;
    widget.onSelection?.call(selection);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (widget.interactionMode == MapInteractionMode.browse) return;
    final selection = _selectionAt(details.localPosition);
    if (selection == null) return;
    HapticFeedback.selectionClick();
    setState(() => _dragSelection = selection);
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    final start = _dragSelection;
    if (start == null) return;
    final current = _selectionAt(details.localPosition);
    if (current == null) return;
    final theta = math.atan2(current.y - start.y, current.x - start.x);
    setState(
      () =>
          _dragSelection = start.copyWith(theta: theta, headingExplicit: true),
    );
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    final selection = _dragSelection;
    if (selection == null) return;
    setState(() => _dragSelection = null);
    widget.onSelection?.call(selection);
  }

  @override
  Widget build(BuildContext context) {
    final pgm = _pgm;
    final mapImage = _mapImage;
    if (pgm == null) {
      return const ColoredBox(
        color: Color(0xFF020617),
        child: Center(
          child: Text(
            '未加载地图',
            style: TextStyle(
              color: Colors.white54,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final contentSize = Size(pgm.width.toDouble(), pgm.height.toDouble());
    final editing = widget.interactionMode != MapInteractionMode.browse;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        _scheduleConfigure(viewportSize, contentSize);

        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: editing ? _handleTap : null,
            onLongPressStart: editing ? _handleLongPressStart : null,
            onLongPressMoveUpdate: editing ? _handleLongPressMove : null,
            onLongPressEnd: editing ? _handleLongPressEnd : null,
            child: InteractiveViewer(
              transformationController: _controller.transformationController,
              constrained: false,
              panEnabled: !editing,
              scaleEnabled: true,
              minScale: 0.02,
              maxScale: 32,
              boundaryMargin: EdgeInsets.all(
                math.max(contentSize.width, contentSize.height),
              ),
              onInteractionStart: (_) => widget.onViewportInteraction?.call(),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: contentSize,
                  painter: _MapPainter(
                    mapImage: mapImage,
                    meta: widget.meta,
                    robotPose: widget.robotPose,
                    trajectory: widget.trajectory,
                    goalPoint: _dragSelection ?? widget.goalPoint,
                    waypoints: widget.waypoints,
                    plannedPath: widget.plannedPath,
                    viewportScale: math.max(_viewportScale, 0.001),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapPainter extends CustomPainter {
  final ui.Image? mapImage;
  final MapMeta? meta;
  final RobotOdometry? robotPose;
  final List<RobotOdometry> trajectory;
  final MapSelection? goalPoint;
  final List<MapSelection> waypoints;
  final List<(double, double)> plannedPath;
  final double viewportScale;

  const _MapPainter({
    required this.mapImage,
    required this.meta,
    required this.robotPose,
    required this.trajectory,
    required this.goalPoint,
    required this.waypoints,
    required this.plannedPath,
    required this.viewportScale,
  });

  Offset _worldToCanvas(double x, double y) {
    final mapMeta = meta;
    if (mapMeta == null) return Offset.zero;
    return worldToPixel(x, y, mapMeta);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final image = mapImage;
    if (image == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF111827),
      );
    } else {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: image,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      );
    }
    if (meta == null) return;

    final stroke = 2 / viewportScale;
    final markerRadius = 9 / viewportScale;

    if (plannedPath.length > 1) {
      final path = Path();
      final first = _worldToCanvas(plannedPath.first.$1, plannedPath.first.$2);
      path.moveTo(first.dx, first.dy);
      for (final point in plannedPath.skip(1)) {
        final canvasPoint = _worldToCanvas(point.$1, point.$2);
        path.lineTo(canvasPoint.dx, canvasPoint.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF4ADE80).withValues(alpha: 0.85)
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke,
      );
    }

    if (trajectory.length > 1) {
      final path = Path();
      final first = _worldToCanvas(trajectory.first.x, trajectory.first.y);
      path.moveTo(first.dx, first.dy);
      for (final point in trajectory.skip(1)) {
        final canvasPoint = _worldToCanvas(point.x, point.y);
        path.lineTo(canvasPoint.dx, canvasPoint.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF22D3EE).withValues(alpha: 0.7)
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke,
      );
    }

    if (waypoints.length > 1) {
      final path = Path();
      final first = _worldToCanvas(waypoints.first.x, waypoints.first.y);
      path.moveTo(first.dx, first.dy);
      for (final waypoint in waypoints.skip(1)) {
        final point = _worldToCanvas(waypoint.x, waypoint.y);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.65)
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke,
      );
    }

    for (var index = 0; index < waypoints.length; index++) {
      final waypoint = waypoints[index];
      final point = _worldToCanvas(waypoint.x, waypoint.y);
      _drawPoseMarker(
        canvas,
        point,
        waypoint.theta,
        const Color(0xFF8B5CF6),
        markerRadius,
        stroke,
        label: '${index + 1}',
      );
    }

    final goal = goalPoint;
    if (goal != null) {
      _drawPoseMarker(
        canvas,
        _worldToCanvas(goal.x, goal.y),
        goal.theta,
        const Color(0xFFF59E0B),
        markerRadius * 1.15,
        stroke,
      );
    }

    final robot = robotPose;
    if (robot != null) {
      final point = _worldToCanvas(robot.x, robot.y);
      _drawPoseMarker(
        canvas,
        point,
        robot.heading,
        const Color(0xFF06B6D4),
        markerRadius,
        stroke,
      );
    }
  }

  void _drawPoseMarker(
    Canvas canvas,
    Offset point,
    double theta,
    Color color,
    double radius,
    double stroke, {
    String? label,
  }) {
    canvas.drawCircle(
      point,
      radius,
      Paint()..color = color.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );
    final tip = point.translate(
      radius * 1.8 * math.cos(theta),
      -radius * 1.8 * math.sin(theta),
    );
    canvas.drawLine(
      point,
      tip,
      Paint()
        ..color = color
        ..strokeWidth = stroke * 1.4
        ..strokeCap = StrokeCap.round,
    );

    if (label != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10 / viewportScale,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        point.translate(-textPainter.width / 2, -textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.mapImage != mapImage ||
        oldDelegate.meta != meta ||
        oldDelegate.robotPose != robotPose ||
        !listEquals(oldDelegate.trajectory, trajectory) ||
        oldDelegate.goalPoint != goalPoint ||
        !listEquals(oldDelegate.waypoints, waypoints) ||
        !listEquals(oldDelegate.plannedPath, plannedPath) ||
        oldDelegate.viewportScale != viewportScale;
  }
}
