// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) {
  return _DeviceInfo.fromJson(json);
}

/// @nodoc
mixin _$DeviceInfo {
  @JsonKey(name: 'SN')
  String? get sn => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;
  String? get version => throw _privateConstructorUsedError;
  @JsonKey(name: 'node_role')
  String? get nodeRole => throw _privateConstructorUsedError;

  /// Serializes this DeviceInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceInfoCopyWith<DeviceInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceInfoCopyWith<$Res> {
  factory $DeviceInfoCopyWith(
    DeviceInfo value,
    $Res Function(DeviceInfo) then,
  ) = _$DeviceInfoCopyWithImpl<$Res, DeviceInfo>;
  @useResult
  $Res call({
    @JsonKey(name: 'SN') String? sn,
    String? model,
    String? version,
    @JsonKey(name: 'node_role') String? nodeRole,
  });
}

/// @nodoc
class _$DeviceInfoCopyWithImpl<$Res, $Val extends DeviceInfo>
    implements $DeviceInfoCopyWith<$Res> {
  _$DeviceInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sn = freezed,
    Object? model = freezed,
    Object? version = freezed,
    Object? nodeRole = freezed,
  }) {
    return _then(
      _value.copyWith(
            sn: freezed == sn
                ? _value.sn
                : sn // ignore: cast_nullable_to_non_nullable
                      as String?,
            model: freezed == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String?,
            version: freezed == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as String?,
            nodeRole: freezed == nodeRole
                ? _value.nodeRole
                : nodeRole // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeviceInfoImplCopyWith<$Res>
    implements $DeviceInfoCopyWith<$Res> {
  factory _$$DeviceInfoImplCopyWith(
    _$DeviceInfoImpl value,
    $Res Function(_$DeviceInfoImpl) then,
  ) = __$$DeviceInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'SN') String? sn,
    String? model,
    String? version,
    @JsonKey(name: 'node_role') String? nodeRole,
  });
}

/// @nodoc
class __$$DeviceInfoImplCopyWithImpl<$Res>
    extends _$DeviceInfoCopyWithImpl<$Res, _$DeviceInfoImpl>
    implements _$$DeviceInfoImplCopyWith<$Res> {
  __$$DeviceInfoImplCopyWithImpl(
    _$DeviceInfoImpl _value,
    $Res Function(_$DeviceInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sn = freezed,
    Object? model = freezed,
    Object? version = freezed,
    Object? nodeRole = freezed,
  }) {
    return _then(
      _$DeviceInfoImpl(
        sn: freezed == sn
            ? _value.sn
            : sn // ignore: cast_nullable_to_non_nullable
                  as String?,
        model: freezed == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String?,
        version: freezed == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as String?,
        nodeRole: freezed == nodeRole
            ? _value.nodeRole
            : nodeRole // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DeviceInfoImpl implements _DeviceInfo {
  const _$DeviceInfoImpl({
    @JsonKey(name: 'SN') this.sn,
    this.model,
    this.version,
    @JsonKey(name: 'node_role') this.nodeRole,
  });

  factory _$DeviceInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$DeviceInfoImplFromJson(json);

  @override
  @JsonKey(name: 'SN')
  final String? sn;
  @override
  final String? model;
  @override
  final String? version;
  @override
  @JsonKey(name: 'node_role')
  final String? nodeRole;

  @override
  String toString() {
    return 'DeviceInfo(sn: $sn, model: $model, version: $version, nodeRole: $nodeRole)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceInfoImpl &&
            (identical(other.sn, sn) || other.sn == sn) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.nodeRole, nodeRole) ||
                other.nodeRole == nodeRole));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sn, model, version, nodeRole);

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceInfoImplCopyWith<_$DeviceInfoImpl> get copyWith =>
      __$$DeviceInfoImplCopyWithImpl<_$DeviceInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DeviceInfoImplToJson(this);
  }
}

abstract class _DeviceInfo implements DeviceInfo {
  const factory _DeviceInfo({
    @JsonKey(name: 'SN') final String? sn,
    final String? model,
    final String? version,
    @JsonKey(name: 'node_role') final String? nodeRole,
  }) = _$DeviceInfoImpl;

  factory _DeviceInfo.fromJson(Map<String, dynamic> json) =
      _$DeviceInfoImpl.fromJson;

  @override
  @JsonKey(name: 'SN')
  String? get sn;
  @override
  String? get model;
  @override
  String? get version;
  @override
  @JsonKey(name: 'node_role')
  String? get nodeRole;

  /// Create a copy of DeviceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceInfoImplCopyWith<_$DeviceInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

HubInfo _$HubInfoFromJson(Map<String, dynamic> json) {
  return _HubInfo.fromJson(json);
}

/// @nodoc
mixin _$HubInfo {
  String get hostname => throw _privateConstructorUsedError;
  @JsonKey(name: 'cpu_usage')
  double get cpuUsage => throw _privateConstructorUsedError;
  @JsonKey(name: 'mem_used_mb')
  int get memUsedMb => throw _privateConstructorUsedError;
  @JsonKey(name: 'mem_total_mb')
  int get memTotalMb => throw _privateConstructorUsedError;

  /// Serializes this HubInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of HubInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HubInfoCopyWith<HubInfo> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HubInfoCopyWith<$Res> {
  factory $HubInfoCopyWith(HubInfo value, $Res Function(HubInfo) then) =
      _$HubInfoCopyWithImpl<$Res, HubInfo>;
  @useResult
  $Res call({
    String hostname,
    @JsonKey(name: 'cpu_usage') double cpuUsage,
    @JsonKey(name: 'mem_used_mb') int memUsedMb,
    @JsonKey(name: 'mem_total_mb') int memTotalMb,
  });
}

/// @nodoc
class _$HubInfoCopyWithImpl<$Res, $Val extends HubInfo>
    implements $HubInfoCopyWith<$Res> {
  _$HubInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HubInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hostname = null,
    Object? cpuUsage = null,
    Object? memUsedMb = null,
    Object? memTotalMb = null,
  }) {
    return _then(
      _value.copyWith(
            hostname: null == hostname
                ? _value.hostname
                : hostname // ignore: cast_nullable_to_non_nullable
                      as String,
            cpuUsage: null == cpuUsage
                ? _value.cpuUsage
                : cpuUsage // ignore: cast_nullable_to_non_nullable
                      as double,
            memUsedMb: null == memUsedMb
                ? _value.memUsedMb
                : memUsedMb // ignore: cast_nullable_to_non_nullable
                      as int,
            memTotalMb: null == memTotalMb
                ? _value.memTotalMb
                : memTotalMb // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HubInfoImplCopyWith<$Res> implements $HubInfoCopyWith<$Res> {
  factory _$$HubInfoImplCopyWith(
    _$HubInfoImpl value,
    $Res Function(_$HubInfoImpl) then,
  ) = __$$HubInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String hostname,
    @JsonKey(name: 'cpu_usage') double cpuUsage,
    @JsonKey(name: 'mem_used_mb') int memUsedMb,
    @JsonKey(name: 'mem_total_mb') int memTotalMb,
  });
}

