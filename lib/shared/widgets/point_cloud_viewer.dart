import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../app/theme.dart';

class PointCloudViewer extends StatefulWidget {
  final String? wsUrl;
  final String pointCloudTopic;
  final bool accumulate;

  const PointCloudViewer({
    super.key,
    required this.wsUrl,
    this.pointCloudTopic = '/tower/mapping/cloud_colored',
    this.accumulate = true,
  });

  @override
  State<PointCloudViewer> createState() => _PointCloudViewerState();
}

class _PointCloudViewerState extends State<PointCloudViewer> {
  static const _rebuildEvery = 5;
  static const _maxVoxels = 80000;
  static const _minVoxelSize = 0.02;
  static const _maxVoxelSize = 0.5;
  static const _voxelStep = 0.01;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  _FieldLayout? _layout;
  int _connectGeneration = 0;
  int _frameCounter = 0;
  double _voxelSize = 0.05;
  String _status = '未连接';

  final Map<String, _CloudPoint> _voxels = {};
  List<_CloudPoint> _points = const [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant PointCloudViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wsUrl != widget.wsUrl ||
        oldWidget.pointCloudTopic != widget.pointCloudTopic) {
      _clearPoints();
      _connect();
    }
  }

  @override
  void dispose() {
    _disconnect(sendUnsubscribe: true);
    super.dispose();
  }

  void _connect() {
    _disconnect(sendUnsubscribe: false);
    final url = widget.wsUrl;
    if (url == null || url.isEmpty) {
      setState(() => _status = '未配置连接');
      return;
    }

    final generation = ++_connectGeneration;
    setState(() => _status = '连接中...');
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    _subscription = channel.stream.listen(
      (data) => _handleMessage(data),
      onDone: () => _scheduleReconnect(generation),
      onError: (_) => _scheduleReconnect(generation),
      cancelOnError: true,
    );

    channel.ready
        .then((_) {
          if (!mounted || generation != _connectGeneration) return;
          setState(() => _status = '已连接');
          _sendSubscribe();
        })
        .catchError((_) {
          _scheduleReconnect(generation);
          return null;
        });
  }

  void _scheduleReconnect(int generation) {
    if (!mounted || generation != _connectGeneration) return;
    setState(() => _status = '重连中...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && generation == _connectGeneration) _connect();
    });
  }

  void _disconnect({required bool sendUnsubscribe}) {
    _connectGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (sendUnsubscribe) _sendUnsubscribe();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _layout = null;
  }

  void _sendSubscribe() {
    _channel?.sink.add(
      jsonEncode({
        'op': 'subscribe',
        'topic': widget.pointCloudTopic,
        'type': 'sensor_msgs/PointCloud2',
        'output_format': 'json',
        'queue_length': 1,
      }),
    );
  }

  void _sendUnsubscribe() {
    try {
      _channel?.sink.add(
        jsonEncode({'op': 'unsubscribe', 'topic': widget.pointCloudTopic}),
      );
    } catch (_) {}
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;
    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      if (decoded['topic'] != widget.pointCloudTopic) return;
      final cloud = decoded['msg'];
      if (cloud is! Map<String, dynamic>) return;
      _parseCloud(cloud);
    } catch (_) {
      // Ignore malformed frames. The next PointCloud2 frame can recover.
    }
  }

  void _parseCloud(Map<String, dynamic> cloud) {
    final raw = _decodeCloudData(cloud['data']);
    if (raw == null || raw.isEmpty) return;

    _layout ??= _FieldLayout.fromCloud(cloud);
    final layout = _layout;
    if (layout == null || layout.step <= 0) return;

    final width = (cloud['width'] as num?)?.toInt() ?? 0;
    final height = (cloud['height'] as num?)?.toInt() ?? 1;
    final declaredTotal = width * height;
    final availableTotal = raw.length ~/ layout.step;
    final total = declaredTotal > 0
        ? math.min(declaredTotal, availableTotal)
        : availableTotal;
    final endian = cloud['is_bigendian'] == true ? Endian.big : Endian.little;
    final view = ByteData.sublistView(raw);

    if (!widget.accumulate) _voxels.clear();

    for (var i = 0; i < total; i++) {
      final off = i * layout.step;
      if (off + layout.minRequiredBytes > raw.length) break;
      final x = view.getFloat32(off + layout.xOffset, endian);
      final y = view.getFloat32(off + layout.yOffset, endian);
      final z = view.getFloat32(off + layout.zOffset, endian);
      if (!x.isFinite || !y.isFinite || !z.isFinite) continue;

      final color =
          layout.rgbOffset == null || off + layout.rgbOffset! + 4 > raw.length
          ? const Color(0xFF22D3EE)
          : _decodePackedColor(view.getUint32(off + layout.rgbOffset!, endian));
      final key =
          '${(x / _voxelSize).round()},${(y / _voxelSize).round()},${(z / _voxelSize).round()}';
      _voxels[key] = _CloudPoint(x: x, y: y, z: z, color: color);
    }

    _trimVoxelMap();
    _frameCounter++;
    if (!widget.accumulate || _frameCounter % _rebuildEvery == 0) {
      _publishPoints();
    }
  }

  Uint8List? _decodeCloudData(dynamic data) {
    if (data is String) return base64Decode(data);
    if (data is List) {
      return Uint8List.fromList(data.map((e) => (e as num).toInt()).toList());
    }
    return null;
  }

  Color _decodePackedColor(int packed) {
    final r = (packed >> 16) & 0xff;
    final g = (packed >> 8) & 0xff;
    final b = packed & 0xff;
    return Color.fromARGB(255, r, g, b);
  }

  void _trimVoxelMap() {
    final overflow = _voxels.length - _maxVoxels;
    if (overflow <= 0) return;
    final keys = _voxels.keys.take(overflow).toList();
    for (final key in keys) {
      _voxels.remove(key);
    }
  }

  void _publishPoints() {
    if (!mounted) return;
    setState(() {
      _points = List<_CloudPoint>.unmodifiable(_voxels.values);
      _status = '接收中';
    });
  }

  void _clearPoints() {
    setState(() {
      _voxels.clear();
      _points = const [];
      _frameCounter = 0;
      _layout = null;
    });
  }

  void _changeVoxelSize(double delta) {
    final next = (_voxelSize + delta).clamp(_minVoxelSize, _maxVoxelSize);
    setState(() => _voxelSize = (next * 100).round() / 100);
    _clearPoints();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _PointCloudPainter(
            points: _points,
            gridColor: AppTheme.borderColor(context).withValues(alpha: 0.35),
          ),
        ),
        Positioned(
          left: 8,
          top: 8,
          child: _VoxelControl(
            voxelSize: _voxelSize,
            onDecrease: _voxelSize <= _minVoxelSize
                ? null
                : () => _changeVoxelSize(-_voxelStep),
            onIncrease: _voxelSize >= _maxVoxelSize
                ? null
                : () => _changeVoxelSize(_voxelStep),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: _PointCloudStats(
            status: _status,
            count: _points.length,
            onClear: _points.isEmpty ? null : _clearPoints,
          ),
        ),
      ],
    );
  }
}

