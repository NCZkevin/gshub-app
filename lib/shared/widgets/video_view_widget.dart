import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../app/theme.dart';

/// Janus WebRTC 视频视图占位
/// 完整的 Janus 信令接入在 video_view_controller.dart 实现
/// 此 Widget 只负责渲染 RTCVideoRenderer
class VideoViewWidget extends StatefulWidget {
  final RTCVideoRenderer? renderer;
  final String? placeholderText;

  const VideoViewWidget({super.key, this.renderer, this.placeholderText});

  @override
  State<VideoViewWidget> createState() => _VideoViewWidgetState();
}

class _VideoViewWidgetState extends State<VideoViewWidget> {
  @override
  Widget build(BuildContext context) {
    final renderer = widget.renderer;
    if (renderer == null) {
      return Container(
        color: const Color(0xFF020617),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off,
                size: 42,
                color: AppTheme.slate400.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 8),
              Text(
                widget.placeholderText ?? '视频流未连接',
                style: TextStyle(
                  color: AppTheme.slate400,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RTCVideoView(
      renderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }
}

/// Janus WebRTC 信令控制器，使用 Janus WebSocket API 和 streaming 插件。
class JanusVideoController {
  final int streamId;
  final ValueNotifier<String> status = ValueNotifier<String>('未连接');

  RTCVideoRenderer? renderer;
  RTCPeerConnection? _pc;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _keepAliveTimer;
  int? _sessionId;
  int? _handleId;
  bool _remoteDescriptionSet = false;
  final List<Map<String, dynamic>> _pendingCandidates = [];
  final Map<String, Completer<Map<String, dynamic>>> _transactions = {};

  JanusVideoController({required this.streamId});

  Future<void> initialize() async {
    renderer = RTCVideoRenderer();
    await renderer!.initialize();
  }

  Future<void> connect(String janusWsUrl) async {
    await disconnect();
    status.value = '连接中...';

    final channel = WebSocketChannel.connect(
      Uri.parse(janusWsUrl),
      protocols: const ['janus-protocol'],
    );
    _channel = channel;
    _sub = channel.stream.listen(
      _handleMessage,
      onDone: () => status.value = '连接已断开',
      onError: (_) => status.value = '连接失败',
      cancelOnError: true,
    );

    await channel.ready;
    final create = await _request({'janus': 'create'});
    _sessionId = create['data']?['id'] as int?;
    if (_sessionId == null) throw StateError('Janus session missing');

    _keepAliveTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _send({'janus': 'keepalive', 'session_id': _sessionId}),
    );

    final attach = await _request({
      'janus': 'attach',
      'session_id': _sessionId,
      'plugin': 'janus.plugin.streaming',
      'opaque_id': 'flutter-streaming-$streamId',
    });
    _handleId = attach['data']?['id'] as int?;
    if (_handleId == null) throw StateError('Janus handle missing');

    status.value = '会话已建立';
    await _sendPluginMessage({'request': 'watch', 'id': streamId});
    status.value = '视频请求已发送';
  }

  void _handleMessage(dynamic data) {
    if (data is! String) return;
    final msg = jsonDecode(data) as Map<String, dynamic>;
    final transaction = msg['transaction'] as String?;
    if (transaction != null) {
      final completer = _transactions.remove(transaction);
      if (completer != null && !completer.isCompleted) {
        completer.complete(msg);
      }
    }

    if (msg['janus'] == 'event' && msg['sender'] == _handleId) {
      final pluginData = msg['plugindata']?['data'];
      if (pluginData is Map<String, dynamic>) {
        final result = pluginData['result'];
        if (result is Map<String, dynamic> && result['status'] != null) {
          status.value = _displayStatus(result['status'].toString());
        } else if (pluginData['error'] != null) {
          status.value = '流错误: ${pluginData['error']}';
        }
      }
      final jsep = msg['jsep'];
      if (jsep is Map<String, dynamic>) {
        unawaited(_acceptOffer(jsep));
      }
    } else if (msg['janus'] == 'trickle' && msg['sender'] == _handleId) {
      final candidate = msg['candidate'];
      if (candidate is Map<String, dynamic>) {
        unawaited(_addRemoteCandidate(candidate));
      }
    } else if (msg['janus'] == 'webrtcup') {
      status.value = '播放中';
    } else if (msg['janus'] == 'hangup') {
      status.value = '流已结束';
    }
  }

  String _displayStatus(String raw) {
    switch (raw) {
      case 'starting':
        return '正在启动...';
      case 'started':
        return '视频流已启动';
      case 'stopped':
        return '已停止';
      default:
        return raw;
    }
  }

  Future<void> _acceptOffer(Map<String, dynamic> jsep) async {
    await _pc?.close();
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) {
        _send({
          'janus': 'trickle',
          'session_id': _sessionId,
          'handle_id': _handleId,
          'candidate': {'completed': true},
          'transaction': _transactionId(),
        });
        return;
      }
      _send({
        'janus': 'trickle',
        'session_id': _sessionId,
        'handle_id': _handleId,
        'candidate': _candidateToJson(candidate),
        'transaction': _transactionId(),
      });
    };
    pc.onTrack = (event) {
      if (event.track.kind != 'video') return;
      unawaited(_setRemoteTrack(event));
    };
    pc.onAddStream = (stream) {
      renderer?.srcObject = stream;
      status.value = '播放中';
    };

    await pc.setRemoteDescription(
      RTCSessionDescription(jsep['sdp'] as String, jsep['type'] as String),
    );
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();
    final answer = await pc.createAnswer({
      'offerToReceiveAudio': false,
      'offerToReceiveVideo': true,
    });
    await pc.setLocalDescription(answer);
    await _sendPluginMessage(
      {'request': 'start'},
      jsep: {'type': answer.type, 'sdp': answer.sdp},
    );
  }

  Future<void> _setRemoteTrack(RTCTrackEvent event) async {
    if (event.streams.isNotEmpty) {
      renderer?.srcObject = event.streams.first;
    } else {
      final stream = await createLocalMediaStream('janus-remote-$streamId');
      await stream.addTrack(event.track);
      renderer?.srcObject = stream;
    }
    status.value = '播放中';
  }

  Map<String, dynamic> _candidateToJson(RTCIceCandidate candidate) {
    return {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };
  }

  Future<void> _addRemoteCandidate(Map<String, dynamic> candidate) async {
    final pc = _pc;
    if (candidate['completed'] == true) {
      return;
    }
    if (!_remoteDescriptionSet || pc == null) {
      _pendingCandidates.add(candidate);
      return;
    }
    await pc.addCandidate(
      RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ),
    );
  }

