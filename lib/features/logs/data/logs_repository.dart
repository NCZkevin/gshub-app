import '../../../core/api/dio_client.dart';
import '../../../shared/domain/app_models.dart';

class LogsRepository {
  final DioClient _client;

  LogsRepository(this._client);

  /// GET /logs/list → {items: [{name, size, mod_time}]}
  Future<List<LogFileInfo>> fetchList() async {
    final data = await _client.get('/logs/list');
    if (data == null) return [];
    final map = data as Map<String, dynamic>;
    final list = map['items'] as List<dynamic>? ?? [];
    return list.map((e) => LogFileInfo.fromJson(_normalizeLogFile(e))).toList();
  }

  /// GET /logs/{filename} → {filename, content}
  Future<String> fetchContent(String filename) async {
    final data = await _client.get('/logs/$filename');
    if (data == null) return '';
    final map = data as Map<String, dynamic>;
    return map['content'] as String? ?? '';
  }

  /// DELETE /logs/{filename}
  Future<void> deleteLog(String filename) async {
    await _client.delete('/logs/$filename');
  }

  /// POST /logs/actions/cleanup
  Future<void> cleanup() async {
    try {
      await _client.post('/logs/cleanup');
    } catch (_) {
      await _client.post('/logs/actions/cleanup');
    }
  }

  Map<String, dynamic> _normalizeLogFile(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    json['name'] ??= json['filename'];
    json['mod_time'] ??= json['last_modified'];
    return json;
  }
}
