import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apNetworkServiceProvider = Provider<APNetworkService>(
  (ref) => APNetworkService(),
);

class APNetworkService {
  static const _channel = MethodChannel('com.gshub.sysapp/wifi');

  String? _activeSSID;

  Future<void> join({required String ssid, required String password}) async {
    if (_activeSSID == ssid) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const APNetworkException(
        'UNSUPPORTED_PLATFORM',
        '当前平台不支持自动加入机器人热点',
      );
    }
    try {
      await _channel
          .invokeMethod<bool>('joinAP', {
            'ssid': ssid,
            'password': password,
            'timeout_ms': 30000,
          })
          .timeout(const Duration(seconds: 35));
      _activeSSID = ssid;
    } on PlatformException catch (error) {
      throw APNetworkException(error.code, _platformErrorMessage(error));
    } on TimeoutException {
      throw const APNetworkException('JOIN_TIMEOUT', '加入机器人热点超时');
    }
  }

  Future<void> release({bool forget = false}) async {
    if (_activeSSID == null) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _activeSSID = null;
      return;
    }
    final ssid = _activeSSID;
    try {
      await _channel.invokeMethod<void>('leaveAP', {
        'ssid': ?ssid,
        'forget': forget,
      });
    } on PlatformException {
      // Releasing a stale platform request is best-effort.
    } finally {
      _activeSSID = null;
    }
  }

  Future<void> openWiFiSettings() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _channel.invokeMethod<void>('openWiFiSettings');
  }

  String _platformErrorMessage(PlatformException error) {
    return switch (error.code) {
      'WIFI_NETWORK_PERMISSION_MISSING' => 'App 缺少 Android 网络连接权限，请安装更新后的 App。',
      'WIFI_PERMISSION_DENIED' => '未授予附近 Wi-Fi 权限，无法自动连接机器人热点。',
      'WIFI_JOIN_UNAVAILABLE' => '没有找到机器人热点，请确认热点仍处于开启状态。',
      'WIFI_JOIN_TIMEOUT' => '加入机器人热点超时，请靠近机器人后重试。',
      _ => error.message ?? '无法自动加入机器人热点',
    };
  }
}

class APNetworkException implements Exception {
  final String code;
  final String message;

  const APNetworkException(this.code, this.message);

  @override
  String toString() => message;
}
