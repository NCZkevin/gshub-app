import '../../../core/api/dio_client.dart';
import '../../../shared/domain/app_models.dart';

class DashboardRepository {
  final DioClient _client;

  DashboardRepository(this._client);

  /// GET /systems/hub — CPU/内存
  Future<HubInfo?> fetchHubInfo() async {
    final data = await _client.get('/systems/hub');
    if (data == null) return null;
    return HubInfo.fromJson(data as Map<String, dynamic>);
  }

  /// GET /systems/robot — 机器人连接状态和电量
  Future<RobotInfo?> fetchRobotInfo() async {
    final data = await _client.get('/systems/robot');
    if (data == null) return null;
    return RobotInfo.fromJson(data as Map<String, dynamic>);
  }

  /// GET /runtime/containers?class=model
  Future<List<ContainerInfo>> fetchContainers({String? serviceClass}) async {
    final data = await _client.get(
      '/runtime/containers',
      queryParameters: serviceClass != null ? {'class': serviceClass} : null,
    );
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => ContainerInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /runtime/containers/{name}/actions/start (async)
  Future<void> startContainer(String name) =>
      _client.post('/runtime/containers/$name/actions/start');

  /// POST /runtime/containers/{name}/actions/stop (async)
  Future<void> stopContainer(String name) =>
      _client.post('/runtime/containers/$name/actions/stop');

  /// GET /services/status — 所有下游服务汇总
  Future<Map<String, dynamic>?> fetchServicesStatus() async {
    final data = await _client.get('/services/status');
    return data as Map<String, dynamic>?;
  }

  /// POST /services/motion/start
  Future<void> startMotion(String adapterType) =>
      _client.post('/services/motion/start',
          data: {'adapter_type': adapterType});

  /// POST /services/motion/stop
  Future<void> stopMotion() => _client.post('/services/motion/stop');

  /// GET /services/motion/adapters → {enabled_adapter_types: [...]}
  Future<List<String>> fetchMotionAdapters() async {
    final data = await _client.get('/services/motion/adapters');
    if (data == null) return [];
    final map = data as Map<String, dynamic>;
    final list = map['enabled_adapter_types'];
    if (list == null) return [];
    return (list as List<dynamic>).map((e) => e.toString()).toList();
  }
}