class _FieldLayout {
  final int xOffset;
  final int yOffset;
  final int zOffset;
  final int? rgbOffset;
  final int step;

  const _FieldLayout({
    required this.xOffset,
    required this.yOffset,
    required this.zOffset,
    required this.rgbOffset,
    required this.step,
  });

  int get minRequiredBytes {
    final maxOffset = [
      xOffset,
      yOffset,
      zOffset,
      rgbOffset ?? 0,
    ].reduce(math.max);
    return maxOffset + 4;
  }

  factory _FieldLayout.fromCloud(Map<String, dynamic> cloud) {
    final fields = cloud['fields'] as List<dynamic>? ?? const [];
    int? find(String name) {
      for (final item in fields) {
        if (item is Map<String, dynamic> && item['name'] == name) {
          return (item['offset'] as num?)?.toInt();
        }
      }
      return null;
    }

    return _FieldLayout(
      xOffset: find('x') ?? 0,
      yOffset: find('y') ?? 4,
      zOffset: find('z') ?? 8,
      rgbOffset: find('rgb') ?? find('rgba'),
      step: (cloud['point_step'] as num?)?.toInt() ?? 16,
    );
  }
}

class _CloudPoint {
  final double x;
  final double y;
  final double z;
  final Color color;

  const _CloudPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.color,
  });
}

class _PointCloudPainter extends CustomPainter {
  final List<_CloudPoint> points;
  final Color gridColor;

  const _PointCloudPainter({required this.points, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF020617),
    );
    _drawGrid(canvas, size);
    if (points.isEmpty) {
      _drawEmpty(canvas, size);
      return;
    }

    var minX = points.first.x;
    var maxX = points.first.x;
    var minY = points.first.y;
    var maxY = points.first.y;
    for (final p in points) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    final rangeX = math.max(maxX - minX, 1.0);
    final rangeY = math.max(maxY - minY, 1.0);
    const padding = 18.0;
    final scale = math.min(
      (size.width - padding * 2) / rangeX,
      (size.height - padding * 2) / rangeY,
    );
    final drawnWidth = rangeX * scale;
    final drawnHeight = rangeY * scale;
    final originX = (size.width - drawnWidth) / 2;
    final originY = (size.height - drawnHeight) / 2;

    final grouped = <int, List<Offset>>{};
    for (final p in points) {
      final sx = originX + (p.x - minX) * scale;
      final sy = originY + drawnHeight - (p.y - minY) * scale;
      grouped.putIfAbsent(p.color.toARGB32(), () => []).add(Offset(sx, sy));
    }

    for (final entry in grouped.entries) {
      final paint = Paint()
        ..color = Color(entry.key)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = points.length > 30000 ? 1.2 : 2.0;
      canvas.drawPoints(PointMode.points, entry.value, paint);
    }

    final robotPaint = Paint()..color = AppTheme.warning;
    final center = Offset(
      originX + (0 - minX) * scale,
      originY + drawnHeight - (0 - minY) * scale,
    );
    if ((Offset.zero & size).inflate(20).contains(center)) {
      canvas.drawCircle(center, 5, robotPaint);
      canvas.drawCircle(
        center,
        10,
        robotPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawEmpty(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: '等待点云数据',
        style: TextStyle(
          color: AppTheme.slate400,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    painter.paint(
      canvas,
      Offset(
        (size.width - painter.width) / 2,
        (size.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_PointCloudPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.gridColor != gridColor;
  }
}

class _VoxelControl extends StatelessWidget {
  final double voxelSize;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _VoxelControl({
    required this.voxelSize,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return _OverlayPanel(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '体素',
            style: TextStyle(
              color: AppTheme.slate400,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 15,
            tooltip: '减小体素',
            onPressed: onDecrease,
            icon: const Icon(Icons.remove),
          ),
          Text(
            '${voxelSize.toStringAsFixed(2)}m',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 15,
            tooltip: '增大体素',
            onPressed: onIncrease,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _PointCloudStats extends StatelessWidget {
  final String status;
  final int count;
  final VoidCallback? onClear;

  const _PointCloudStats({
    required this.status,
    required this.count,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _OverlayPanel(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$status · $count pts',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 15,
            tooltip: '清空点云',
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _OverlayPanel extends StatelessWidget {
  final Widget child;

  const _OverlayPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(8),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white70),
          child: child,
        ),
      ),
    );
  }
}