/// @nodoc
class __$$HubInfoImplCopyWithImpl<$Res>
    extends _$HubInfoCopyWithImpl<$Res, _$HubInfoImpl>
    implements _$$HubInfoImplCopyWith<$Res> {
  __$$HubInfoImplCopyWithImpl(
    _$HubInfoImpl _value,
    $Res Function(_$HubInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HubInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hostname = null,
    Object? cpuUsage = null,
    Object? memUsedMb = null,
    Object? memTotalMb = null,
  }) {
    return _then(
      _$HubInfoImpl(
        hostname: null == hostname
            ? _value.hostname
            : hostname // ignore: cast_nullable_to_non_nullable
                  as String,
        cpuUsage: null == cpuUsage
            ? _value.cpuUsage
            : cpuUsage // ignore: cast_nullable_to_non_nullable
                  as double,
        memUsedMb: null == memUsedMb
            ? _value.memUsedMb
            : memUsedMb // ignore: cast_nullable_to_non_nullable
                  as int,
        memTotalMb: null == memTotalMb
            ? _value.memTotalMb
            : memTotalMb // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$HubInfoImpl implements _HubInfo {
  const _$HubInfoImpl({
    this.hostname = '',
    @JsonKey(name: 'cpu_usage') this.cpuUsage = 0.0,
    @JsonKey(name: 'mem_used_mb') this.memUsedMb = 0,
    @JsonKey(name: 'mem_total_mb') this.memTotalMb = 0,
  });

  factory _$HubInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$HubInfoImplFromJson(json);

  @override
  @JsonKey()
  final String hostname;
  @override
  @JsonKey(name: 'cpu_usage')
  final double cpuUsage;
  @override
  @JsonKey(name: 'mem_used_mb')
  final int memUsedMb;
  @override
  @JsonKey(name: 'mem_total_mb')
  final int memTotalMb;

  @override
  String toString() {
    return 'HubInfo(hostname: $hostname, cpuUsage: $cpuUsage, memUsedMb: $memUsedMb, memTotalMb: $memTotalMb)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HubInfoImpl &&
            (identical(other.hostname, hostname) ||
                other.hostname == hostname) &&
            (identical(other.cpuUsage, cpuUsage) ||
                other.cpuUsage == cpuUsage) &&
            (identical(other.memUsedMb, memUsedMb) ||
                other.memUsedMb == memUsedMb) &&
            (identical(other.memTotalMb, memTotalMb) ||
                other.memTotalMb == memTotalMb));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, hostname, cpuUsage, memUsedMb, memTotalMb);

  /// Create a copy of HubInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HubInfoImplCopyWith<_$HubInfoImpl> get copyWith =>
      __$$HubInfoImplCopyWithImpl<_$HubInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$HubInfoImplToJson(this);
  }
}

abstract class _HubInfo implements HubInfo {
  const factory _HubInfo({
    final String hostname,
    @JsonKey(name: 'cpu_usage') final double cpuUsage,
    @JsonKey(name: 'mem_used_mb') final int memUsedMb,
    @JsonKey(name: 'mem_total_mb') final int memTotalMb,
  }) = _$HubInfoImpl;

  factory _HubInfo.fromJson(Map<String, dynamic> json) = _$HubInfoImpl.fromJson;

  @override
  String get hostname;
  @override
  @JsonKey(name: 'cpu_usage')
  double get cpuUsage;
  @override
  @JsonKey(name: 'mem_used_mb')
  int get memUsedMb;
  @override
  @JsonKey(name: 'mem_total_mb')
  int get memTotalMb;

  /// Create a copy of HubInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HubInfoImplCopyWith<_$HubInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RobotInfo {
  @JsonKey(name: 'robot_type')
  String get robotType => throw _privateConstructorUsedError;
  bool get connected =>
      throw _privateConstructorUsedError; // Stored as parsed int (first battery if multi-battery, or null)
  int? get battery => throw _privateConstructorUsedError;

  /// Create a copy of RobotInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RobotInfoCopyWith<RobotInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RobotInfoCopyWith<$Res> {
  factory $RobotInfoCopyWith(RobotInfo value, $Res Function(RobotInfo) then) =
      _$RobotInfoCopyWithImpl<$Res, RobotInfo>;
  @useResult
  $Res call({
    @JsonKey(name: 'robot_type') String robotType,
    bool connected,
    int? battery,
  });
}

/// @nodoc
class _$RobotInfoCopyWithImpl<$Res, $Val extends RobotInfo>
    implements $RobotInfoCopyWith<$Res> {
  _$RobotInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RobotInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? robotType = null,
    Object? connected = null,
    Object? battery = freezed,
  }) {
    return _then(
      _value.copyWith(
            robotType: null == robotType
                ? _value.robotType
                : robotType // ignore: cast_nullable_to_non_nullable
                      as String,
            connected: null == connected
                ? _value.connected
                : connected // ignore: cast_nullable_to_non_nullable
                      as bool,
            battery: freezed == battery
                ? _value.battery
                : battery // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RobotInfoImplCopyWith<$Res>
    implements $RobotInfoCopyWith<$Res> {
  factory _$$RobotInfoImplCopyWith(
    _$RobotInfoImpl value,
    $Res Function(_$RobotInfoImpl) then,
  ) = __$$RobotInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'robot_type') String robotType,
    bool connected,
    int? battery,
  });
}

