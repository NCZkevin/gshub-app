import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_models.freezed.dart';
part 'app_models.g.dart';

// ─── 设备信息 ───────────────────────────────────────────────

@freezed
class DeviceInfo with _$DeviceInfo {
  const factory DeviceInfo({
    @JsonKey(name: 'SN') String? sn,
    String? model,
    String? version,
    @JsonKey(name: 'node_role') String? nodeRole,
  }) = _DeviceInfo;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);
}

// GET /systems/hub
@freezed
class HubInfo with _$HubInfo {
  const factory HubInfo({
    @Default('') String hostname,
    @JsonKey(name: 'cpu_usage') @Default(0.0) double cpuUsage,
    @JsonKey(name: 'mem_used_mb') @Default(0) int memUsedMb,
    @JsonKey(name: 'mem_total_mb') @Default(0) int memTotalMb,
  }) = _HubInfo;

  factory HubInfo.fromJson(Map<String, dynamic> json) =>
      _$HubInfoFromJson(json);
}

// GET /systems/robot — battery can be int, List<int>, or null
@freezed
class RobotInfo with _$RobotInfo {
  const factory RobotInfo({
    @JsonKey(name: 'robot_type') @Default('unknown') String robotType,
    @Default(false) bool connected,
    // Stored as parsed int (first battery if multi-battery, or null)
    int? battery,
  }) = _RobotInfo;

  factory RobotInfo.fromJson(Map<String, dynamic> json) {
    int? battery;
    final raw = json['battery'];
    if (raw is int) {
      battery = raw;
    } else if (raw is List && raw.isNotEmpty) {
      battery = raw.first as int?;
    }
    return RobotInfo(
      robotType: json['robot_type'] as String? ?? 'unknown',
      connected: json['connected'] as bool? ?? false,
      battery: battery,
    );
  }

  factory RobotInfo.fromJsonFreezed(Map<String, dynamic> json) =>
      RobotInfo.fromJson(json);
}

// ─── 服务状态 ────────────────────────────────────────────────

@freezed
class ContainerInfo with _$ContainerInfo {
  const factory ContainerInfo({
    required String name,
    @JsonKey(name: 'service_class') String? serviceClass,
    String? role,
    @Default('UNKNOWN') String state,
    String? health,
    @Default(false) bool critical,
    @JsonKey(name: 'allow_manual_stop') @Default(true) bool allowManualStop,
    @JsonKey(name: 'mutex_group') String? mutexGroup,
  }) = _ContainerInfo;

  factory ContainerInfo.fromJson(Map<String, dynamic> json) =>
      _$ContainerInfoFromJson(json);
}

// ─── 导航 ────────────────────────────────────────────────────

enum NavigationStatus { vacant, navigating, arrived, failed, paused, stopped }

// GET /nav/navigation_status → {status: "navigating", relocalization: "active"}
class NavStatus {
  final NavigationStatus status;
  final String relocalizationRaw;

  const NavStatus({required this.status, this.relocalizationRaw = ''});

  factory NavStatus.fromJson(Map<String, dynamic> json) {
    final s = json['status'] as String? ?? '';
    NavigationStatus status;
    switch (s) {
      case 'navigating':
        status = NavigationStatus.navigating;
        break;
      case 'arrived':
      case 'succeeded':
        status = NavigationStatus.arrived;
        break;
      case 'failed':
      case 'error':
        status = NavigationStatus.failed;
        break;
      case 'paused':
        status = NavigationStatus.paused;
        break;
      case 'stopped':
      case 'idle':
        status = NavigationStatus.stopped;
        break;
      default:
        status = NavigationStatus.vacant;
    }
    return NavStatus(
      status: status,
      relocalizationRaw: json['relocalization'] as String? ?? '',
    );
  }
}

@freezed
class Waypoint with _$Waypoint {
  const factory Waypoint({
    required double x,
    required double y,
    @Default(0.0) double theta,
  }) = _Waypoint;

  factory Waypoint.fromJson(Map<String, dynamic> json) =>
      _$WaypointFromJson(json);
}

// ─── 地图 ────────────────────────────────────────────────────

// GET /maps → {total, maps: [MapInfo]}
// created_time / modified_time are Unix timestamps (float)
@freezed
class MapInfo with _$MapInfo {
  const factory MapInfo({
    required String name,
    String? path,
    @Default(0) int size,
    @JsonKey(name: 'file_count') @Default(0) int fileCount,
    @JsonKey(name: 'resolution') @Default(0.05) double resolution,
    // stored as epoch seconds
    @JsonKey(name: 'created_time') double? createdTime,
    @JsonKey(name: 'modified_time') double? modifiedTime,
  }) = _MapInfo;

  factory MapInfo.fromJson(Map<String, dynamic> json) =>
      _$MapInfoFromJson(json);
}

@freezed
class FileInfo with _$FileInfo {
  const factory FileInfo({
    required String name,
    required String path,
    @JsonKey(name: 'full_path') String? fullPath,
    @Default(0) int size,
    @JsonKey(name: 'mime_type') String? mimeType,
  }) = _FileInfo;

  factory FileInfo.fromJson(Map<String, dynamic> json) =>
      _$FileInfoFromJson(json);
}

// ─── 建图 ────────────────────────────────────────────────────

@freezed
class MappingStatus with _$MappingStatus {
  const factory MappingStatus({
    @Default('unknown') String status,
    @JsonKey(name: 'perceptions_available')
    @Default(false)
    bool perceptionAvailable,
    @JsonKey(name: 'map_available') @Default(false) bool mapAvailable,
    @JsonKey(name: 'points_collected') @Default(0) int pointsCollected,
    @JsonKey(name: 'scene_name') String? sceneName,
    @JsonKey(name: 'output_folder') String? outputFolder,
  }) = _MappingStatus;

  factory MappingStatus.fromJson(Map<String, dynamic> json) =>
      _$MappingStatusFromJson(json);
}

// ─── 日志 ────────────────────────────────────────────────────

// GET /logs/list → {items: [{name, size, mod_time}]}
@freezed
class LogFileInfo with _$LogFileInfo {
  const factory LogFileInfo({
    required String name,
    @Default(0) int size,
    @JsonKey(name: 'mod_time') DateTime? modifiedTime,
  }) = _LogFileInfo;

  factory LogFileInfo.fromJson(Map<String, dynamic> json) =>
      _$LogFileInfoFromJson(json);
}
