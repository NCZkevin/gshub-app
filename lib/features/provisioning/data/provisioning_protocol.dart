import 'dart:convert';
import 'dart:typed_data';

import '../domain/provisioning_models.dart';

const provisioningProtocolVersion = 1;
const provisioningFrameHeaderSize = 9;
const provisioningDefaultFrameSize = 180;

List<Uint8List> encodeProvisioningFrames(
  List<int> payload, {
  required int messageId,
  int maxFrameSize = provisioningDefaultFrameSize,
}) {
  if (maxFrameSize <= provisioningFrameHeaderSize) {
    throw ArgumentError('配网帧长度过小');
  }
  final chunkSize = maxFrameSize - provisioningFrameHeaderSize;
  final total = payload.isEmpty ? 1 : (payload.length / chunkSize).ceil();
  if (total > 0xffff) {
    throw ArgumentError('配网消息过长');
  }
  return List.generate(total, (index) {
    final start = index * chunkSize;
    final end = (start + chunkSize).clamp(0, payload.length);
    final frame = Uint8List(provisioningFrameHeaderSize + end - start);
    final bytes = ByteData.sublistView(frame);
    frame[0] = 0x47; // G
    frame[1] = 0x50; // P
    frame[2] = provisioningProtocolVersion;
    bytes.setUint16(3, messageId & 0xffff, Endian.big);
    bytes.setUint16(5, index, Endian.big);
    bytes.setUint16(7, total, Endian.big);
    if (end > start) {
      frame.setRange(provisioningFrameHeaderSize, frame.length, payload, start);
    }
    return frame;
  });
}

class ProvisioningFrame {
  final int messageId;
  final int index;
  final int total;
  final Uint8List payload;

  const ProvisioningFrame({
    required this.messageId,
    required this.index,
    required this.total,
    required this.payload,
  });

  factory ProvisioningFrame.decode(List<int> value) {
    if (value.length < provisioningFrameHeaderSize) {
      throw const FormatException('配网帧头不完整');
    }
    final frame = Uint8List.fromList(value);
    if (frame[0] != 0x47 || frame[1] != 0x50) {
      throw const FormatException('配网帧标识无效');
    }
    if (frame[2] != provisioningProtocolVersion) {
      throw FormatException('不支持的配网帧版本：${frame[2]}');
    }
    final bytes = ByteData.sublistView(frame);
    final index = bytes.getUint16(5, Endian.big);
    final total = bytes.getUint16(7, Endian.big);
    if (total == 0 || index >= total) {
      throw const FormatException('配网帧序号无效');
    }
    return ProvisioningFrame(
      messageId: bytes.getUint16(3, Endian.big),
      index: index,
      total: total,
      payload: Uint8List.sublistView(frame, provisioningFrameHeaderSize),
    );
  }
}

class ProvisioningFrameReassembler {
  final Map<int, _PartialMessage> _messages = {};

  Uint8List? add(List<int> value) {
    final frame = ProvisioningFrame.decode(value);
    final partial = _messages.update(
      frame.messageId,
      (current) =>
          current.total == frame.total ? current : _PartialMessage(frame.total),
      ifAbsent: () => _PartialMessage(frame.total),
    );
    partial.chunks[frame.index] = frame.payload;
    if (partial.chunks.length != partial.total) return null;

    final builder = BytesBuilder(copy: false);
    for (var index = 0; index < partial.total; index++) {
      final chunk = partial.chunks[index];
      if (chunk == null) return null;
      builder.add(chunk);
    }
    _messages.remove(frame.messageId);
    return builder.takeBytes();
  }
}

class _PartialMessage {
  final int total;
  final Map<int, Uint8List> chunks = {};
  _PartialMessage(this.total);
}

Uint8List encodeProvisioningEnvelope(ProvisioningEnvelope envelope) {
  return Uint8List.fromList(utf8.encode(jsonEncode(envelope.toJson())));
}

ProvisioningEnvelope decodeProvisioningEnvelope(List<int> payload) {
  final value = jsonDecode(utf8.decode(payload));
  if (value is! Map<String, dynamic>) {
    throw const FormatException('配网消息不是 JSON 对象');
  }
  return ProvisioningEnvelope.fromJson(value);
}
