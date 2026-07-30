class ProvisioningDevice {
  final String id;
  final String name;
  final int rssi;

  const ProvisioningDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

class ProvisioningDeviceInfo {
  final String sn;
  final String model;
  final String softwareVersion;
  final int apiPort;
  final Set<String> capabilities;

  const ProvisioningDeviceInfo({
    required this.sn,
    required this.model,
    required this.softwareVersion,
    required this.apiPort,
    required this.capabilities,
  });

  bool get supportsAP => capabilities.contains('wifi_ap');

  factory ProvisioningDeviceInfo.fromJson(Map<String, dynamic> json) {
    final sn = json['sn']?.toString().trim() ?? '';
    if (sn.isEmpty) {
      throw const FormatException('设备信息中缺少序列号');
    }
    return ProvisioningDeviceInfo(
      sn: sn,
      model: json['model']?.toString() ?? '',
      softwareVersion: json['software_version']?.toString() ?? '',
      apiPort: (json['api_port'] as num?)?.toInt() ?? 8898,
      capabilities:
          (json['capabilities'] as List?)
              ?.map((item) => item.toString())
              .toSet() ??
          const {'wifi_client'},
    );
  }
}

class ProvisioningStatus {
  final String mode;
  final bool connected;
  final String ssid;
  final String ip;
  final bool canRestore;
  final String previousSSID;

  const ProvisioningStatus({
    required this.mode,
    required this.connected,
    required this.ssid,
    required this.ip,
    required this.canRestore,
    required this.previousSSID,
  });

  bool get apActive => mode == 'ap' && connected;

  factory ProvisioningStatus.fromJson(Map<String, dynamic> json) {
    final wifi = json['wifi'] is Map<String, dynamic>
        ? json['wifi'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ProvisioningStatus(
      mode: wifi['mode']?.toString() ?? 'disconnected',
      connected: wifi['connected'] == true,
      ssid: wifi['ssid']?.toString() ?? '',
      ip: wifi['ip']?.toString() ?? '',
      canRestore: wifi['can_restore'] == true,
      previousSSID: wifi['previous_ssid']?.toString() ?? '',
    );
  }
}

class ProvisioningAPResult {
  final String ssid;
  final String password;
  final String ip;
  final int apiPort;
  final int prefixLength;
  final String band;
  final int channel;
  final bool canRestore;
  final String previousSSID;

  const ProvisioningAPResult({
    required this.ssid,
    required this.password,
    required this.ip,
    required this.apiPort,
    required this.prefixLength,
    required this.band,
    required this.channel,
    required this.canRestore,
    required this.previousSSID,
  });

  factory ProvisioningAPResult.fromJson(Map<String, dynamic> json) {
    final ssid = json['ssid']?.toString() ?? '';
    final password = json['password']?.toString() ?? '';
    final ip = json['ip']?.toString() ?? '';
    if (ssid.isEmpty || password.isEmpty || ip.isEmpty) {
      throw const FormatException('热点响应缺少 SSID、密码或 IP');
    }
    return ProvisioningAPResult(
      ssid: ssid,
      password: password,
      ip: ip,
      apiPort: (json['api_port'] as num?)?.toInt() ?? 8898,
      prefixLength: (json['prefix_length'] as num?)?.toInt() ?? 24,
      band: json['band']?.toString() ?? '2.4ghz',
      channel: (json['channel'] as num?)?.toInt() ?? 6,
      canRestore: json['can_restore'] == true,
      previousSSID: json['previous_ssid']?.toString() ?? '',
    );
  }
}

enum ProvisioningWiFiSecurity {
  open('open'),
  wpa2Personal('wpa2-personal'),
  wpa3Personal('wpa3-personal');

  final String wireValue;
  const ProvisioningWiFiSecurity(this.wireValue);

  factory ProvisioningWiFiSecurity.fromWire(String value) {
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => wpa2Personal,
    );
  }
}

class ProvisioningWiFiNetwork {
  final String ssid;
  final String? bssid;
  final int strength;
  final int frequencyMHz;
  final ProvisioningWiFiSecurity security;
  final bool saved;

  const ProvisioningWiFiNetwork({
    required this.ssid,
    required this.strength,
    required this.frequencyMHz,
    required this.security,
    required this.saved,
    this.bssid,
  });

  factory ProvisioningWiFiNetwork.fromJson(Map<String, dynamic> json) {
    return ProvisioningWiFiNetwork(
      ssid: json['ssid']?.toString() ?? '',
      bssid: json['bssid']?.toString(),
      strength: (json['strength'] as num?)?.toInt() ?? 0,
      frequencyMHz: (json['frequency_mhz'] as num?)?.toInt() ?? 0,
      security: ProvisioningWiFiSecurity.fromWire(
        json['security']?.toString() ?? '',
      ),
      saved: json['saved'] == true,
    );
  }
}

class ProvisioningEnvelope {
  final int version;
  final String requestId;
  final String type;
  final String status;
  final Object? payload;
  final ProvisioningProtocolError? error;

  const ProvisioningEnvelope({
    required this.version,
    required this.type,
    this.requestId = '',
    this.status = '',
    this.payload,
    this.error,
  });

  factory ProvisioningEnvelope.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 0;
    final type = json['type']?.toString() ?? '';
    if (version != 1) {
      throw FormatException('不支持的配网协议版本：$version');
    }
    if (type.isEmpty) {
      throw const FormatException('配网消息缺少类型');
    }
    return ProvisioningEnvelope(
      version: version,
      requestId: json['request_id']?.toString() ?? '',
      type: type,
      status: json['status']?.toString() ?? '',
      payload: json['payload'],
      error: json['error'] is Map<String, dynamic>
          ? ProvisioningProtocolError.fromJson(
              json['error'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    if (requestId.isNotEmpty) 'request_id': requestId,
    'type': type,
    if (status.isNotEmpty) 'status': status,
    if (payload != null) 'payload': payload,
    if (error != null) 'error': error!.toJson(),
  };
}

class ProvisioningProtocolError {
  final String code;
  final String message;
  final bool retryable;

  const ProvisioningProtocolError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory ProvisioningProtocolError.fromJson(Map<String, dynamic> json) {
    return ProvisioningProtocolError(
      code: json['code']?.toString() ?? 'INTERNAL_ERROR',
      message: json['message']?.toString() ?? '配网失败',
      retryable: json['retryable'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'retryable': retryable,
  };
}

class ProvisioningException implements Exception {
  final String code;
  final String message;
  final bool retryable;

  const ProvisioningException({
    required this.code,
    required this.message,
    this.retryable = true,
  });

  factory ProvisioningException.fromProtocol(ProvisioningProtocolError error) {
    return ProvisioningException(
      code: error.code,
      message: error.message,
      retryable: error.retryable,
    );
  }

  @override
  String toString() => message;
}
