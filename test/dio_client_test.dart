import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/core/api/api_error.dart';
import 'package:sysapp/core/api/dio_client.dart';

void main() {
  test(
    'non-2xx API envelope preserves status and exposes business error',
    () async {
      final server = await _startServer((request) async {
        request.response.statusCode = HttpStatus.badGateway;
        request.response.write(
          jsonEncode({
            'code': 1005,
            'msg': 'navigation service is starting',
            'data': null,
          }),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final client = DioClient.create(
        baseUrl: 'http://127.0.0.1:${server.port}',
      );

      await expectLater(
        client.post('/nav/navigation_status'),
        throwsA(
          isA<DioException>()
              .having(
                (exception) => exception.type,
                'type',
                DioExceptionType.badResponse,
              )
              .having(
                (exception) => exception.response?.statusCode,
                'status',
                HttpStatus.badGateway,
              )
              .having(
                (exception) => exception.message,
                'message',
                'navigation service is starting',
              )
              .having(
                (exception) => exception.error,
                'error',
                isA<ApiException>()
                    .having((error) => error.code, 'code', 1005)
                    .having(
                      (error) => error.message,
                      'message',
                      'navigation service is starting',
                    ),
              ),
        ),
      );
    },
  );
}

Future<HttpServer> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}
