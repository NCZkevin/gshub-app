import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/core/websocket/ws_connection_manager.dart';

void main() {
  test('subscribes to map pose odometry and emits rosbridge poses', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = Completer<Map<String, dynamic>>();

    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      if (request.uri.path != '/') {
        socket.listen((_) {});
        return;
      }

      socket.listen((data) {
        if (!subscription.isCompleted && data is String) {
          subscription.complete(jsonDecode(data) as Map<String, dynamic>);
        }
        socket.add(
          jsonEncode({
            'op': 'publish',
            'topic': '/map_pose_odometry',
            'msg': {
              'pose': {
                'pose': {
                  'position': {'x': 1.25, 'y': -0.75, 'z': 0},
                  'orientation': {
                    'x': 0,
                    'y': 0,
                    'z': math.sqrt1_2,
                    'w': math.sqrt1_2,
                  },
                },
              },
            },
          }),
        );
      });
    });

    final manager = WsConnectionManager();
    addTearDown(() async {
      manager.dispose();
      await server.close(force: true);
    });

    final baseUrl = 'ws://${server.address.host}:${server.port}';
    manager.connect(
      odometryWsBaseUrl: baseUrl,
      navigationOdometryWsUrl: baseUrl,
      controlWsUrl: '$baseUrl/control',
    );

    final subscribePayload = await subscription.future.timeout(
      const Duration(seconds: 2),
    );
    expect(subscribePayload['op'], 'subscribe');
    expect(subscribePayload['topic'], '/map_pose_odometry');

    final pose = await manager.odometryStream.first.timeout(
      const Duration(seconds: 2),
    );
    expect(pose.x, 1.25);
    expect(pose.y, -0.75);
    expect(pose.heading, closeTo(math.pi / 2, 1e-6));
  });
}