/// @nodoc
class __$$RobotInfoImplCopyWithImpl<$Res>
    extends _$RobotInfoCopyWithImpl<$Res, _$RobotInfoImpl>
    implements _$$RobotInfoImplCopyWith<$Res> {
  __$$RobotInfoImplCopyWithImpl(
    _$RobotInfoImpl _value,
    $Res Function(_$RobotInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RobotInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? robotType = null,
    Object? connected = null,
    Object? battery = freezed,
  }) {
    return _then(
      _$RobotInfoImpl(
        robotType: null == robotType
            ? _value.robotType
            : robotType // ignore: cast_nullable_to_non_nullable
                  as String,
        connected: null == connected
            ? _value.connected
            : connected // ignore: cast_nullable_to_non_nullable
                  as bool,
        battery: freezed == battery
            ? _value.battery
            : battery // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc

class _$RobotInfoImpl implements _RobotInfo {
  const _$RobotInfoImpl({
    @JsonKey(name: 'robot_type') this.robotType = 'unknown',
    this.connected = false,
    this.battery,
  });

  @override
  @JsonKey(name: 'robot_type')
  final String robotType;
  @override
  @JsonKey()
  final bool connected;
  // Stored as parsed int (first battery if multi-battery, or null)
  @override
  final int? battery;

  @override
  String toString() {
    return 'RobotInfo(robotType: $robotType, connected: $connected, battery: $battery)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RobotInfoImpl &&
            (identical(other.robotType, robotType) ||
                other.robotType == robotType) &&
            (identical(other.connected, connected) ||
                other.connected == connected) &&
            (identical(other.battery, battery) || other.battery == battery));
  }

  @override
  int get hashCode => Object.hash(runtimeType, robotType, connected, battery);

  /// Create a copy of RobotInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RobotInfoImplCopyWith<_$RobotInfoImpl> get copyWith =>
      __$$RobotInfoImplCopyWithImpl<_$RobotInfoImpl>(this, _$identity);
}

abstract class _RobotInfo implements RobotInfo {
  const factory _RobotInfo({
    @JsonKey(name: 'robot_type') final String robotType,
    final bool connected,
    final int? battery,
  }) = _$RobotInfoImpl;

  @override
  @JsonKey(name: 'robot_type')
  String get robotType;
  @override
  bool get connected; // Stored as parsed int (first battery if multi-battery, or null)
  @override
  int? get battery;

  /// Create a copy of RobotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RobotInfoImplCopyWith<_$RobotInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ContainerInfo _$ContainerInfoFromJson(Map<String, dynamic> json) {
  return _ContainerInfo.fromJson(json);
}

/// @nodoc
mixin _$ContainerInfo {
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'service_class')
  String? get serviceClass => throw _privateConstructorUsedError;
  String? get role => throw _privateConstructorUsedError;
  String get state => throw _privateConstructorUsedError;
  String? get health => throw _privateConstructorUsedError;
  bool get critical => throw _privateConstructorUsedError;
  @JsonKey(name: 'allow_manual_stop')
  bool get allowManualStop => throw _privateConstructorUsedError;
  @JsonKey(name: 'mutex_group')
  String? get mutexGroup => throw _privateConstructorUsedError;

  /// Serializes this ContainerInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ContainerInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ContainerInfoCopyWith<ContainerInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContainerInfoCopyWith<$Res> {
  factory $ContainerInfoCopyWith(
    ContainerInfo value,
    $Res Function(ContainerInfo) then,
  ) = _$ContainerInfoCopyWithImpl<$Res, ContainerInfo>;
  @useResult
  $Res call({
    String name,
    @JsonKey(name: 'service_class') String? serviceClass,
    String? role,
    String state,
    String? health,
    bool critical,
    @JsonKey(name: 'allow_manual_stop') bool allowManualStop,
    @JsonKey(name: 'mutex_group') String? mutexGroup,
  });
}

/// @nodoc
class _$ContainerInfoCopyWithImpl<$Res, $Val extends ContainerInfo>
    implements $ContainerInfoCopyWith<$Res> {
  _$ContainerInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ContainerInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? serviceClass = freezed,
    Object? role = freezed,
    Object? state = null,
    Object? health = freezed,
    Object? critical = null,
    Object? allowManualStop = null,
    Object? mutexGroup = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            serviceClass: freezed == serviceClass
                ? _value.serviceClass
                : serviceClass // ignore: cast_nullable_to_non_nullable
                      as String?,
            role: freezed == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String?,
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as String,
            health: freezed == health
                ? _value.health
                : health // ignore: cast_nullable_to_non_nullable
                      as String?,
            critical: null == critical
                ? _value.critical
                : critical // ignore: cast_nullable_to_non_nullable
                      as bool,
            allowManualStop: null == allowManualStop
                ? _value.allowManualStop
                : allowManualStop // ignore: cast_nullable_to_non_nullable
                      as bool,
            mutexGroup: freezed == mutexGroup
                ? _value.mutexGroup
                : mutexGroup // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ContainerInfoImplCopyWith<$Res>
    implements $ContainerInfoCopyWith<$Res> {
  factory _$$ContainerInfoImplCopyWith(
    _$ContainerInfoImpl value,
    $Res Function(_$ContainerInfoImpl) then,
  ) = __$$ContainerInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    @JsonKey(name: 'service_class') String? serviceClass,
    String? role,
    String state,
    String? health,
    bool critical,
    @JsonKey(name: 'allow_manual_stop') bool allowManualStop,
    @JsonKey(name: 'mutex_group') String? mutexGroup,
  });
}

/// @nodoc
class __$$ContainerInfoImplCopyWithImpl<$Res>
    extends _$ContainerInfoCopyWithImpl<$Res, _$ContainerInfoImpl>
    implements _$$ContainerInfoImplCopyWith<$Res> {
  __$$ContainerInfoImplCopyWithImpl(
    _$ContainerInfoImpl _value,
    $Res Function(_$ContainerInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ContainerInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? serviceClass = freezed,
    Object? role = freezed,
    Object? state = null,
    Object? health = freezed,
    Object? critical = null,
    Object? allowManualStop = null,
    Object? mutexGroup = freezed,
  }) {
    return _then(
      _$ContainerInfoImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        serviceClass: freezed == serviceClass
            ? _value.serviceClass
            : serviceClass // ignore: cast_nullable_to_non_nullable
                  as String?,
        role: freezed == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String?,
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as String,
        health: freezed == health
            ? _value.health
            : health // ignore: cast_nullable_to_non_nullable
                  as String?,
        critical: null == critical
            ? _value.critical
            : critical // ignore: cast_nullable_to_non_nullable
                  as bool,
        allowManualStop: null == allowManualStop
            ? _value.allowManualStop
            : allowManualStop // ignore: cast_nullable_to_non_nullable
                  as bool,
        mutexGroup: freezed == mutexGroup
            ? _value.mutexGroup
            : mutexGroup // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ContainerInfoImpl implements _ContainerInfo {
  const _$ContainerInfoImpl({
    required this.name,
    @JsonKey(name: 'service_class') this.serviceClass,
    this.role,
    this.state = 'UNKNOWN',
    this.health,
    this.critical = false,
    @JsonKey(name: 'allow_manual_stop') this.allowManualStop = true,
    @JsonKey(name: 'mutex_group') this.mutexGroup,
  });

  factory _$ContainerInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ContainerInfoImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey(name: 'service_class')
  final String? serviceClass;
  @override
  final String? role;
  @override
  @JsonKey()
  final String state;
  @override
  final String? health;
  @override
  @JsonKey()
  final bool critical;
  @override
  @JsonKey(name: 'allow_manual_stop')
  final bool allowManualStop;
  @override
  @JsonKey(name: 'mutex_group')
  final String? mutexGroup;

  @override
  String toString() {
    return 'ContainerInfo(name: $name, serviceClass: $serviceClass, role: $role, state: $state, health: $health, critical: $critical, allowManualStop: $allowManualStop, mutexGroup: $mutexGroup)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContainerInfoImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.serviceClass, serviceClass) ||
                other.serviceClass == serviceClass) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.health, health) || other.health == health) &&
            (identical(other.critical, critical) ||
                other.critical == critical) &&
            (identical(other.allowManualStop, allowManualStop) ||
                other.allowManualStop == allowManualStop) &&
            (identical(other.mutexGroup, mutexGroup) ||
                other.mutexGroup == mutexGroup));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    serviceClass,
    role,
    state,
    health,
    critical,
    allowManualStop,
    mutexGroup,
  );

  /// Create a copy of ContainerInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ContainerInfoImplCopyWith<_$ContainerInfoImpl> get copyWith =>
      __$$ContainerInfoImplCopyWithImpl<_$ContainerInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ContainerInfoImplToJson(this);
  }
}

