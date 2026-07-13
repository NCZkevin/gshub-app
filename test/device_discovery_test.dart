import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/core/api/dio_client.dart';
import 'package:sysapp/features/connection/data/device_discovery_repository.dart';

void main() {
  test(
    'manual probe confirms identity without sending an empty bearer header',
    () async {
      String? authorization;
      final server = await _startServer((request) async {
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 0,
            'msg': 'ok',
            'data': {
              'sn': 'GS20250004',
              'model': 'GS-HUB',
              'version': 'v1.0.0',
            },
          }),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final robot = await DeviceDiscoveryRepository().probe(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      );

      expect(authorization, isNull);
      expect(robot.sn, 'GS20250004');
      expect(robot.model, 'GS-HUB');
      expect(robot.version, 'v1.0.0');
      expect(robot.baseUrl, 'http://127.0.0.1:${server.port}');
    },
  );

  test('Dio client sends a non-empty token and reports 401 once', () async {
    String? authorization;
    final server = await _startServer((request) async {
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'code': 1006, 'msg': 'unauthorized', 'data': null}),
      );
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    var unauthorizedCount = 0;
    final client = DioClient.create(
      baseUrl: 'http://127.0.0.1:${server.port}',
      authToken: 'valid-token',
      onUnauthorized: () => unauthorizedCount++,
    );

    await expectLater(client.get('/protected'), throwsA(anything));
    expect(authorization, 'Bearer valid-token');
    expect(unauthorizedCount, 1);
  });
}

Future<HttpServer> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}
