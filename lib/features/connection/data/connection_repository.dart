import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/connection_model.dart';

const _kConnectionsKey = 'robot_connections';
const _kActiveIdKey = 'active_connection_id';
const _kApiTokenPrefix = 'api_token_';
const _kTerminalTokenPrefix = 'terminal_token_';
const _kAPPasswordPrefix = 'ap_password_';

class ConnectionRepository {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  ConnectionRepository({
    required SharedPreferences prefs,
    required FlutterSecureStorage secure,
  }) : _prefs = prefs,
       _secure = secure;

  List<RobotConnection> loadAll() {
    final raw = _prefs.getString(_kConnectionsKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      // Handle double-encoded strings (legacy bad writes)
      final list = decoded is String
          ? jsonDecode(decoded) as List<dynamic>
          : decoded as List<dynamic>;
      return list.map((e) {
        final map = e is String
            ? jsonDecode(e) as Map<String, dynamic>
            : e as Map<String, dynamic>;
        return RobotConnection.fromJson(map);
      }).toList();
    } catch (_) {
      // Corrupted data — reset
      _prefs.remove(_kConnectionsKey);
      return [];
    }
  }

  String? getActiveId() => _prefs.getString(_kActiveIdKey);

  Future<void> save(RobotConnection conn) async {
    final all = loadAll();
    final idx = all.indexWhere((c) => c.id == conn.id);
    if (idx >= 0) {
      all[idx] = conn;
    } else {
      all.add(conn);
    }
    await _prefs.setString(
      _kConnectionsKey,
      jsonEncode(all.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> setActive(String id) async {
    await _prefs.setString(_kActiveIdKey, id);
  }

  Future<void> clearActive() async {
    await _prefs.remove(_kActiveIdKey);
  }

  Future<void> delete(String id) async {
    final all = loadAll()..removeWhere((c) => c.id == id);
    await _prefs.setString(
      _kConnectionsKey,
      jsonEncode(all.map((c) => c.toJson()).toList()),
    );
    await _secure.delete(key: '$_kApiTokenPrefix$id');
    await _secure.delete(key: '$_kTerminalTokenPrefix$id');
    await _secure.delete(key: '$_kAPPasswordPrefix$id');
    if (getActiveId() == id) {
      await _prefs.remove(_kActiveIdKey);
    }
  }

  Future<String?> getApiToken(String id) =>
      _secure.read(key: '$_kApiTokenPrefix$id');

  Future<String?> getTerminalToken(String id) =>
      _secure.read(key: '$_kTerminalTokenPrefix$id');

  Future<String?> getAPPassword(String id) =>
      _secure.read(key: '$_kAPPasswordPrefix$id');

  Future<void> saveApiToken(String id, String token) {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return _secure.delete(key: '$_kApiTokenPrefix$id');
    }
    return _secure.write(key: '$_kApiTokenPrefix$id', value: normalized);
  }

  Future<void> saveTerminalToken(String id, String token) =>
      _secure.write(key: '$_kTerminalTokenPrefix$id', value: token);

  Future<void> saveAPPassword(String id, String password) {
    if (password.isEmpty) {
      return _secure.delete(key: '$_kAPPasswordPrefix$id');
    }
    return _secure.write(key: '$_kAPPasswordPrefix$id', value: password);
  }

  Future<void> deleteAPPassword(String id) =>
      _secure.delete(key: '$_kAPPasswordPrefix$id');
}