abstract class _ContainerInfo implements ContainerInfo {
  const factory _ContainerInfo({
    required final String name,
    @JsonKey(name: 'service_class') final String? serviceClass,
    final String? role,
    final String state,
    final String? health,
    final bool critical,
    @JsonKey(name: 'allow_manual_stop') final bool allowManualStop,
    @JsonKey(name: 'mutex_group') final String? mutexGroup,
  }) = _$ContainerInfoImpl;

  factory _ContainerInfo.fromJson(Map<String, dynamic> json) =
      _$ContainerInfoImpl.fromJson;

  @override
  String get name;
  @override
  @JsonKey(name: 'service_class')
  String? get serviceClass;
  @override
  String? get role;
  @override
  String get state;
  @override
  String? get health;
  @override
  bool get critical;
  @override
  @JsonKey(name: 'allow_manual_stop')
  bool get allowManualStop;
  @override
  @JsonKey(name: 'mutex_group')
  String? get mutexGroup;

  /// Create a copy of ContainerInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ContainerInfoImplCopyWith<_$ContainerInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Waypoint _$WaypointFromJson(Map<String, dynamic> json) {
  return _Waypoint.fromJson(json);
}

/// @nodoc
mixin _$Waypoint {
  double get x => throw _privateConstructorUsedError;
  double get y => throw _privateConstructorUsedError;
  double get theta => throw _privateConstructorUsedError;

  /// Serializes this Waypoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Waypoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WaypointCopyWith<Waypoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WaypointCopyWith<$Res> {
  factory $WaypointCopyWith(Waypoint value, $Res Function(Waypoint) then) =
      _$WaypointCopyWithImpl<$Res, Waypoint>;
  @useResult
  $Res call({double x, double y, double theta});
}

