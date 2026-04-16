import '../../../core/api/dio_client.dart';
import '../../../shared/domain/app_models.dart';

class MappingRepository {
  final DioClient _client;

  MappingRepository(this._client);

  /// POST /mapping/container/start — 快速失败检测模式（5s窗口）
  Future<void> startMapping(String sceneName) async {
    await _client.post(
      '/mapping/container/start',
      data: {'scene_name': sceneName},
    );
  }

  /// POST /mapping/container/stop
  Future<void> stopMapping() async {
    await _client.post('/mapping/container/stop');
  }

  /// GET /mapping/container/status → {running, status, container_id}
  Future<Map<String, dynamic>> fetchContainerStatus() async {
    final data = await _client.get('/mapping/container/status');
    if (data == null) return {'running': false, 'status': 'unknown'};
    return data as Map<String, dynamic>;
  }

  /// POST /mapping/status → MappingStatus
  Future<MappingStatus?> fetchMappingStatus() async {
    try {
      final data = await _client.post('/mapping/status');
      if (data == null) return null;
      return MappingStatus.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// GET /maps → {total, maps: [...]}
  Future<List<MapInfo>> fetchMaps() async {
    final data = await _client.get('/maps');
    if (data == null) return [];
    final map = data as Map<String, dynamic>;
    final list = map['maps'] as List<dynamic>? ?? [];
    return list
        .map((e) => MapInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /maps/{name}
  Future<void> deleteMap(String name) async {
    await _client.delete('/maps/$name');
  }

  String mapArchiveUrl(String baseUrl, String name) {
    return '$baseUrl/v1/api/maps/$name/archive';
  }
}
