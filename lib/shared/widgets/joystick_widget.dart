import 'dart:math' show sqrt;
import 'package:flutter/material.dart';

/// 虚拟摇杆 Widget
/// 回调 [onMove]：归一化 x, y 值，范围 [-1.0, 1.0]
/// 回调 [onRelease]：摇杆松开，应发送停止指令
class JoystickWidget extends StatefulWidget {
  final void Function(double x, double y) onMove;
  final VoidCallback? onRelease;
  final double size;
  final Color stickColor;
  final Color baseColor;

  const JoystickWidget({
    super.key,
    required this.onMove,
    this.onRelease,
    this.size = 150,
    this.stickColor = Colors.cyan,
    this.baseColor = Colors.white12,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _stick = Offset.zero;
  bool _active = false;

  void _update(Offset localPos) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final radius = widget.size / 2 * 0.6; // 允许移动范围半径
    var delta = localPos - center;
    final dist = sqrt(delta.dx * delta.dx + delta.dy * delta.dy);
    if (dist > radius) {
      delta = delta / dist * radius;
    }
    setState(() => _stick = delta);
    widget.onMove(delta.dx / radius, delta.dy / radius);
  }

  void _release() {
    setState(() {
      _stick = Offset.zero;
      _active = false;
    });
    widget.onRelease?.call();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanStart: (d) {
          _active = true;
          _update(d.localPosition);
        },
        onPanUpdate: (d) {
          if (_active) _update(d.localPosition);
        },
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: CustomPaint(
          painter: _JoystickPainter(
            stick: _stick,
            baseColor: widget.baseColor,
            stickColor: widget.stickColor,
            radius: r,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset stick;
  final Color baseColor;
  final Color stickColor;
  final double radius;

  const _JoystickPainter({
    required this.stick,
    required this.baseColor,
    required this.stickColor,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 底座圆
    canvas.drawCircle(center, radius,
        Paint()..color = baseColor);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // 摇杆圆
    canvas.drawCircle(
        center + stick,
        radius * 0.35,
        Paint()..color = stickColor.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.stick != stick;
}