/// @nodoc
class _$WaypointCopyWithImpl<$Res, $Val extends Waypoint>
    implements $WaypointCopyWith<$Res> {
  _$WaypointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Waypoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? x = null, Object? y = null, Object? theta = null}) {
    return _then(
      _value.copyWith(
            x: null == x
                ? _value.x
                : x // ignore: cast_nullable_to_non_nullable
                      as double,
            y: null == y
                ? _value.y
                : y // ignore: cast_nullable_to_non_nullable
                      as double,
            theta: null == theta
                ? _value.theta
                : theta // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WaypointImplCopyWith<$Res>
    implements $WaypointCopyWith<$Res> {
  factory _$$WaypointImplCopyWith(
    _$WaypointImpl value,
    $Res Function(_$WaypointImpl) then,
  ) = __$$WaypointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double x, double y, double theta});
}

/// @nodoc
class __$$WaypointImplCopyWithImpl<$Res>
    extends _$WaypointCopyWithImpl<$Res, _$WaypointImpl>
    implements _$$WaypointImplCopyWith<$Res> {
  __$$WaypointImplCopyWithImpl(
    _$WaypointImpl _value,
    $Res Function(_$WaypointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Waypoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? x = null, Object? y = null, Object? theta = null}) {
    return _then(
      _$WaypointImpl(
        x: null == x
            ? _value.x
            : x // ignore: cast_nullable_to_non_nullable
                  as double,
        y: null == y
            ? _value.y
            : y // ignore: cast_nullable_to_non_nullable
                  as double,
        theta: null == theta
            ? _value.theta
            : theta // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WaypointImpl implements _Waypoint {
  const _$WaypointImpl({required this.x, required this.y, this.theta = 0.0});

  factory _$WaypointImpl.fromJson(Map<String, dynamic> json) =>
      _$$WaypointImplFromJson(json);

  @override
  final double x;
  @override
  final double y;
  @override
  @JsonKey()
  final double theta;

  @override
  String toString() {
    return 'Waypoint(x: $x, y: $y, theta: $theta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WaypointImpl &&
            (identical(other.x, x) || other.x == x) &&
            (identical(other.y, y) || other.y == y) &&
            (identical(other.theta, theta) || other.theta == theta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, x, y, theta);

  /// Create a copy of Waypoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WaypointImplCopyWith<_$WaypointImpl> get copyWith =>
      __$$WaypointImplCopyWithImpl<_$WaypointImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WaypointImplToJson(this);
  }
}

abstract class _Waypoint implements Waypoint {
  const factory _Waypoint({
    required final double x,
    required final double y,
    final double theta,
  }) = _$WaypointImpl;

  factory _Waypoint.fromJson(Map<String, dynamic> json) =
      _$WaypointImpl.fromJson;

  @override
  double get x;
  @override
  double get y;
  @override
  double get theta;

  /// Create a copy of Waypoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WaypointImplCopyWith<_$WaypointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MapInfo _$MapInfoFromJson(Map<String, dynamic> json) {
  return _MapInfo.fromJson(json);
}

/// @nodoc
mixin _$MapInfo {
  String get name => throw _privateConstructorUsedError;
  String? get path => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;
  @JsonKey(name: 'file_count')
  int get fileCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'resolution')
  double get resolution => throw _privateConstructorUsedError; // stored as epoch seconds
  @JsonKey(name: 'created_time')
  double? get createdTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'modified_time')
  double? get modifiedTime => throw _privateConstructorUsedError;

  /// Serializes this MapInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MapInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MapInfoCopyWith<MapInfo> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MapInfoCopyWith<$Res> {
  factory $MapInfoCopyWith(MapInfo value, $Res Function(MapInfo) then) =
      _$MapInfoCopyWithImpl<$Res, MapInfo>;
  @useResult
  $Res call({
    String name,
    String? path,
    int size,
    @JsonKey(name: 'file_count') int fileCount,
    @JsonKey(name: 'resolution') double resolution,
    @JsonKey(name: 'created_time') double? createdTime,
    @JsonKey(name: 'modified_time') double? modifiedTime,
  });
}

/// @nodoc
class _$MapInfoCopyWithImpl<$Res, $Val extends MapInfo>
    implements $MapInfoCopyWith<$Res> {
  _$MapInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MapInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = freezed,
    Object? size = null,
    Object? fileCount = null,
    Object? resolution = null,
    Object? createdTime = freezed,
    Object? modifiedTime = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            path: freezed == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String?,
            size: null == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int,
            fileCount: null == fileCount
                ? _value.fileCount
                : fileCount // ignore: cast_nullable_to_non_nullable
                      as int,
            resolution: null == resolution
                ? _value.resolution
                : resolution // ignore: cast_nullable_to_non_nullable
                      as double,
            createdTime: freezed == createdTime
                ? _value.createdTime
                : createdTime // ignore: cast_nullable_to_non_nullable
                      as double?,
            modifiedTime: freezed == modifiedTime
                ? _value.modifiedTime
                : modifiedTime // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MapInfoImplCopyWith<$Res> implements $MapInfoCopyWith<$Res> {
  factory _$$MapInfoImplCopyWith(
    _$MapInfoImpl value,
    $Res Function(_$MapInfoImpl) then,
  ) = __$$MapInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String? path,
    int size,
    @JsonKey(name: 'file_count') int fileCount,
    @JsonKey(name: 'resolution') double resolution,
    @JsonKey(name: 'created_time') double? createdTime,
    @JsonKey(name: 'modified_time') double? modifiedTime,
  });
}

