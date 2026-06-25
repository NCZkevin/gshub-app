import 'dart:typed_data';
import '../../../core/api/dio_client.dart';
import '../../../shared/domain/app_models.dart';

class NavigationRepository {
  final DioClient _client;

  NavigationRepository(this._client);

  // ─── 地图列表 ─────────────────────────────────────────────────
  // GET /maps → {total, maps: [...]}

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
  Future<List<FileInfo>> fetchMapFiles(String mapName) async {
    final data = await _client.get('/maps/$mapName/files');
    if (data == null) return [];
    final map = data as Map<String, dynamic>;
    final list = map['files'] as List<dynamic>? ?? [];
    return list
        .map((e) => FileInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 下载 PGM 二进制文件
  Future<Uint8List?> fetchMapPgm(String mapName) async {
    try {
      final files = await fetchMapFiles(mapName);
      final pgmFile = files.firstWhere(
        (f) => f.name.endsWith('.pgm'),
        orElse: () =>
            files.isNotEmpty ? files.first : const FileInfo(name: '', path: ''),
      );
      if (pgmFile.name.isEmpty) return null;
      final bytes = await _client.getBytes(
        '/maps/$mapName/files/${pgmFile.path}',
      );
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  // ─── 导航容器 ─────────────────────────────────────────────────

  /// GET /nav/container/status → {running, status, container_id}
  Future<Map<String, dynamic>> checkContainerStatus() async {
    final data = await _client.get('/nav/container/status');
    if (data == null) return {'running': false, 'status': 'unknown'};
    return data as Map<String, dynamic>;
  }

  /// POST /nav/container/start
  Future<void> startNavContainer(
    String sceneName, {
    bool relocalization = false,
  }) => _client.post(
    '/nav/container/start',
    data: {'scene_name': sceneName, 'use_relocalization': relocalization},
  );

  /// POST /nav/container/stop (async)
  Future<void> stopNavContainer() => _client.post('/nav/container/stop');

  // ─── 导航状态 ─────────────────────────────────────────────────

  /// POST /nav/navigation_status → {status, relocalization}
  Future<NavStatus?> fetchNavStatus() async {
    final data = await _client.post('/nav/navigation_status');
    if (data == null) return null;
    return NavStatus.fromJson(data as Map<String, dynamic>);
  }

  // ─── 导航控制 ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> createMission(
    Map<String, dynamic> request,
  ) async {
    final data = await _client.post('/nav/missions', data: request);
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchMission(String missionId) async {
    final data = await _client.get('/nav/missions/$missionId');
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  Future<void> cancelMission(String missionId) =>
      _client.delete('/nav/missions/$missionId');

  Future<void> startNavigateTo(double x, double y, double theta) => _client
      .post('/nav/start_navigation', data: {'x': x, 'y': y, 'theta': theta});

  Future<void> startPathNavigation(List<Waypoint> waypoints, int cycles) =>
      _client.post(
        '/nav/start_path_navigation',
        data: {
          'waypoints': waypoints
              .map((w) => {'x': w.x, 'y': w.y, 'theta': w.theta})
              .toList(),
          'cycles': cycles,
        },
      );

  Future<void> stopNavigating() => _client.post('/nav/stop_navigation');
  Future<void> pauseNav() => _client.post('/nav/pause_navigation');
  Future<void> resumeNav() => _client.post('/nav/resume_navigation');

  Future<Map<String, dynamic>> getSavedNavParams(List<String> names) async {
    final data = await _client.post(
      '/nav/get_saved_nav_params',
      data: {'names': names},
    );
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNavParams(List<String> names) async {
    final data = await _client.post(
      '/nav/get_nav_params',
      data: {'names': names},
    );
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setNavParams(Map<String, dynamic> params) async {
    final data = await _client.post('/nav/set_nav_params', data: params);
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchLandmarks(String sceneName) async {
    final data = await _client.get(
      '/nav/landmarks',
      queryParameters: {'scene_name': sceneName},
    );
    if (data == null) return [];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    final map = data as Map<String, dynamic>;
    final list = map['items'] ?? map['landmarks'] ?? [];
    if (list is! List) return [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> saveLandmark({
    required String name,
    required String sceneName,
    required String kind,
    required List<Waypoint> points,
  }) async {
    final data = await _client.post(
      '/nav/landmarks',
      data: {
        'name': name,
        'scene_name': sceneName,
        'kind': kind,
        'points': points
            .map((point) => {'x': point.x, 'y': point.y, 'theta': point.theta})
            .toList(),
      },
    );
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startLandmark(int id, int cycles) async {
    final data = await _client.post(
      '/nav/landmarks/$id/start',
      data: {'cycles': cycles},
    );
    if (data == null) return {};
    return data as Map<String, dynamic>;
  }

  // ─── 规划路径 ─────────────────────────────────────────────────

  /// POST /nav/get_plan_path → {global: [[x,y], ...]}
  Future<List<(double x, double y)>> fetchPlanPath() async {
    final data = await _client.post('/nav/get_plan_path');
    if (data == null) return [];
    final map = data as Map<String, dynamic>;
    final global = map['global'] as List<dynamic>? ?? [];
    return global.map((e) {
      final pair = e as List<dynamic>;
      return ((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
    }).toList();
  }

  // ─── 重定位 ───────────────────────────────────────────────────

  Future<void> setRelocalizationPose(double x, double y, double theta) =>
      _client.post(
        '/nav/set_relocalization_pose',
        data: {'x': x, 'y': y, 'theta': theta},
      );

  Future<void> toggleRelocalization(bool enable) =>
      _client.post('/nav/relocalization_toggle', data: {'enable': enable});
}
