import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/features/connection/data/machine_connection_probe.dart';
import 'package:sysapp/features/connection/domain/connection_model.dart';

void main() {
  test('probe rejects an address that belongs to another machine', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'code': 0,
          'msg': 'ok',
          'data': {'sn': 'GS-OTHER'},
        }),
      );
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final connection = RobotConnection(
      id: 'GS-EXPECTED',
      name: '目标机器',
      baseUrl: 'http://127.0.0.1:${server.port}',
    );

    await expectLater(
      HttpMachineConnectionProbe().probe(connection),
      throwsA(
        isA<MachineConnectionException>().having(
          (error) => error.kind,
          'kind',
          MachineConnectionFailureKind.identityMismatch,
        ),
      ),
    );
  });

  test('probe keeps legacy UUID connections compatible', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'code': 0,
          'msg': 'ok',
          'data': {'sn': 'GS-LEGACY'},
        }),
      );
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final connection = RobotConnection(
      id: '550e8400-e29b-41d4-a716-446655440000',
      name: '旧版机器配置',
      baseUrl: 'http://127.0.0.1:${server.port}',
    );

    final result = await HttpMachineConnectionProbe().probe(connection);

    expect(result.sn, 'GS-LEGACY');
  });
}
