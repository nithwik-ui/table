import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage.dart';

/// Manages the low-level HTTP session for SRAAP.
/// Holds the PHPSESSID cookie and ensures all requests use the same context.
class SraapSessionManager {
  static final SraapSessionManager instance = SraapSessionManager._();
  SraapSessionManager._();

  String _cookieHeader = '';
  final Map<String, String> _cookies = {};
  http.Client _client = http.Client();
  
  /// Contains diagnostic info for the developer prototype UI.
  String lastDebugLog = '';

  /// Gets the current session cookies.
  String get cookieHeader => _cookieHeader;

  /// Restores a previously saved session.
  Future<void> restoreSession() async {
    final state = await StorageService.loadSessionState();
    if (state != null && state['cookie'] != null) {
      _cookieHeader = state['cookie'];
      final parts = _cookieHeader.split(';');
      for (var p in parts) {
        final kv = p.trim().split('=');
        if (kv.length >= 2) {
          _cookies[kv[0]] = kv.sublist(1).join('=');
        }
      }
    }
  }

  /// Hits the login page to initialize a new PHP session.
  Future<bool> fetchLoginPage() async {
    try {
      final res = await _client.get(
        Uri.parse('https://sraap.in/student_login.php'),
        headers: _headers(),
      );
      _updateCookies(res.headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches a fresh CAPTCHA image using the existing session.
  Future<Uint8List?> fetchCaptcha() async {
    lastDebugLog = '--- CAPTCHA FETCH LOG ---\n';
    try {
      if (_cookieHeader.isEmpty) {
        lastDebugLog += '1. No session cookie. Initializing via /student_login.php\n';
        final initRes = await _client.get(
          Uri.parse('https://sraap.in/student_login.php'),
          headers: _headers(),
        ).timeout(const Duration(seconds: 15));
        lastDebugLog += '   -> Status: ${initRes.statusCode}\n';
        _updateCookies(initRes.headers);
        lastDebugLog += '   -> Cookie captured: ${_cookieHeader.isNotEmpty}\n';
      }

      lastDebugLog += '2. Requesting /captcha/image.php\n';
      final res = await _client.get(
        Uri.parse('https://sraap.in/captcha/image.php?${DateTime.now().millisecondsSinceEpoch}'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 15));
      
      lastDebugLog += '   -> Status: ${res.statusCode}\n';
      lastDebugLog += '   -> Bytes: ${res.bodyBytes.length}\n';
      lastDebugLog += '   -> Content-Type: ${res.headers['content-type']}\n';
      
      _updateCookies(res.headers);
      
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        // Double check it's actually an image
        if (res.headers['content-type']?.contains('text/html') == true) {
          lastDebugLog += '   -> ERROR: Server returned HTML instead of an image!\n';
          return null;
        }
        lastDebugLog += '3. CAPTCHA retrieved successfully.\n';
        return res.bodyBytes;
      }
      return null;
    } catch (e) {
      lastDebugLog += '   -> EXCEPTION: $e\n';
      return null;
    }
  }

  /// Submits the login form using the current session.
  Future<http.Response> login({
    required String enrollment,
    required String password,
    required String captcha,
  }) async {
    final req = http.Request('POST', Uri.parse('https://sraap.in/student_login.php'));
    req.headers.addAll(_headers(isForm: true));
    req.followRedirects = false; // CRITICAL: Stop auto-redirect to capture cookies correctly
    req.bodyFields = {
      'user_id': enrollment,
      'user_password': password,
      'token': captcha,
      'submit': 'Sign in',
    };

    final stream = await _client.send(req);
    final res = await http.Response.fromStream(stream);

    _updateCookies(res.headers);
    return res;
  }

  /// Checks if the session is still valid.
  Future<bool> checkSession() async {
    if (_cookieHeader.isEmpty) return false;
    try {
      final res = await _client.get(
        Uri.parse('https://sraap.in/student_login.php'),
        headers: _headers(),
      );
      _updateCookies(res.headers);
      
      final body = res.body.toLowerCase();
      // If we request login page while authenticated, SRAAP usually redirects to dashboard
      // or the page contains 'logout' or does not contain 'student_login'.
      if (res.statusCode == 302 || res.statusCode == 301) return true;
      if (res.statusCode == 200 && !body.contains('student_login') && body.contains('student')) return true;
      if (res.statusCode == 200 && body.contains('logout')) return true;
      
      return false;
    } catch (_) {
      // In case of network errors, we can't definitively say the session is dead,
      // but for this check we return false.
      return false;
    }
  }

  /// General authenticated GET request (for fetching academic data later).
  Future<http.Response> get(String path) async {
    final res = await _client.get(
      Uri.parse('https://sraap.in$path'),
      headers: _headers(),
    );
    _updateCookies(res.headers);
    return res;
  }

  /// Wipes the session.
  Future<void> clearSession() async {
    _cookieHeader = '';
    _cookies.clear();
    _client.close();
    _client = http.Client();
    await StorageService.clearSessionState();
  }

  Map<String, String> _headers({bool isForm = false}) {
    final Map<String, String> headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': 'https://sraap.in/student_login.php',
      'Connection': 'keep-alive',
    };
    if (isForm) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }
    if (_cookieHeader.isNotEmpty) {
      headers['Cookie'] = _cookieHeader;
    }
    return headers;
  }

  void _updateCookies(Map<String, String> responseHeaders) {
    final setCookie = responseHeaders['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      // Dart http joins multiple set-cookie headers with a comma.
      // We split carefully to avoid splitting commas within date strings like 'Expires=Thu, 01 Jan...'
      // A simple regex looks for a comma followed by a word and an equals sign (e.g. ', PHPSESSID=')
      final parts = setCookie.split(RegExp(r',(?=[a-zA-Z0-9_\-]+=|$)'));
      for (var part in parts) {
        final cookieString = part.split(';').first.trim();
        final equalIndex = cookieString.indexOf('=');
        if (equalIndex != -1) {
          final key = cookieString.substring(0, equalIndex);
          final value = cookieString.substring(equalIndex + 1);
          _cookies[key] = value;
        }
      }
      
      if (_cookies.isNotEmpty) {
        _cookieHeader = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
        // Persist the sanitized cookie string
        StorageService.saveSessionState({'cookie': _cookieHeader});
      }
    }
  }
}
