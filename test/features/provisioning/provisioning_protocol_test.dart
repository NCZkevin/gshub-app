import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/features/provisioning/data/provisioning_protocol.dart';
import 'package:sysapp/features/provisioning/domain/provisioning_models.dart';

void main() {
  test('fragments and reassembles a provisioning envelope', () {
    final envelope = ProvisioningEnvelope(
      version: provisioningProtocolVersion,
      requestId: 'request-1',
      type: 'wifi.connect',
      payload: {
        'ssid': 'Lab WiFi',
        'password': 'a long password with spaces',
        'hidden': false,
        'security': 'wpa2-personal',
      },
    );
    final frames = encodeProvisioningFrames(
      encodeProvisioningEnvelope(envelope),
      messageId: 42,
      maxFrameSize: 24,
    );
    expect(frames.length, greaterThan(1));

    final reassembler = ProvisioningFrameReassembler();
    List<int>? payload;
    for (final frame in frames.reversed) {
      payload = reassembler.add(frame) ?? payload;
    }

    expect(payload, isNotNull);
    final decoded = decodeProvisioningEnvelope(payload!);
    expect(decoded.requestId, 'request-1');
    expect(decoded.type, 'wifi.connect');
    expect((decoded.payload! as Map<String, dynamic>)['ssid'], 'Lab WiFi');
  });

  test('rejects frames from a different protocol version', () {
    final frame = encodeProvisioningFrames([1, 2, 3], messageId: 1).single;
    frame[2] = 9;
    expect(
      () => ProvisioningFrame.decode(frame),
      throwsA(isA<FormatException>()),
    );
  });
}