/// @nodoc
class __$$MapInfoImplCopyWithImpl<$Res>
    extends _$MapInfoCopyWithImpl<$Res, _$MapInfoImpl>
    implements _$$MapInfoImplCopyWith<$Res> {
  __$$MapInfoImplCopyWithImpl(
    _$MapInfoImpl _value,
    $Res Function(_$MapInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MapInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = freezed,
    Object? size = null,
    Object? fileCount = null,
    Object? resolution = null,
    Object? createdTime = freezed,
    Object? modifiedTime = freezed,
  }) {
    return _then(
      _$MapInfoImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        path: freezed == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String?,
        size: null == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int,
        fileCount: null == fileCount
            ? _value.fileCount
            : fileCount // ignore: cast_nullable_to_non_nullable
                  as int,
        resolution: null == resolution
            ? _value.resolution
            : resolution // ignore: cast_nullable_to_non_nullable
                  as double,
        createdTime: freezed == createdTime
            ? _value.createdTime
            : createdTime // ignore: cast_nullable_to_non_nullable
                  as double?,
        modifiedTime: freezed == modifiedTime
            ? _value.modifiedTime
            : modifiedTime // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MapInfoImpl implements _MapInfo {
  const _$MapInfoImpl({
    required this.name,
    this.path,
    this.size = 0,
    @JsonKey(name: 'file_count') this.fileCount = 0,
    @JsonKey(name: 'resolution') this.resolution = 0.05,
    @JsonKey(name: 'created_time') this.createdTime,
    @JsonKey(name: 'modified_time') this.modifiedTime,
  });

  factory _$MapInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$MapInfoImplFromJson(json);

  @override
  final String name;
  @override
  final String? path;
  @override
  @JsonKey()
  final int size;
  @override
  @JsonKey(name: 'file_count')
  final int fileCount;
  @override
  @JsonKey(name: 'resolution')
  final double resolution;
  // stored as epoch seconds
  @override
  @JsonKey(name: 'created_time')
  final double? createdTime;
  @override
  @JsonKey(name: 'modified_time')
  final double? modifiedTime;

  @override
  String toString() {
    return 'MapInfo(name: $name, path: $path, size: $size, fileCount: $fileCount, resolution: $resolution, createdTime: $createdTime, modifiedTime: $modifiedTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MapInfoImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.fileCount, fileCount) ||
                other.fileCount == fileCount) &&
            (identical(other.resolution, resolution) ||
                other.resolution == resolution) &&
            (identical(other.createdTime, createdTime) ||
                other.createdTime == createdTime) &&
            (identical(other.modifiedTime, modifiedTime) ||
                other.modifiedTime == modifiedTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    path,
    size,
    fileCount,
    resolution,
    createdTime,
    modifiedTime,
  );

  /// Create a copy of MapInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MapInfoImplCopyWith<_$MapInfoImpl> get copyWith =>
      __$$MapInfoImplCopyWithImpl<_$MapInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MapInfoImplToJson(this);
  }
}

abstract class _MapInfo implements MapInfo {
  const factory _MapInfo({
    required final String name,
    final String? path,
    final int size,
    @JsonKey(name: 'file_count') final int fileCount,
    @JsonKey(name: 'resolution') final double resolution,
    @JsonKey(name: 'created_time') final double? createdTime,
    @JsonKey(name: 'modified_time') final double? modifiedTime,
  }) = _$MapInfoImpl;

  factory _MapInfo.fromJson(Map<String, dynamic> json) = _$MapInfoImpl.fromJson;

  @override
  String get name;
  @override
  String? get path;
  @override
  int get size;
  @override
  @JsonKey(name: 'file_count')
  int get fileCount;
  @override
  @JsonKey(name: 'resolution')
  double get resolution; // stored as epoch seconds
  @override
  @JsonKey(name: 'created_time')
  double? get createdTime;
  @override
  @JsonKey(name: 'modified_time')
  double? get modifiedTime;

  /// Create a copy of MapInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MapInfoImplCopyWith<_$MapInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FileInfo _$FileInfoFromJson(Map<String, dynamic> json) {
  return _FileInfo.fromJson(json);
}

/// @nodoc
mixin _$FileInfo {
  String get name => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  @JsonKey(name: 'full_path')
  String? get fullPath => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;
  @JsonKey(name: 'mime_type')
  String? get mimeType => throw _privateConstructorUsedError;

  /// Serializes this FileInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FileInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FileInfoCopyWith<FileInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FileInfoCopyWith<$Res> {
  factory $FileInfoCopyWith(FileInfo value, $Res Function(FileInfo) then) =
      _$FileInfoCopyWithImpl<$Res, FileInfo>;
  @useResult
  $Res call({
    String name,
    String path,
    @JsonKey(name: 'full_path') String? fullPath,
    int size,
    @JsonKey(name: 'mime_type') String? mimeType,
  });
}

/// @nodoc
class _$FileInfoCopyWithImpl<$Res, $Val extends FileInfo>
    implements $FileInfoCopyWith<$Res> {
  _$FileInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FileInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? fullPath = freezed,
    Object? size = null,
    Object? mimeType = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            fullPath: freezed == fullPath
                ? _value.fullPath
                : fullPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            size: null == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int,
            mimeType: freezed == mimeType
                ? _value.mimeType
                : mimeType // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FileInfoImplCopyWith<$Res>
    implements $FileInfoCopyWith<$Res> {
  factory _$$FileInfoImplCopyWith(
    _$FileInfoImpl value,
    $Res Function(_$FileInfoImpl) then,
  ) = __$$FileInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String path,
    @JsonKey(name: 'full_path') String? fullPath,
    int size,
    @JsonKey(name: 'mime_type') String? mimeType,
  });
}

/// @nodoc
class __$$FileInfoImplCopyWithImpl<$Res>
    extends _$FileInfoCopyWithImpl<$Res, _$FileInfoImpl>
    implements _$$FileInfoImplCopyWith<$Res> {
  __$$FileInfoImplCopyWithImpl(
    _$FileInfoImpl _value,
    $Res Function(_$FileInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FileInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? fullPath = freezed,
    Object? size = null,
    Object? mimeType = freezed,
  }) {
    return _then(
      _$FileInfoImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        fullPath: freezed == fullPath
            ? _value.fullPath
            : fullPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        size: null == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int,
        mimeType: freezed == mimeType
            ? _value.mimeType
            : mimeType // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FileInfoImpl implements _FileInfo {
  const _$FileInfoImpl({
    required this.name,
    required this.path,
    @JsonKey(name: 'full_path') this.fullPath,
    this.size = 0,
    @JsonKey(name: 'mime_type') this.mimeType,
  });

  factory _$FileInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$FileInfoImplFromJson(json);

  @override
  final String name;
  @override
  final String path;
  @override
  @JsonKey(name: 'full_path')
  final String? fullPath;
  @override
  @JsonKey()
  final int size;
  @override
  @JsonKey(name: 'mime_type')
  final String? mimeType;

  @override
  String toString() {
    return 'FileInfo(name: $name, path: $path, fullPath: $fullPath, size: $size, mimeType: $mimeType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FileInfoImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.fullPath, fullPath) ||
                other.fullPath == fullPath) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.mimeType, mimeType) ||
                other.mimeType == mimeType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, path, fullPath, size, mimeType);

  /// Create a copy of FileInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FileInfoImplCopyWith<_$FileInfoImpl> get copyWith =>
      __$$FileInfoImplCopyWithImpl<_$FileInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FileInfoImplToJson(this);
  }
}

abstract class _FileInfo implements FileInfo {
  const factory _FileInfo({
    required final String name,
    required final String path,
    @JsonKey(name: 'full_path') final String? fullPath,
    final int size,
    @JsonKey(name: 'mime_type') final String? mimeType,
  }) = _$FileInfoImpl;

  factory _FileInfo.fromJson(Map<String, dynamic> json) =
      _$FileInfoImpl.fromJson;

