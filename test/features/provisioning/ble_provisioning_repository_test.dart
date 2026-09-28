import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sysapp/features/provisioning/data/ble_provisioning_repository.dart';
import 'package:sysapp/features/provisioning/data/provisioning_protocol.dart';
import 'package:sysapp/features/provisioning/domain/provisioning_models.dart';

class _MockFlutterReactiveBle extends Mock implements FlutterReactiveBle {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      QualifiedCharacteristic(
        serviceId: BleProvisioningRepository.serviceUuid,
        characteristicId: BleProvisioningRepository.deviceInfoUuid,
        deviceId: 'fallback',
      ),
    );
  });

  test('loads device info through MTU-safe event frames', () async {
    final ble = _MockFlutterReactiveBle();
    final notifications = StreamController<List<int>>();
    final connectionUpdates = StreamController<ConnectionStateUpdate>();
    final commandReassembler = ProvisioningFrameReassembler();

    when(
      () => ble.subscribeToCharacteristic(any()),
    ).thenAnswer((_) => notifications.stream);
    when(() => ble.readCharacteristic(any())).thenAnswer((_) async {
      final frame = _legacyDeviceInfoFrame();
      return frame.sublist(0, 22);
    });
    when(
      () => ble.writeCharacteristicWithResponse(
        any(),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final frame = invocation.namedArguments[#value]! as List<int>;
      final payload = commandReassembler.add(frame);
      if (payload == null) return;
      final command = decodeProvisioningEnvelope(payload);
      expect(command.type, 'device_info.get');

      final response = ProvisioningEnvelope(
        version: provisioningProtocolVersion,
        requestId: command.requestId,
        type: 'device_info.result',
        status: 'succeeded',
        payload: _deviceInfoPayload,
      );
      for (final responseFrame in encodeProvisioningFrames(
        encodeProvisioningEnvelope(response),
        messageId: 77,
        maxFrameSize: 20,
      )) {
        notifications.add(responseFrame);
      }
    });

    final session = ProvisioningSession(
      ble: ble,
      deviceId: 'robot-1',
      connectionSubscription: connectionUpdates.stream.listen((_) {}),
      frameSize: 20,
    );
    addTearDown(() async {
      await session.close();
      await notifications.close();
      await connectionUpdates.close();
    });

    await session.initialize();

    expect(session.deviceInfo.sn, 'GS20260006');
    expect(session.deviceInfo.supportsAP, isTrue);
    verifyNever(() => ble.readCharacteristic(any()));
  });

  test('falls back to the legacy characteristic for an old daemon', () async {
    final ble = _MockFlutterReactiveBle();
    final notifications = StreamController<List<int>>();
    final connectionUpdates = StreamController<ConnectionStateUpdate>();
    final commandReassembler = ProvisioningFrameReassembler();

    when(
      () => ble.subscribeToCharacteristic(any()),
    ).thenAnswer((_) => notifications.stream);
    when(
      () => ble.readCharacteristic(any()),
    ).thenAnswer((_) async => _legacyDeviceInfoFrame());
    when(
      () => ble.writeCharacteristicWithResponse(
        any(),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final frame = invocation.namedArguments[#value]! as List<int>;
      final payload = commandReassembler.add(frame);
      if (payload == null) return;
      final command = decodeProvisioningEnvelope(payload);
      final response = ProvisioningEnvelope(
        version: provisioningProtocolVersion,
        requestId: command.requestId,
        type: 'device_info.get.result',
        status: 'failed',
        error: const ProvisioningProtocolError(
          code: 'INVALID_REQUEST',
          message: 'unsupported command type',
          retryable: false,
        ),
      );
      for (final responseFrame in encodeProvisioningFrames(
        encodeProvisioningEnvelope(response),
        messageId: 78,
        maxFrameSize: 20,
      )) {
        notifications.add(responseFrame);
      }
    });

    final session = ProvisioningSession(
      ble: ble,
      deviceId: 'robot-1',
      connectionSubscription: connectionUpdates.stream.listen((_) {}),
      frameSize: 20,
    );
    addTearDown(() async {
      await session.close();
      await notifications.close();
      await connectionUpdates.close();
    });

    await session.initialize();

    expect(session.deviceInfo.sn, 'GS20260006');
    verify(() => ble.readCharacteristic(any())).called(1);
  });
}

const _deviceInfoPayload = <String, dynamic>{
  'sn': 'GS20260006',
  'model': 'robot',
  'software_version': '1.2.3',
  'api_port': 8898,
  'protocol_versions': <int>[1],
  'capabilities': <String>['wifi_client', 'wifi_ap'],
};

List<int> _legacyDeviceInfoFrame() {
  final envelope = ProvisioningEnvelope(
    version: provisioningProtocolVersion,
    type: 'device_info.result',
    status: 'succeeded',
    payload: _deviceInfoPayload,
  );
  return encodeProvisioningFrames(
    encodeProvisioningEnvelope(envelope),
    messageId: 76,
    maxFrameSize: 512,
  ).single;
}
