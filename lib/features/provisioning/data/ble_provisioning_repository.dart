import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/provisioning_models.dart';
import 'provisioning_protocol.dart';

final flutterReactiveBleProvider = Provider<FlutterReactiveBle>(
  (ref) => FlutterReactiveBle(),
);

final bleProvisioningRepositoryProvider = Provider<BleProvisioningRepository>(
  (ref) => BleProvisioningRepository(ref.watch(flutterReactiveBleProvider)),
);

class BleProvisioningRepository {
  static final serviceUuid = Uuid.parse('8f621000-bc55-4a5f-8b21-15d70e22b001');
  static final deviceInfoUuid = Uuid.parse(
    '8f621001-bc55-4a5f-8b21-15d70e22b001',
  );
  static final commandUuid = Uuid.parse('8f621002-bc55-4a5f-8b21-15d70e22b001');
  static final eventUuid = Uuid.parse('8f621003-bc55-4a5f-8b21-15d70e22b001');

  static const _permissionChannel = MethodChannel(
    'com.gshub.sysapp/bluetooth_permissions',
  );

  final FlutterReactiveBle _ble;
  BleProvisioningRepository(this._ble);

  Future<List<ProvisioningDevice>> scan({
    Duration duration = const Duration(seconds: 15),
  }) async {
    await _ensureReady();
    final devices = <String, ProvisioningDevice>{};
    final error = Completer<Object>();
    final subscription = _ble
        .scanForDevices(
          withServices: [serviceUuid],
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          (device) {
            devices[device.id] = ProvisioningDevice(
              id: device.id,
              name: device.name.isEmpty ? 'GSHUB' : device.name,
              rssi: device.rssi,
            );
          },
          onError: (Object value, StackTrace stackTrace) {
            if (!error.isCompleted) error.complete(value);
          },
        );
    try {
      await Future.any([
        Future<void>.delayed(duration),
        error.future.then<void>((value) => throw value),
      ]);
    } finally {
      await subscription.cancel();
    }
    final result = devices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return result;
  }

  Future<ProvisioningSession> connect(
    ProvisioningDevice device, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    await _ensureReady();
    final connected = Completer<void>();
    ProvisioningSession? activeSession;
    var disconnectedAfterConnect = false;
    late final StreamSubscription<ConnectionStateUpdate> subscription;
    subscription = _ble
        .connectToDevice(
          id: device.id,
          servicesWithCharacteristicsToDiscover: {
            serviceUuid: [deviceInfoUuid, commandUuid, eventUuid],
          },
          connectionTimeout: timeout,
        )
        .listen(
          (update) {
            switch (update.connectionState) {
              case DeviceConnectionState.connected:
                if (!connected.isCompleted) connected.complete();
              case DeviceConnectionState.disconnected:
                if (!connected.isCompleted) {
                  connected.completeError(
                    const ProvisioningException(
                      code: 'BLUETOOTH_DISCONNECTED',
                      message: '蓝牙连接已断开',
                    ),
                  );
                } else if (activeSession != null) {
                  activeSession.handleDisconnect();
                } else {
                  disconnectedAfterConnect = true;
                }
              default:
                break;
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!connected.isCompleted) {
              connected.completeError(error, stackTrace);
            }
          },
        );
    try {
      await connected.future.timeout(timeout);
      var frameSize = provisioningDefaultFrameSize;
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final mtu = await _ble.requestMtu(deviceId: device.id, mtu: 247);
          frameSize = (mtu - 3).clamp(
            provisioningFrameHeaderSize + 1,
            provisioningDefaultFrameSize,
          );
        } catch (_) {
          // The ATT default MTU allows a 20-byte characteristic value.
          frameSize = 20;
        }
      }
      final session = ProvisioningSession(
        ble: _ble,
        deviceId: device.id,
        connectionSubscription: subscription,
        frameSize: frameSize,
      );
      activeSession = session;
      if (disconnectedAfterConnect) {
        session.handleDisconnect();
      }
      await session.initialize();
      return session;
    } catch (_) {
      await subscription.cancel();
      rethrow;
    }
  }

  Future<void> _ensureReady() async {
    try {
      final granted =
          await _permissionChannel.invokeMethod<bool>('request') ?? true;
      if (!granted) {
        throw const ProvisioningException(
          code: 'BLUETOOTH_PERMISSION_DENIED',
          message: '需要蓝牙权限才能搜索机器人',
          retryable: false,
        );
      }
    } on MissingPluginException {
      // iOS requests CoreBluetooth permission when the BLE client starts.
    }

    if (_ble.status == BleStatus.ready) return;
    final status = await _ble.statusStream
        .firstWhere(
          (value) =>
              value == BleStatus.ready ||
              value == BleStatus.poweredOff ||
              value == BleStatus.unauthorized ||
              value == BleStatus.unsupported,
        )
        .timeout(const Duration(seconds: 5), onTimeout: () => _ble.status);
    switch (status) {
      case BleStatus.ready:
        return;
      case BleStatus.poweredOff:
        throw const ProvisioningException(
          code: 'BLUETOOTH_POWERED_OFF',
          message: '请先打开手机蓝牙',
        );
      case BleStatus.unauthorized:
        throw const ProvisioningException(
          code: 'BLUETOOTH_PERMISSION_DENIED',
          message: '蓝牙权限未授权',
          retryable: false,
        );
      case BleStatus.unsupported:
        throw const ProvisioningException(
          code: 'BLUETOOTH_UNSUPPORTED',
          message: '当前设备不支持低功耗蓝牙',
          retryable: false,
        );
      default:
        throw ProvisioningException(
          code: 'BLUETOOTH_UNAVAILABLE',
          message: '蓝牙暂不可用：$status',
        );
    }
  }
}

