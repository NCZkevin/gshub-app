// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RobotConnectionImpl _$$RobotConnectionImplFromJson(
  Map<String, dynamic> json,
) => _$RobotConnectionImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  baseUrl: json['baseUrl'] as String,
  networkKind:
      $enumDecodeNullable(
        _$ConnectionNetworkKindEnumMap,
        json['networkKind'],
      ) ??
      ConnectionNetworkKind.lan,
  apSsid: json['apSsid'] as String?,
);

Map<String, dynamic> _$$RobotConnectionImplToJson(
  _$RobotConnectionImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'baseUrl': instance.baseUrl,
  'networkKind': _$ConnectionNetworkKindEnumMap[instance.networkKind]!,
  'apSsid': instance.apSsid,
};

const _$ConnectionNetworkKindEnumMap = {
  ConnectionNetworkKind.lan: 'lan',
  ConnectionNetworkKind.ap: 'ap',
};
