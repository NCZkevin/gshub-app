// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DeviceInfoImpl _$$DeviceInfoImplFromJson(Map<String, dynamic> json) =>
    _$DeviceInfoImpl(
      sn: json['SN'] as String?,
      model: json['model'] as String?,
      version: json['version'] as String?,
      nodeRole: json['node_role'] as String?,
    );

Map<String, dynamic> _$$DeviceInfoImplToJson(_$DeviceInfoImpl instance) =>
    <String, dynamic>{
      'SN': instance.sn,
      'model': instance.model,
      'version': instance.version,
      'node_role': instance.nodeRole,
    };

_$HubInfoImpl _$$HubInfoImplFromJson(Map<String, dynamic> json) =>
    _$HubInfoImpl(
      hostname: json['hostname'] as String? ?? '',
      cpuUsage: (json['cpu_usage'] as num?)?.toDouble() ?? 0.0,
      memUsedMb: (json['mem_used_mb'] as num?)?.toInt() ?? 0,
      memTotalMb: (json['mem_total_mb'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$HubInfoImplToJson(_$HubInfoImpl instance) =>
    <String, dynamic>{
      'hostname': instance.hostname,
      'cpu_usage': instance.cpuUsage,
      'mem_used_mb': instance.memUsedMb,
      'mem_total_mb': instance.memTotalMb,
    };

_$ContainerInfoImpl _$$ContainerInfoImplFromJson(Map<String, dynamic> json) =>
    _$ContainerInfoImpl(
      name: json['name'] as String,
      serviceClass: json['service_class'] as String?,
      role: json['role'] as String?,
      state: json['state'] as String? ?? 'UNKNOWN',
      health: json['health'] as String?,
      critical: json['critical'] as bool? ?? false,
      allowManualStop: json['allow_manual_stop'] as bool? ?? true,
      mutexGroup: json['mutex_group'] as String?,
    );

Map<String, dynamic> _$$ContainerInfoImplToJson(_$ContainerInfoImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'service_class': instance.serviceClass,
      'role': instance.role,
      'state': instance.state,
      'health': instance.health,
      'critical': instance.critical,
      'allow_manual_stop': instance.allowManualStop,
      'mutex_group': instance.mutexGroup,
    };

_$WaypointImpl _$$WaypointImplFromJson(Map<String, dynamic> json) =>
    _$WaypointImpl(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      theta: (json['theta'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$WaypointImplToJson(_$WaypointImpl instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'theta': instance.theta,
    };

_$MapInfoImpl _$$MapInfoImplFromJson(Map<String, dynamic> json) =>
    _$MapInfoImpl(
      name: json['name'] as String,
      path: json['path'] as String?,
      size: (json['size'] as num?)?.toInt() ?? 0,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      resolution: (json['resolution'] as num?)?.toDouble() ?? 0.05,
      createdTime: (json['created_time'] as num?)?.toDouble(),
      modifiedTime: (json['modified_time'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$MapInfoImplToJson(_$MapInfoImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'size': instance.size,
      'file_count': instance.fileCount,
      'resolution': instance.resolution,
      'created_time': instance.createdTime,
      'modified_time': instance.modifiedTime,
    };

_$FileInfoImpl _$$FileInfoImplFromJson(Map<String, dynamic> json) =>
    _$FileInfoImpl(
      name: json['name'] as String,
      path: json['path'] as String,
      fullPath: json['full_path'] as String?,
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String?,
    );

Map<String, dynamic> _$$FileInfoImplToJson(_$FileInfoImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'full_path': instance.fullPath,
      'size': instance.size,
      'mime_type': instance.mimeType,
    };

_$MappingStatusImpl _$$MappingStatusImplFromJson(Map<String, dynamic> json) =>
    _$MappingStatusImpl(
      status: json['status'] as String? ?? 'unknown',
      perceptionAvailable: json['perception_available'] as bool? ?? false,
      mapAvailable: json['map_available'] as bool? ?? false,
      pointsCollected: (json['points_collected'] as num?)?.toInt() ?? 0,
      sceneName: json['scene_name'] as String?,
      outputFolder: json['output_folder'] as String?,
    );

Map<String, dynamic> _$$MappingStatusImplToJson(_$MappingStatusImpl instance) =>
    <String, dynamic>{
      'status': instance.status,
      'perception_available': instance.perceptionAvailable,
      'map_available': instance.mapAvailable,
      'points_collected': instance.pointsCollected,
      'scene_name': instance.sceneName,
      'output_folder': instance.outputFolder,
    };

_$LogFileInfoImpl _$$LogFileInfoImplFromJson(Map<String, dynamic> json) =>
    _$LogFileInfoImpl(
      name: json['name'] as String,
      size: (json['size'] as num?)?.toInt() ?? 0,
      modifiedTime: json['mod_time'] == null
          ? null
          : DateTime.parse(json['mod_time'] as String),
    );

Map<String, dynamic> _$$LogFileInfoImplToJson(_$LogFileInfoImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'size': instance.size,
      'mod_time': instance.modifiedTime?.toIso8601String(),
    };
