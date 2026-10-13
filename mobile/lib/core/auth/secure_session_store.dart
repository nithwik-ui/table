import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStore {
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'sru_auth_session';

  static Future<void> saveSession(Map<String, dynamic> sessionData, {String? role}) async {
    final jsonString = json.encode(sessionData);
    final targetRole = role ?? sessionData['role']?.toString() ?? 'student';
    await _storage.write(key: '${_sessionKey}_$targetRole', value: jsonString);
    await _storage.write(key: _sessionKey, value: jsonString);
  }

  static Future<Map<String, dynamic>?> getSession({String? role}) async {
    if (role != null && role.isNotEmpty) {
      final roleSession = await _storage.read(key: '${_sessionKey}_$role');
      if (roleSession != null && roleSession.isNotEmpty) {
        try {
          return json.decode(roleSession) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    final jsonString = await _storage.read(key: _sessionKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        return json.decode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> clearSession({String? role}) async {
    if (role != null) {
      await _storage.delete(key: '${_sessionKey}_$role');
    } else {
      await _storage.delete(key: '${_sessionKey}_student');
      await _storage.delete(key: '${_sessionKey}_faculty');
      await _storage.delete(key: _sessionKey);
    }
  }
}
