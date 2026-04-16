import 'package:freezed_annotation/freezed_annotation.dart';

part 'connection_model.freezed.dart';
part 'connection_model.g.dart';

/// 机器人展位连接配置（明文部分存 SharedPreferences，Token 存 SecureStorage）
@freezed
class RobotConnection with _$RobotConnection {
  const factory RobotConnection({
    required String id,
    required String name,
    required String baseUrl, // e.g. http://192.168.1.100:8080
    // apiToken 和 terminalToken 不在此存储，存于 SecureStorage
  }) = _RobotConnection;

  factory RobotConnection.fromJson(Map<String, dynamic> json) =>
      _$RobotConnectionFromJson(json);
}
