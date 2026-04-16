import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_error.dart';

class DioClient {
  final Dio _dio;

  DioClient._({required Dio dio}) : _dio = dio;

  factory DioClient.create({
    required String baseUrl,
    required String authToken,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: '$baseUrl/v1/api',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        contentType: 'application/json',
      ),
    );
    dio.interceptors.add(_AuthInterceptor(authToken: authToken));
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

  Future<dynamic> put(String path, {dynamic data}) async {
    final response = await _dio.put<dynamic>(path, data: data);
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
}

class _AuthInterceptor extends Interceptor {
  final String authToken;
  _AuthInterceptor({required this.authToken});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'Bearer $authToken';
    handler.next(options);
  }
}

class _EnvelopeInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    var data = response.data;

    // If Dio didn't auto-parse JSON (missing/wrong Content-Type), do it manually
    if (data is String && data.isNotEmpty) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        // Not JSON — pass through as-is
        handler.next(response);
        return;
      }
    }

    if (data is Map<String, dynamic> && data.containsKey('code')) {
      final code = data['code'] as int? ?? 0;
      if (code != 0) {
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            error: ApiException(
              code: code,
              message: data['msg'] as String? ?? 'API error',
            ),
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
    handler.next(err);
  }
}
