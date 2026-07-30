import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/core/api/dio_client.dart';
import 'package:sysapp/features/navigation/data/navigation_repository.dart';

void main() {
  test(
    'current navigation task reads the core uppercase task contract',
    () async {
      late String requestedPath;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requestedPath = request.uri.path;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 0,
            'msg': 'ok',
            'data': {'ID': 'task-42', 'Type': 'navigation', 'Status': 1},
          }),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final repository = NavigationRepository(
        DioClient.create(baseUrl: 'http://127.0.0.1:${server.port}'),
      );

      final taskId = await repository.fetchCurrentNavigationTaskId();

      expect(requestedPath, '/v1/api/tasks/current');
      expect(taskId, 'task-42');
    },
  );
}
