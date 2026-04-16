import 'dart:ui';

/// 地图元数据（来自 YAML 文件）
class MapMeta {
  final double resolution; // 米/像素
  final double originX; // 世界坐标原点 x（米）
  final double originY; // 世界坐标原点 y（米）
  final int width;
  final int height;

  const MapMeta({
    required this.resolution,
    required this.originX,
    required this.originY,
    required this.width,
    required this.height,
  });
}

/// 世界坐标（米）→ 像素坐标
Offset worldToPixel(double wx, double wy, MapMeta meta) {
  final px = (wx - meta.originX) / meta.resolution;
  final py = meta.height - (wy - meta.originY) / meta.resolution;
  return Offset(px, py);
}

/// 像素坐标 → 世界坐标（米）
(double wx, double wy) pixelToWorld(double px, double py, MapMeta meta) {
  final wx = px * meta.resolution + meta.originX;
  final wy = (meta.height - py) * meta.resolution + meta.originY;
  return (wx, wy);
}
