import 'dart:typed_data';

import 'package:dio/dio.dart';

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

  /// GET /maps/{name}/files → {map_name, total, files: [...]}
  Future<List<FileInfo>> fetchMapFiles(String name) async {
    final data = await _client.get('/maps/$name/files');
    if (data == null) return [];
    final map = data as Map<String, dynamic>;
    final list = map['files'] as List<dynamic>? ?? [];
    return list
        .map((e) => FileInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /maps/{name}/files/{filePath}
  Future<Uint8List> fetchMapFile(String name, String filePath) async {
    final bytes = await _client.getBytes('/maps/$name/files/$filePath');
    return Uint8List.fromList(bytes);
  }

  /// GET /maps/{name}/archive
  Future<Uint8List> fetchArchive(String name) async {
    final bytes = await _client.getBytes('/maps/$name/archive');
    return Uint8List.fromList(bytes);
  }

  /// PUT /maps/{name} — 上传编辑后的 PGM
  Future<void> updateMapPgm(String name, Uint8List bytes) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: '$name.pgm'),
    });
    await _client.put(
      '/maps/$name',
      data: form,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
  }

  /// DELETE /maps/{name}
  Future<void> deleteMap(String name) async {
    await _client.delete('/maps/$name');
  }

  String mapArchiveUrl(String baseUrl, String name) {
    return '$baseUrl/v1/api/maps/$name/archive';
  }
}
