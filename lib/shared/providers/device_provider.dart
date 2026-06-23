import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/connection/presentation/connection_provider.dart';
import '../domain/app_models.dart';

/// 设备基础信息（应用启动后拉取一次，机器切换时重新拉取）
final deviceInfoProvider = FutureProvider<DeviceInfo?>((ref) async {
  final client = await ref.watch(dioClientFutureProvider.future);
  if (client == null) return null;
  final data = await client.get('/device');
  if (data == null) return null;
  return DeviceInfo.fromJson(data as Map<String, dynamic>);
});

/// 机器人连接状态
final robotInfoProvider = FutureProvider<RobotInfo?>((ref) async {
  final client = await ref.watch(dioClientFutureProvider.future);
  if (client == null) return null;
  final data = await client.get('/robot_info');
  if (data == null) return null;
  return RobotInfo.fromJson(data as Map<String, dynamic>);
});