  @override
  String get name;
  @override
  String get path;
  @override
  @JsonKey(name: 'full_path')
  String? get fullPath;
  @override
  int get size;
  @override
  @JsonKey(name: 'mime_type')
  String? get mimeType;

  /// Create a copy of FileInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FileInfoImplCopyWith<_$FileInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MappingStatus _$MappingStatusFromJson(Map<String, dynamic> json) {
  return _MappingStatus.fromJson(json);
}

/// @nodoc
mixin _$MappingStatus {
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'perceptions_available')
  bool get perceptionAvailable => throw _privateConstructorUsedError;
  @JsonKey(name: 'map_available')
  bool get mapAvailable => throw _privateConstructorUsedError;
  @JsonKey(name: 'points_collected')
  int get pointsCollected => throw _privateConstructorUsedError;
  @JsonKey(name: 'scene_name')
  String? get sceneName => throw _privateConstructorUsedError;
  @JsonKey(name: 'output_folder')
  String? get outputFolder => throw _privateConstructorUsedError;

  /// Serializes this MappingStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MappingStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MappingStatusCopyWith<MappingStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MappingStatusCopyWith<$Res> {
  factory $MappingStatusCopyWith(
    MappingStatus value,
    $Res Function(MappingStatus) then,
  ) = _$MappingStatusCopyWithImpl<$Res, MappingStatus>;
  @useResult
  $Res call({
    String status,
    @JsonKey(name: 'perceptions_available') bool perceptionAvailable,
    @JsonKey(name: 'map_available') bool mapAvailable,
    @JsonKey(name: 'points_collected') int pointsCollected,
    @JsonKey(name: 'scene_name') String? sceneName,
    @JsonKey(name: 'output_folder') String? outputFolder,
  });
}

