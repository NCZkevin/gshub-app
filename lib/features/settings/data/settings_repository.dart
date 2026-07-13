import '../../../core/api/dio_client.dart';

class SettingsRepository {
  SettingsRepository();

  /// Verifies the given token against baseUrl.
  /// Returns the username on success, throws on failure.
  Future<String> verifyToken(String baseUrl, String token) async {
    final client = DioClient.create(baseUrl: baseUrl);
    final data =
        await client.post('/auth/verify', data: {'token': token.trim()})
            as Map<String, dynamic>?;
    final username = data?['username'] as String? ?? 'authenticated';
    return username;
  }
}
