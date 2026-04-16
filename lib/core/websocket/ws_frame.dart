import 'dart:typed_data';

/// 终端 WebSocket 二进制帧协议
enum WsFrameType {
  input(0x00),
  resize(0x01),
  output(0x02),
  error(0x03);

  final int byte;
  const WsFrameType(this.byte);

  static WsFrameType fromByte(int b) =>
      WsFrameType.values.firstWhere((e) => e.byte == b,
          orElse: () => WsFrameType.error);
}

class WsFrame {
  final WsFrameType type;
  final Uint8List data;

  const WsFrame({required this.type, required this.data});

  /// 序列化为二进制帧（type byte + data）
  Uint8List toBytes() {
    final out = Uint8List(1 + data.length);
    out[0] = type.byte;
    out.setRange(1, out.length, data);
    return out;
  }

  /// 从二进制帧解析
  factory WsFrame.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return WsFrame(type: WsFrameType.error, data: Uint8List(0));
    return WsFrame(
      type: WsFrameType.fromByte(bytes[0]),
      data: bytes.sublist(1),
    );
  }

  /// 构建 resize 帧（cols: 2 bytes BE, rows: 2 bytes BE）
  factory WsFrame.resize(int cols, int rows) {
    final data = Uint8List(4);
    data[0] = (cols >> 8) & 0xFF;
    data[1] = cols & 0xFF;
    data[2] = (rows >> 8) & 0xFF;
    data[3] = rows & 0xFF;
    return WsFrame(type: WsFrameType.resize, data: data);
  }
}