/// @nodoc
class _$MappingStatusCopyWithImpl<$Res, $Val extends MappingStatus>
    implements $MappingStatusCopyWith<$Res> {
  _$MappingStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MappingStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? perceptionAvailable = null,
    Object? mapAvailable = null,
    Object? pointsCollected = null,
    Object? sceneName = freezed,
    Object? outputFolder = freezed,
  }) {
    return _then(
      _value.copyWith(
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            perceptionAvailable: null == perceptionAvailable
                ? _value.perceptionAvailable
                : perceptionAvailable // ignore: cast_nullable_to_non_nullable
                      as bool,
            mapAvailable: null == mapAvailable
                ? _value.mapAvailable
                : mapAvailable // ignore: cast_nullable_to_non_nullable
                      as bool,
            pointsCollected: null == pointsCollected
                ? _value.pointsCollected
                : pointsCollected // ignore: cast_nullable_to_non_nullable
                      as int,
            sceneName: freezed == sceneName
                ? _value.sceneName
                : sceneName // ignore: cast_nullable_to_non_nullable
                      as String?,
            outputFolder: freezed == outputFolder
                ? _value.outputFolder
                : outputFolder // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MappingStatusImplCopyWith<$Res>
    implements $MappingStatusCopyWith<$Res> {
  factory _$$MappingStatusImplCopyWith(
    _$MappingStatusImpl value,
    $Res Function(_$MappingStatusImpl) then,
  ) = __$$MappingStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String status,
    @JsonKey(name: 'perceptions_available') bool perceptionAvailable,
    @JsonKey(name: 'map_available') bool mapAvailable,
    @JsonKey(name: 'points_collected') int pointsCollected,
    @JsonKey(name: 'scene_name') String? sceneName,
    @JsonKey(name: 'output_folder') String? outputFolder,
  });
}

/// @nodoc
class __$$MappingStatusImplCopyWithImpl<$Res>
    extends _$MappingStatusCopyWithImpl<$Res, _$MappingStatusImpl>
    implements _$$MappingStatusImplCopyWith<$Res> {
  __$$MappingStatusImplCopyWithImpl(
    _$MappingStatusImpl _value,
    $Res Function(_$MappingStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MappingStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? perceptionAvailable = null,
    Object? mapAvailable = null,
    Object? pointsCollected = null,
    Object? sceneName = freezed,
    Object? outputFolder = freezed,
  }) {
    return _then(
      _$MappingStatusImpl(
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        perceptionAvailable: null == perceptionAvailable
            ? _value.perceptionAvailable
            : perceptionAvailable // ignore: cast_nullable_to_non_nullable
                  as bool,
        mapAvailable: null == mapAvailable
            ? _value.mapAvailable
            : mapAvailable // ignore: cast_nullable_to_non_nullable
                  as bool,
        pointsCollected: null == pointsCollected
            ? _value.pointsCollected
            : pointsCollected // ignore: cast_nullable_to_non_nullable
                  as int,
        sceneName: freezed == sceneName
            ? _value.sceneName
            : sceneName // ignore: cast_nullable_to_non_nullable
                  as String?,
        outputFolder: freezed == outputFolder
            ? _value.outputFolder
            : outputFolder // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MappingStatusImpl implements _MappingStatus {
  const _$MappingStatusImpl({
    this.status = 'unknown',
    @JsonKey(name: 'perceptions_available') this.perceptionAvailable = false,
    @JsonKey(name: 'map_available') this.mapAvailable = false,
    @JsonKey(name: 'points_collected') this.pointsCollected = 0,
    @JsonKey(name: 'scene_name') this.sceneName,
    @JsonKey(name: 'output_folder') this.outputFolder,
  });

  factory _$MappingStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$MappingStatusImplFromJson(json);

  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey(name: 'perceptions_available')
  final bool perceptionAvailable;
  @override
  @JsonKey(name: 'map_available')
  final bool mapAvailable;
  @override
  @JsonKey(name: 'points_collected')
  final int pointsCollected;
  @override
  @JsonKey(name: 'scene_name')
  final String? sceneName;
  @override
  @JsonKey(name: 'output_folder')
  final String? outputFolder;

  @override
  String toString() {
    return 'MappingStatus(status: $status, perceptionAvailable: $perceptionAvailable, mapAvailable: $mapAvailable, pointsCollected: $pointsCollected, sceneName: $sceneName, outputFolder: $outputFolder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MappingStatusImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.perceptionAvailable, perceptionAvailable) ||
                other.perceptionAvailable == perceptionAvailable) &&
            (identical(other.mapAvailable, mapAvailable) ||
                other.mapAvailable == mapAvailable) &&
            (identical(other.pointsCollected, pointsCollected) ||
                other.pointsCollected == pointsCollected) &&
            (identical(other.sceneName, sceneName) ||
                other.sceneName == sceneName) &&
            (identical(other.outputFolder, outputFolder) ||
                other.outputFolder == outputFolder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    status,
    perceptionAvailable,
    mapAvailable,
    pointsCollected,
    sceneName,
    outputFolder,
  );

  /// Create a copy of MappingStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MappingStatusImplCopyWith<_$MappingStatusImpl> get copyWith =>
      __$$MappingStatusImplCopyWithImpl<_$MappingStatusImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MappingStatusImplToJson(this);
  }
}

abstract class _MappingStatus implements MappingStatus {
  const factory _MappingStatus({
    final String status,
    @JsonKey(name: 'perceptions_available') final bool perceptionAvailable,
    @JsonKey(name: 'map_available') final bool mapAvailable,
    @JsonKey(name: 'points_collected') final int pointsCollected,
    @JsonKey(name: 'scene_name') final String? sceneName,
    @JsonKey(name: 'output_folder') final String? outputFolder,
  }) = _$MappingStatusImpl;

  factory _MappingStatus.fromJson(Map<String, dynamic> json) =
      _$MappingStatusImpl.fromJson;

  @override
  String get status;
  @override
  @JsonKey(name: 'perceptions_available')
  bool get perceptionAvailable;
  @override
  @JsonKey(name: 'map_available')
  bool get mapAvailable;
  @override
  @JsonKey(name: 'points_collected')
  int get pointsCollected;
  @override
  @JsonKey(name: 'scene_name')
  String? get sceneName;
  @override
  @JsonKey(name: 'output_folder')
  String? get outputFolder;

  /// Create a copy of MappingStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MappingStatusImplCopyWith<_$MappingStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LogFileInfo _$LogFileInfoFromJson(Map<String, dynamic> json) {
  return _LogFileInfo.fromJson(json);
}

/// @nodoc
mixin _$LogFileInfo {
  String get name => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;
  @JsonKey(name: 'mod_time')
  DateTime? get modifiedTime => throw _privateConstructorUsedError;

  /// Serializes this LogFileInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LogFileInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LogFileInfoCopyWith<LogFileInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LogFileInfoCopyWith<$Res> {
  factory $LogFileInfoCopyWith(
    LogFileInfo value,
    $Res Function(LogFileInfo) then,
  ) = _$LogFileInfoCopyWithImpl<$Res, LogFileInfo>;
  @useResult
  $Res call({
    String name,
    int size,
    @JsonKey(name: 'mod_time') DateTime? modifiedTime,
  });
}

/// @nodoc
class _$LogFileInfoCopyWithImpl<$Res, $Val extends LogFileInfo>
    implements $LogFileInfoCopyWith<$Res> {
  _$LogFileInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LogFileInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? size = null,
    Object? modifiedTime = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            size: null == size
                ? _value.size
                : size // ignore: cast_nullable_to_non_nullable
                      as int,
            modifiedTime: freezed == modifiedTime
                ? _value.modifiedTime
                : modifiedTime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LogFileInfoImplCopyWith<$Res>
    implements $LogFileInfoCopyWith<$Res> {
  factory _$$LogFileInfoImplCopyWith(
    _$LogFileInfoImpl value,
    $Res Function(_$LogFileInfoImpl) then,
  ) = __$$LogFileInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    int size,
    @JsonKey(name: 'mod_time') DateTime? modifiedTime,
  });
}

/// @nodoc
class __$$LogFileInfoImplCopyWithImpl<$Res>
    extends _$LogFileInfoCopyWithImpl<$Res, _$LogFileInfoImpl>
    implements _$$LogFileInfoImplCopyWith<$Res> {
  __$$LogFileInfoImplCopyWithImpl(
    _$LogFileInfoImpl _value,
    $Res Function(_$LogFileInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LogFileInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? size = null,
    Object? modifiedTime = freezed,
  }) {
    return _then(
      _$LogFileInfoImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        size: null == size
            ? _value.size
            : size // ignore: cast_nullable_to_non_nullable
                  as int,
        modifiedTime: freezed == modifiedTime
            ? _value.modifiedTime
            : modifiedTime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LogFileInfoImpl implements _LogFileInfo {
  const _$LogFileInfoImpl({
    required this.name,
    this.size = 0,
    @JsonKey(name: 'mod_time') this.modifiedTime,
  });

  factory _$LogFileInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$LogFileInfoImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey()
  final int size;
  @override
  @JsonKey(name: 'mod_time')
  final DateTime? modifiedTime;

  @override
  String toString() {
    return 'LogFileInfo(name: $name, size: $size, modifiedTime: $modifiedTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LogFileInfoImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.modifiedTime, modifiedTime) ||
                other.modifiedTime == modifiedTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, size, modifiedTime);

  /// Create a copy of LogFileInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LogFileInfoImplCopyWith<_$LogFileInfoImpl> get copyWith =>
      __$$LogFileInfoImplCopyWithImpl<_$LogFileInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LogFileInfoImplToJson(this);
  }
}

abstract class _LogFileInfo implements LogFileInfo {
  const factory _LogFileInfo({
    required final String name,
    final int size,
    @JsonKey(name: 'mod_time') final DateTime? modifiedTime,
  }) = _$LogFileInfoImpl;

  factory _LogFileInfo.fromJson(Map<String, dynamic> json) =
      _$LogFileInfoImpl.fromJson;

  @override
  String get name;
  @override
  int get size;
  @override
  @JsonKey(name: 'mod_time')
  DateTime? get modifiedTime;

  /// Create a copy of LogFileInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LogFileInfoImplCopyWith<_$LogFileInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
