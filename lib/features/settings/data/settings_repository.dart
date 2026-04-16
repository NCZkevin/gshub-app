import '../../../core/api/dio_client.dart';

class SettingsRepository {
  SettingsRepository();

  /// Verifies the given token against baseUrl.
  /// Returns the username on success, throws on failure.
  Future<String> verifyToken(String baseUrl, String token) async {
    final client = DioClient.create(baseUrl: baseUrl, authToken: token);
    // Call an authenticated endpoint to verify token validity.
    // We use /system/hub as a lightweight probe.
    final data = await client.get('/system/hub') as Map<String, dynamic>?;
    final username = data?['hostname'] as String? ?? 'authenticated';
    return username;
  }
}
