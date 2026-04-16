// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connection_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RobotConnection _$RobotConnectionFromJson(Map<String, dynamic> json) {
  return _RobotConnection.fromJson(json);
}

/// @nodoc
mixin _$RobotConnection {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get baseUrl => throw _privateConstructorUsedError;

  /// Serializes this RobotConnection to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RobotConnection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RobotConnectionCopyWith<RobotConnection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RobotConnectionCopyWith<$Res> {
  factory $RobotConnectionCopyWith(
    RobotConnection value,
    $Res Function(RobotConnection) then,
  ) = _$RobotConnectionCopyWithImpl<$Res, RobotConnection>;
  @useResult
  $Res call({String id, String name, String baseUrl});
}

/// @nodoc
class _$RobotConnectionCopyWithImpl<$Res, $Val extends RobotConnection>
    implements $RobotConnectionCopyWith<$Res> {
  _$RobotConnectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RobotConnection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? name = null, Object? baseUrl = null}) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            baseUrl: null == baseUrl
                ? _value.baseUrl
                : baseUrl // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RobotConnectionImplCopyWith<$Res>
    implements $RobotConnectionCopyWith<$Res> {
  factory _$$RobotConnectionImplCopyWith(
    _$RobotConnectionImpl value,
    $Res Function(_$RobotConnectionImpl) then,
  ) = __$$RobotConnectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, String baseUrl});
}

/// @nodoc
class __$$RobotConnectionImplCopyWithImpl<$Res>
    extends _$RobotConnectionCopyWithImpl<$Res, _$RobotConnectionImpl>
    implements _$$RobotConnectionImplCopyWith<$Res> {
  __$$RobotConnectionImplCopyWithImpl(
    _$RobotConnectionImpl _value,
    $Res Function(_$RobotConnectionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RobotConnection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? name = null, Object? baseUrl = null}) {
    return _then(
      _$RobotConnectionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        baseUrl: null == baseUrl
            ? _value.baseUrl
            : baseUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RobotConnectionImpl implements _RobotConnection {
  const _$RobotConnectionImpl({
    required this.id,
    required this.name,
    required this.baseUrl,
  });

  factory _$RobotConnectionImpl.fromJson(Map<String, dynamic> json) =>
      _$$RobotConnectionImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;

  @override
  String toString() {
    return 'RobotConnection(id: $id, name: $name, baseUrl: $baseUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RobotConnectionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, baseUrl);

  /// Create a copy of RobotConnection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RobotConnectionImplCopyWith<_$RobotConnectionImpl> get copyWith =>
      __$$RobotConnectionImplCopyWithImpl<_$RobotConnectionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RobotConnectionImplToJson(this);
  }
}

abstract class _RobotConnection implements RobotConnection {
  const factory _RobotConnection({
    required final String id,
    required final String name,
    required final String baseUrl,
  }) = _$RobotConnectionImpl;

  factory _RobotConnection.fromJson(Map<String, dynamic> json) =
      _$RobotConnectionImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get baseUrl;

  /// Create a copy of RobotConnection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RobotConnectionImplCopyWith<_$RobotConnectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
