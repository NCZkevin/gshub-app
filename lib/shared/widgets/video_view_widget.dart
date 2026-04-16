import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Janus WebRTC 视频视图占位
/// 完整的 Janus 信令接入在 video_view_controller.dart 实现
/// 此 Widget 只负责渲染 RTCVideoRenderer
class VideoViewWidget extends StatefulWidget {
  final RTCVideoRenderer? renderer;
  final String? placeholderText;

  const VideoViewWidget({
    super.key,
    this.renderer,
    this.placeholderText,
  });

  @override
  State<VideoViewWidget> createState() => _VideoViewWidgetState();
}

class _VideoViewWidgetState extends State<VideoViewWidget> {
  @override
  Widget build(BuildContext context) {
    final renderer = widget.renderer;
    if (renderer == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                widget.placeholderText ?? '视频流未连接',
                style: const TextStyle(color: Colors.grey),
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

/// Janus WebRTC 信令控制器
/// 封装与 Janus Gateway 的 HTTP JSON RPC 通信
class JanusVideoController {
  RTCVideoRenderer? renderer;
  RTCPeerConnection? _pc;

  Future<void> initialize() async {
    renderer = RTCVideoRenderer();
    await renderer!.initialize();
  }

  /// 连接 Janus 视频流
  /// [janusUrl]: Janus HTTP endpoint, e.g. http://host:8088/janus
  Future<void> connect(String janusUrl, {int roomId = 1234}) async {
    // TODO: 实现 Janus 信令流程
    // 1. POST /janus — 创建 session
    // 2. POST /janus/{sessionId} — 附加 videoroom 插件
    // 3. POST /janus/{sessionId}/{handleId} — join 房间
    // 4. 获取 SDP offer，创建 RTCPeerConnection，生成 SDP answer
    // 5. POST answer 到 Janus
    // 6. 开始接收视频帧
  }

  Future<void> dispose() async {
    await _pc?.close();
    await renderer?.dispose();
    renderer = null;
    _pc = null;
  }
}