class ProvisioningSession {
  final FlutterReactiveBle _ble;
  final String deviceId;
  final StreamSubscription<ConnectionStateUpdate> _connectionSubscription;
  final int _frameSize;
  final _events = StreamController<ProvisioningEnvelope>.broadcast();
  final _reassembler = ProvisioningFrameReassembler();
  StreamSubscription<List<int>>? _eventSubscription;
  var _messageId = 0;
  var _requestId = 0;
  String? _activeRequestId;
  var _closed = false;

  late final QualifiedCharacteristic _deviceInfoCharacteristic;
  late final QualifiedCharacteristic _commandCharacteristic;
  late final QualifiedCharacteristic _eventCharacteristic;
  late final ProvisioningDeviceInfo deviceInfo;

  ProvisioningSession({
    required FlutterReactiveBle ble,
    required this.deviceId,
    required StreamSubscription<ConnectionStateUpdate> connectionSubscription,
    required int frameSize,
  }) : _ble = ble,
       _connectionSubscription = connectionSubscription,
       _frameSize = frameSize {
    _deviceInfoCharacteristic = _characteristic(
      BleProvisioningRepository.deviceInfoUuid,
    );
    _commandCharacteristic = _characteristic(
      BleProvisioningRepository.commandUuid,
    );
    _eventCharacteristic = _characteristic(BleProvisioningRepository.eventUuid);
  }

  Stream<ProvisioningEnvelope> get events => _events.stream;

  Future<void> initialize() async {
    _eventSubscription = _ble
        .subscribeToCharacteristic(_eventCharacteristic)
        .listen(
          _acceptEventFrame,
          onError: (Object error, StackTrace stackTrace) {
            if (!_events.isClosed) _events.addError(error, stackTrace);
          },
        );
    final raw = await _ble.readCharacteristic(_deviceInfoCharacteristic);
    final payload = ProvisioningFrameReassembler().add(raw);
    if (payload == null) {
      throw const FormatException('设备信息帧不完整');
    }
    final envelope = decodeProvisioningEnvelope(payload);
    if (envelope.type != 'device_info.result' ||
        envelope.payload is! Map<String, dynamic>) {
      throw const FormatException('设备信息响应格式不正确');
    }
    deviceInfo = ProvisioningDeviceInfo.fromJson(
      envelope.payload! as Map<String, dynamic>,
    );
  }

  Future<List<ProvisioningWiFiNetwork>> scanWiFi() async {
    final response = await _request(
      type: 'wifi.scan',
      timeout: const Duration(seconds: 20),
    );
    final payload = response.payload;
    if (payload is! Map<String, dynamic> || payload['networks'] is! List) {
      throw const FormatException('Wi-Fi 扫描响应格式不正确');
    }
    return (payload['networks'] as List)
        .whereType<Map<String, dynamic>>()
        .map(ProvisioningWiFiNetwork.fromJson)
        .where((network) => network.ssid.isNotEmpty)
        .toList(growable: false);
  }

