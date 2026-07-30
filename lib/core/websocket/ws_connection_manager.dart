import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

class RobotOdometry {
  final double x;
  final double y;
  final double heading;

  const RobotOdometry({
    required this.x,
    required this.y,
    required this.heading,
  });

  factory RobotOdometry.fromJson(Map<String, dynamic> json) {
    final message = json['msg'];
    if (message is Map<String, dynamic>) {
      final poseWrapper = message['pose'];
      final pose = poseWrapper is Map<String, dynamic>
          ? poseWrapper['pose']
          : null;
      if (pose is Map<String, dynamic>) {
        final position = pose['position'];
        final orientation = pose['orientation'];
        if (position is Map<String, dynamic> &&
            orientation is Map<String, dynamic>) {
          final qx = _number(orientation, 'x');
          final qy = _number(orientation, 'y');
          final qz = _number(orientation, 'z');
          final qw = _number(orientation, 'w');
          final sinyCosp = 2 * (qw * qz + qx * qy);
          final cosyCosp = 1 - 2 * (qy * qy + qz * qz);
          return RobotOdometry(
            x: _number(position, 'x'),
            y: _number(position, 'y'),
            heading: math.atan2(sinyCosp, cosyCosp),
          );
        }
      }
    }

    return RobotOdometry(
      x: _number(json, 'x'),
      y: _number(json, 'y'),
      heading: _number(json, 'heading'),
    );
  }

  static double _number(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) {
      throw FormatException('missing numeric odometry field: $key');
    }
    return value.toDouble();
  }
}

/// 统一管理所有 WebSocket 连接
/// - 导航地图坐标位姿（odometryStream）
/// - 机器人控制（sendCmdVel）
class WsConnectionManager {
  String _odometryWsUrl = '';
  String _controlWsUrl = '';
  bool _active = false;

  // Version counters prevent stale reconnect callbacks from firing
  // after disconnect() or a newer connect() call.
  int _odometryGen = 0;
  int _controlGen = 0;

  WebSocketChannel? _odometryChannel;
  WebSocketChannel? _controlChannel;
  StreamSubscription? _odometrySub;
  StreamSubscription? _controlSub;

  final _odometryController = StreamController<RobotOdometry>.broadcast();
  Stream<RobotOdometry> get odometryStream => _odometryController.stream;

  DateTime _lastCmdVel = DateTime(0);
  static const _cmdVelCooldown = Duration(milliseconds: 100);

  int _odometryRetry = 0;
  int _controlRetry = 0;

  Duration _backoff(int retry) =>
      Duration(seconds: (2 << retry.clamp(0, 4)).clamp(2, 30));

  void connect({
    required String odometryWsBaseUrl,
    String? navigationOdometryWsUrl,
    required String controlWsUrl,
  }) {
    disconnect();
    final baseUri = Uri.parse(odometryWsBaseUrl);
    _odometryWsUrl =
        navigationOdometryWsUrl ??
        Uri(scheme: baseUri.scheme, host: baseUri.host, port: 7997).toString();
    _controlWsUrl = controlWsUrl;
    _active = true;
    _odometryRetry = 0;
    _controlRetry = 0;
    _connectOdometry(++_odometryGen);
    _connectControl(++_controlGen);
  }

  void reconnectOdometry() {
    if (!_active || _odometryWsUrl.isEmpty) return;
    _odometryRetry = 0;
    _connectOdometry(++_odometryGen);
  }

  void disconnect() {
    _active = false;
    // Bump generations so any pending delayed callbacks become no-ops
    _odometryGen++;
    _controlGen++;
    _odometrySub?.cancel();
    _odometrySub = null;
    _controlSub?.cancel();
    _controlSub = null;
    _odometryChannel?.sink.close();
    _odometryChannel = null;
    _controlChannel?.sink.close();
    _controlChannel = null;
  }

  Future<void> _connectOdometry(int gen) async {
    if (!_active || gen != _odometryGen) return;

    // Clean up previous channel
    await _odometrySub?.cancel();
    _odometrySub = null;
    _odometryChannel?.sink.close();
    _odometryChannel = null;

    final uri = Uri.parse(_odometryWsUrl);
    final channel = WebSocketChannel.connect(uri);
    _odometryChannel = channel;

    // Wait for handshake — this is where Connection refused surfaces
    try {
      await channel.ready;
    } catch (_) {
      channel.sink.close();
      if (_active && gen == _odometryGen) {
        _odometryRetry++;
        await Future.delayed(_backoff(_odometryRetry));
        return _connectOdometry(gen);
      }
      return;
    }

    if (!_active || gen != _odometryGen) {
      channel.sink.close();
      return;
    }

    // Connected — reset retry counter
    _odometryRetry = 0;

    _odometrySub = channel.stream.listen(
      (data) {
        if (data is String) {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            _odometryController.add(RobotOdometry.fromJson(json));
          } catch (_) {}
        }
      },
      onDone: () {
        if (_active && gen == _odometryGen) {
          _odometryRetry++;
          Future.delayed(_backoff(_odometryRetry), () => _connectOdometry(gen));
        }
      },
      onError: (e) {
        // Swallow — reconnect handled via onDone after cancelOnError
      },
      cancelOnError: true,
    );
    channel.sink.add(
      jsonEncode({'op': 'subscribe', 'topic': '/map_pose_odometry'}),
    );
  }

  Future<void> _connectControl(int gen) async {
    if (!_active || gen != _controlGen) return;

    await _controlSub?.cancel();
    _controlSub = null;
    _controlChannel?.sink.close();
    _controlChannel = null;

    final uri = Uri.parse(_controlWsUrl);
    final channel = WebSocketChannel.connect(uri);
    _controlChannel = channel;

    try {
      await channel.ready;
    } catch (_) {
      channel.sink.close();
      if (_active && gen == _controlGen) {
        _controlRetry++;
        await Future.delayed(_backoff(_controlRetry));
        return _connectControl(gen);
      }
      return;
    }

    if (!_active || gen != _controlGen) {
      channel.sink.close();
      return;
    }

    _controlRetry = 0;

    _controlSub = channel.stream.listen(
      (_) {},
      onDone: () {
        if (_active && gen == _controlGen) {
          _controlRetry++;
          Future.delayed(_backoff(_controlRetry), () => _connectControl(gen));
        }
      },
      onError: (e) {},
      cancelOnError: true,
    );
  }

  /// 发送速度指令，带 100ms 冷却防抖
  void sendCmdVel(
    double linearX,
    double angularZ, {
    double linearY = 0,
    bool force = false,
  }) {
    final now = DateTime.now();
    if (!force && now.difference(_lastCmdVel) < _cmdVelCooldown) return;
    _lastCmdVel = now;
    final channel = _controlChannel;
    if (channel == null) return;
    try {
      channel.sink.add(
        jsonEncode({
          'linear_x': linearX,
          'linear_y': linearY,
          'linear_z': 0,
          'angular_x': 0,
          'angular_y': 0,
          'angular_z': angularZ,
        }),
      );
    } catch (_) {}
  }

  void sendStop() => sendCmdVel(0, 0, force: true);

  void dispose() {
    disconnect();
    _odometryController.close();
  }
}
