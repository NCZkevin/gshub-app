import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_error.dart';

class DioClient {
  final Dio _dio;

  DioClient._({required Dio dio}) : _dio = dio;

  factory DioClient.create({
    required String baseUrl,
    String? authToken,
    void Function()? onUnauthorized,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: '$baseUrl/v1/api',
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        responseType: ResponseType.json,
        contentType: 'application/json',
      ),
    );
    dio.interceptors.add(
      _AuthInterceptor(authToken: authToken, onUnauthorized: onUnauthorized),
    );
    dio.interceptors.add(_EnvelopeInterceptor());
    return DioClient._(dio: dio);
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
    );
    return response.data;
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final response = await _dio.post<dynamic>(path, data: data);
    return response.data;
  }

  Future<dynamic> delete(String path) async {
    final response = await _dio.delete<dynamic>(path);
    return response.data;
  }

  Future<dynamic> put(String path, {dynamic data, Options? options}) async {
    final response = await _dio.put<dynamic>(
      path,
      data: data,
      options: options,
    );
    return response.data;
  }

  /// 二进制下载（PGM、ZIP 等）
  Future<List<int>> getBytes(String path) async {
    final response = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  void close({bool force = true}) => _dio.close(force: force);
}

class _AuthInterceptor extends Interceptor {
  final String? authToken;
  final void Function()? onUnauthorized;

  _AuthInterceptor({this.authToken, this.onUnauthorized});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = authToken?.trim() ?? '';
    if (token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}

class _EnvelopeInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = _decodeJson(response.data);

    if (data is Map<String, dynamic> && data.containsKey('code')) {
      final code = data['code'] as int? ?? 0;
      if (code != 0) {
        final apiError = ApiException(
          code: code,
          message: data['msg'] as String? ?? 'API error',
        );
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: apiError,
            message: apiError.message,
          ),
        );
        return;
      }
      response.data = data['data'];
    } else {
      response.data = data;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final data = _decodeJson(err.response?.data);
    if (data is Map<String, dynamic>) {
      final code = data['code'];
      if (code is int && code != 0) {
        final apiError = ApiException(
          code: code,
          message: data['msg'] as String? ?? 'API error',
        );
        handler.next(err.copyWith(error: apiError, message: apiError.message));
        return;
      }
    }
    handler.next(err);
  }
}

dynamic _decodeJson(dynamic data) {
  if (data is! String || data.isEmpty) return data;
  try {
    return jsonDecode(data);
  } catch (_) {
    return data;
  }
}