  Future<ProvisioningStatus> getStatus() async {
    final response = await _request(
      type: 'status.get',
      responseType: 'status.result',
      timeout: const Duration(seconds: 8),
    );
    if (response.payload is! Map<String, dynamic>) {
      throw const FormatException('配网状态响应格式不正确');
    }
    return ProvisioningStatus.fromJson(
      response.payload! as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> connectWiFi({
    required String ssid,
    required ProvisioningWiFiSecurity security,
    String password = '',
    bool hidden = false,
  }) async {
    final response = await _request(
      type: 'wifi.connect',
      payload: {
        'ssid': ssid,
        'password': password,
        'hidden': hidden,
        'security': security.wireValue,
      },
      timeout: const Duration(seconds: 50),
    );
    if (response.payload is! Map<String, dynamic>) {
      throw const FormatException('Wi-Fi 连接响应格式不正确');
    }
    return response.payload! as Map<String, dynamic>;
  }

  Future<ProvisioningAPResult> startAP() async {
    final response = await _request(
      type: 'wifi.ap.start',
      timeout: const Duration(seconds: 40),
    );
    if (response.payload is! Map<String, dynamic>) {
      throw const FormatException('热点启动响应格式不正确');
    }
    return ProvisioningAPResult.fromJson(
      response.payload! as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> stopAP() async {
    final response = await _request(
      type: 'wifi.ap.stop',
      timeout: const Duration(seconds: 50),
    );
    if (response.payload is! Map<String, dynamic>) {
      throw const FormatException('热点恢复响应格式不正确');
    }
    return response.payload! as Map<String, dynamic>;
  }

  Future<void> cancel() async {
    final requestId = _activeRequestId;
    if (requestId == null) return;
    await _send(
      ProvisioningEnvelope(
        version: provisioningProtocolVersion,
        requestId: requestId,
        type: 'wifi.cancel',
      ),
    );
  }

  Future<ProvisioningEnvelope> _request({
    required String type,
    String? responseType,
    Object? payload,
    required Duration timeout,
  }) async {
    if (_closed) {
      throw const ProvisioningException(
        code: 'BLUETOOTH_DISCONNECTED',
        message: '蓝牙配网会话已关闭',
      );
    }
    final requestId = _nextRequestId();
    _activeRequestId = requestId;
    final response = events
        .firstWhere(
          (event) =>
              event.requestId == requestId &&
              event.type == (responseType ?? '$type.result'),
        )
        .timeout(timeout);
    try {
      await _send(
        ProvisioningEnvelope(
          version: provisioningProtocolVersion,
          requestId: requestId,
          type: type,
          payload: payload,
        ),
      );
      final envelope = await response;
      if (envelope.error != null) {
        throw ProvisioningException.fromProtocol(envelope.error!);
      }
      if (envelope.status != 'succeeded') {
        throw const ProvisioningException(
          code: 'INTERNAL_ERROR',
          message: '配网操作未成功完成',
        );
      }
      return envelope;
    } finally {
      if (_activeRequestId == requestId) _activeRequestId = null;
    }
  }

  Future<void> _send(ProvisioningEnvelope envelope) async {
    final frames = encodeProvisioningFrames(
      encodeProvisioningEnvelope(envelope),
      messageId: _nextMessageId(),
      maxFrameSize: _frameSize,
    );
    for (final frame in frames) {
      await _ble.writeCharacteristicWithResponse(
        _commandCharacteristic,
        value: frame,
      );
    }
  }

  void _acceptEventFrame(List<int> value) {
    try {
      final payload = _reassembler.add(value);
      if (payload != null && !_events.isClosed) {
        _events.add(decodeProvisioningEnvelope(payload));
      }
    } catch (error, stackTrace) {
      if (!_events.isClosed) _events.addError(error, stackTrace);
    }
  }

  void handleDisconnect() {
    if (_closed || _events.isClosed) return;
    _events.addError(
      const ProvisioningException(
        code: 'BLUETOOTH_DISCONNECTED',
        message: '蓝牙连接已断开',
      ),
    );
  }

  QualifiedCharacteristic _characteristic(Uuid characteristicId) {
    return QualifiedCharacteristic(
      serviceId: BleProvisioningRepository.serviceUuid,
      characteristicId: characteristicId,
      deviceId: deviceId,
    );
  }

  int _nextMessageId() {
    _messageId = (_messageId + 1) & 0xffff;
    return _messageId;
  }

  String _nextRequestId() {
    _requestId += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_requestId';
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _eventSubscription?.cancel();
    await _connectionSubscription.cancel();
    await _events.close();
  }
}