  Future<void> _flushPendingCandidates() async {
    if (_pendingCandidates.isEmpty) return;
    final candidates = List<Map<String, dynamic>>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final candidate in candidates) {
      await _addRemoteCandidate(candidate);
    }
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> payload) {
    final transaction = _transactionId();
    final completer = Completer<Map<String, dynamic>>();
    _transactions[transaction] = completer;
    _send({...payload, 'transaction': transaction});
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<void> _sendPluginMessage(
    Map<String, dynamic> body, {
    Map<String, dynamic>? jsep,
  }) async {
    final payload = {
      'janus': 'message',
      'session_id': _sessionId,
      'handle_id': _handleId,
      'body': body,
    };
    if (jsep != null) payload['jsep'] = jsep;
    final response = await _request(payload);
    final janus = response['janus'];
    if (janus == 'error') {
      final error = response['error'];
      final reason = error is Map<String, dynamic>
          ? error['reason']?.toString()
          : response.toString();
      throw StateError(reason ?? 'Janus message error');
    }
  }

  void _send(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode(payload));
  }

  String _transactionId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> stop() async {
    try {
      await _sendPluginMessage({'request': 'stop'});
    } catch (_) {}
    renderer?.srcObject = null;
    status.value = '已停止';
  }

  Future<void> disconnect() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    try {
      if (_handleId != null) {
        _send({
          'janus': 'detach',
          'session_id': _sessionId,
          'handle_id': _handleId,
        });
      }
      if (_sessionId != null) {
        _send({'janus': 'destroy', 'session_id': _sessionId});
      }
    } catch (_) {}
    await _pc?.close();
    _pc = null;
    renderer?.srcObject = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _transactions.clear();
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;
    _sessionId = null;
    _handleId = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await renderer?.dispose();
    status.dispose();
    renderer = null;
  }
}
