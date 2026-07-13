import '../../../core/api/dio_client.dart';
import 'mdns_browser.dart';

class DiscoveredRobot {
  final String sn;
  final String? model;
  final String? version;
  final String host;
  final int port;

  const DiscoveredRobot({
    required this.sn,
    required this.host,
    required this.port,
    this.model,
    this.version,
  });

  String get baseUrl => Uri(
    scheme: 'http',
    host: host,
    port: port,
  ).toString().replaceFirst(RegExp(r'/$'), '');
}

class DeviceDiscoveryRepository {
  Future<List<DiscoveredRobot>> discover() async {
    final endpoints = await browseGshubEndpoints();
    final results = await Future.wait(
      endpoints.map((endpoint) async {
        try {
          return await probe(host: endpoint.host, port: endpoint.port);
        } catch (_) {
          return null;
        }
      }),
    );

    final bySN = <String, DiscoveredRobot>{};
    for (final result in results) {
      if (result != null) bySN[result.sn] = result;
    }
    return bySN.values.toList(growable: false);
  }

  Future<DiscoveredRobot> probe({
    required String host,
    required int port,
  }) async {
    final baseUrl = Uri(
      scheme: 'http',
      host: host,
      port: port,
    ).toString().replaceFirst(RegExp(r'/$'), '');
    final client = DioClient.create(baseUrl: baseUrl);
    final data = await client.get('/systems/device');
    if (data is! Map<String, dynamic>) {
      throw const FormatException('设备信息格式不正确');
    }
    final sn = (data['sn'] ?? data['SN'])?.toString().trim() ?? '';
    if (sn.isEmpty) {
      throw const FormatException('设备未返回序列号');
    }
    return DiscoveredRobot(
      sn: sn,
      model: data['model']?.toString(),
      version: data['version']?.toString(),
      host: host,
      port: port,
    );
  }
}
