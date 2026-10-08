import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStore {
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'sru_auth_session';

  static Future<void> saveSession(Map<String, dynamic> sessionData) async {
    final jsonString = json.encode(sessionData);
    await _storage.write(key: _sessionKey, value: jsonString);
  }

  static Future<Map<String, dynamic>?> getSession() async {
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

  static Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }
}
