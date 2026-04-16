class ApiException implements Exception {
  final int code;
  final String message;

  const ApiException({required this.code, required this.message});

  @override
  String toString() => 'ApiException($code): $message';
}
