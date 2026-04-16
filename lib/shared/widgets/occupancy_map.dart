import 'dart:math' show cos, sin;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/utils/map_coords.dart';
import '../../core/utils/pgm_parser.dart';
import '../../core/websocket/ws_connection_manager.dart';

/// 占用格栅地图组件
/// 渲染 PGM 灰度地图，叠加机器人位置、轨迹、目标点、规���路径、航点
/// 外层套 InteractiveViewer 提供缩放/平移
class OccupancyMap extends StatefulWidget {
  final Uint8List? pgmBytes;
  final MapMeta? meta;
  final RobotOdometry? robotPose;
  final List<RobotOdometry> trajectory;
  final (double x, double y, double theta)? goalPoint;
  final List<(double x, double y)> waypoints;
  final List<(double x, double y)> plannedPath;
  final void Function(double wx, double wy)? onTapWorld;

  const OccupancyMap({
    super.key,
    this.pgmBytes,
    this.meta,
    this.robotPose,
    this.trajectory = const [],
    this.goalPoint,
    this.waypoints = const [],
    this.plannedPath = const [],
    this.onTapWorld,
  });

  @override
  State<OccupancyMap> createState() => _OccupancyMapState();
}

class _OccupancyMapState extends State<OccupancyMap> {
  ui.Image? _mapImage;
  PgmImage? _pgm;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  @override
  void didUpdateWidget(OccupancyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pgmBytes != oldWidget.pgmBytes) _decodeImage();
  }

  void _decodeImage() {
    final bytes = widget.pgmBytes;
    if (bytes == null) return;
    final pgm = parsePgm(bytes);
    _pgm = pgm;

    final rgba = Uint8List(pgm.width * pgm.height * 4);
    for (int i = 0; i < pgm.pixels.length; i++) {
      final v = pgm.pixels[i];
      rgba[i * 4] = v;
      rgba[i * 4 + 1] = v;
      rgba[i * 4 + 2] = v;
      rgba[i * 4 + 3] = 255;
    }
    ui.decodeImageFromPixels(
      rgba,
      pgm.width,
      pgm.height,
      ui.PixelFormat.rgba8888,
      (img) {
        if (mounted) setState(() => _mapImage = img);
      },
    );
  }

  void _handleTap(TapDownDetails details, BoxConstraints constraints) {
    if (widget.onTapWorld == null || widget.meta == null || _pgm == null) return;
    final scaleX = _pgm!.width / constraints.maxWidth;
    final scaleY = _pgm!.height / constraints.maxHeight;
    final px = details.localPosition.dx * scaleX;
    final py = details.localPosition.dy * scaleY;
    final (wx, wy) = pixelToWorld(px, py, widget.meta!);
    widget.onTapWorld!(wx, wy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTapDown: (d) => _handleTap(d, constraints),
        child: CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _MapPainter(
            mapImage: _mapImage,
            pgm: _pgm,
            meta: widget.meta,
            robotPose: widget.robotPose,
            trajectory: widget.trajectory,
            goalPoint: widget.goalPoint,
            waypoints: widget.waypoints,
            plannedPath: widget.plannedPath,
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final ui.Image? mapImage;
  final PgmImage? pgm;
  final MapMeta? meta;
  final RobotOdometry? robotPose;
  final List<RobotOdometry> trajectory;
  final (double, double, double)? goalPoint;
  final List<(double, double)> waypoints;
  final List<(double, double)> plannedPath;

  const _MapPainter({
    this.mapImage,
    this.pgm,
    this.meta,
    this.robotPose,
    this.trajectory = const [],
    this.goalPoint,
    this.waypoints = const [],
    this.plannedPath = const [],
  });

  Offset _worldToCanvas(double wx, double wy, Size size) {
    if (meta == null || pgm == null) return Offset.zero;
    final px = worldToPixel(wx, wy, meta!);
    return Offset(
      px.dx / pgm!.width * size.width,
      px.dy / pgm!.height * size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 地图背景
    if (mapImage != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: mapImage!,
        fit: BoxFit.fill,
      );
    } else {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.grey.shade800);
      return;
    }

    // 2. 规划路径（绿线）
    if (plannedPath.length > 1) {
      final paint = Paint()
        ..color = Colors.green.withValues(alpha: 0.8)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      final f = _worldToCanvas(plannedPath[0].$1, plannedPath[0].$2, size);
      path.moveTo(f.dx, f.dy);
      for (final wp in plannedPath.skip(1)) {
        final p = _worldToCanvas(wp.$1, wp.$2, size);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    // 3. 轨迹线（青色）
    if (trajectory.length > 1) {
      final paint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      final f = _worldToCanvas(trajectory[0].x, trajectory[0].y, size);
      path.moveTo(f.dx, f.dy);
      for (final p in trajectory.skip(1)) {
        final c = _worldToCanvas(p.x, p.y, size);
        path.lineTo(c.dx, c.dy);
      }
      canvas.drawPath(path, paint);
    }

    // 4. 航点（橙圆 + 编号）
    for (int i = 0; i < waypoints.length; i++) {
      final c = _worldToCanvas(waypoints[i].$1, waypoints[i].$2, size);
      canvas.drawCircle(c, 6, Paint()..color = Colors.orange);
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c.translate(-tp.width / 2, -tp.height / 2));
    }

    // 5. 目标点（红 X）
    if (goalPoint != null) {
      final c = _worldToCanvas(goalPoint!.$1, goalPoint!.$2, size);
      final paint = Paint()
        ..color = Colors.red
        ..strokeWidth = 3;
      canvas.drawLine(c.translate(-8, -8), c.translate(8, 8), paint);
      canvas.drawLine(c.translate(-8, 8), c.translate(8, -8), paint);
    }

    // 6. 机器人位置（蓝圆 + 方向线）
    if (robotPose != null && meta != null) {
      final c = _worldToCanvas(robotPose!.x, robotPose!.y, size);
      canvas.drawCircle(c, 8, Paint()..color = Colors.blue);
      final heading = robotPose!.heading;
      final tip = c.translate(12 * cos(heading), -12 * sin(heading));
      canvas.drawLine(c, tip, Paint()
        ..color = Colors.white
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.mapImage != mapImage ||
      old.robotPose != robotPose ||
      old.goalPoint != goalPoint ||
      old.trajectory.length != trajectory.length ||
      old.plannedPath.length != plannedPath.length;
}
