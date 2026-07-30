import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../domain/connection_model.dart';
import 'ap_network_service.dart';

final machineConnectionProbeProvider = Provider<MachineConnectionProbe>(
  (ref) => const HttpMachineConnectionProbe(),
);

enum MachineConnectionFailureKind {
  timeout,
  unreachable,
  serviceUnavailable,
  authorizationRequired,
  identityMismatch,
  apNetwork,
  invalidResponse,
  unknown,
}

class MachineConnectionException implements Exception {
  final MachineConnectionFailureKind kind;
  final String message;
  final Object? cause;

  const MachineConnectionException(this.kind, this.message, {this.cause});

  @override
  String toString() => message;
}

class MachineProbeResult {
  final String sn;
  final String? model;
  final String? version;

  const MachineProbeResult({required this.sn, this.model, this.version});
}

abstract interface class MachineConnectionProbe {
  Future<MachineProbeResult> probe(RobotConnection connection);
}

class HttpMachineConnectionProbe implements MachineConnectionProbe {
  final Duration timeout;

  const HttpMachineConnectionProbe({this.timeout = const Duration(seconds: 3)});

  @override
  Future<MachineProbeResult> probe(RobotConnection connection) async {
    final client = DioClient.create(
      baseUrl: connection.baseUrl,
      connectTimeout: timeout,
      receiveTimeout: timeout,
    );
    try {
      final data = await client.get('/systems/device');
      if (data is! Map<String, dynamic>) {
        throw const MachineConnectionException(
          MachineConnectionFailureKind.invalidResponse,
          '机器控制服务返回了无法识别的数据',
        );
      }
      final sn = (data['sn'] ?? data['SN'])?.toString().trim() ?? '';
      if (sn.isEmpty) {
        throw const MachineConnectionException(
          MachineConnectionFailureKind.invalidResponse,
          '机器控制服务未返回设备序列号',
        );
      }
      if (!_isLegacyUuid(connection.id) && sn != connection.id) {
        throw MachineConnectionException(
          MachineConnectionFailureKind.identityMismatch,
          '该地址属于另一台机器（$sn），已取消切换',
        );
      }
      return MachineProbeResult(
        sn: sn,
        model: data['model']?.toString(),
        version: data['version']?.toString(),
      );
    } on MachineConnectionException {
      rethrow;
    } on DioException catch (error) {
      throw normalizeMachineConnectionError(error);
    } catch (error) {
      throw normalizeMachineConnectionError(error);
    } finally {
      client.close();
    }
  }
}

MachineConnectionException normalizeMachineConnectionError(Object error) {
  if (error is MachineConnectionException) return error;
  if (error is APNetworkException) {
    return MachineConnectionException(
      MachineConnectionFailureKind.apNetwork,
      error.message,
      cause: error,
    );
  }
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return MachineConnectionException(
        MachineConnectionFailureKind.authorizationRequired,
        '机器在线，但需要填写或更新 API Token',
        cause: error,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return MachineConnectionException(
        MachineConnectionFailureKind.serviceUnavailable,
        '机器在线，但控制服务暂时不可用',
        cause: error,
      );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return MachineConnectionException(
          MachineConnectionFailureKind.timeout,
          '连接机器超时，请确认机器已开机并连接到当前网络',
          cause: error,
        );
      case DioExceptionType.connectionError:
        final refused = _isConnectionRefused(error.error);
        return MachineConnectionException(
          refused
              ? MachineConnectionFailureKind.serviceUnavailable
              : MachineConnectionFailureKind.unreachable,
          refused ? '机器地址可达，但控制服务未启动' : '机器未开机，或不在当前网络',
          cause: error,
        );
      case DioExceptionType.badCertificate:
        return MachineConnectionException(
          MachineConnectionFailureKind.serviceUnavailable,
          '无法验证机器控制服务的安全证书',
          cause: error,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        break;
    }
  }
  return MachineConnectionException(
    MachineConnectionFailureKind.unknown,
    '无法连接机器，请稍后重试',
    cause: error,
  );
}

bool _isConnectionRefused(Object? error) {
  final text = error.toString().toLowerCase();
  if (text.contains('connection refused')) return true;
  if (error is SocketException) {
    return const {61, 111, 10061}.contains(error.osError?.errorCode);
  }
  return false;
}

bool _isLegacyUuid(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
).hasMatch(value);
