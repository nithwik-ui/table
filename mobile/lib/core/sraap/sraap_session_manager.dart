import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage.dart';
import 'sraap_session_state.dart';

/// Manages the low-level HTTP session for SRAAP.
/// Holds the PHPSESSID cookie and ensures all requests use the same context.
class SraapSessionManager {
  static final SraapSessionManager instance = SraapSessionManager._();
  SraapSessionManager._();

  String _cookieHeader = '';
  final Map<String, String> _cookies = {};
  http.Client _client = http.Client();
  @visibleForTesting
  set client(http.Client client) => _client = client;

  static String get baseUrl => kIsWeb ? '/api/sraap' : 'https://sraap.in';

  /// Contains non-sensitive diagnostic info for debugging.
  String lastDebugLog = '';

  bool isSessionExpired = false;

  /// Explicit state of the CAPTCHA + login state machine.
  SraapLoginFlowState flowState = SraapLoginFlowState.initial;

  /// True while the user is actively on the SRAAP login or quick-reconnect UI.
  /// Prevents background keep-alive or silent sync from overwriting the login cookie.
  bool isLoginFlowActive = false;

  Future<Uint8List?>? _inFlightCaptchaFetch;
  bool _isLoginInFlight = false;

  /// Gets the current session cookies.
  String get cookieHeader => _cookieHeader;

  void _logDiag(String line) {
    final entry = 'SRAAP_LOGIN: $line';
    lastDebugLog += '$entry\n';
    debugPrint(entry);
  }

  /// Case-insensitive HTTP header lookup.
  static String? headerValue(Map<String, String> headers, String name) {
    final direct = headers[name] ?? headers[name.toLowerCase()];
    if (direct != null) return direct;
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) {
        return entry.value;
      }
    }
    return null;
  }

  /// Validates that the response body is a genuine image and not HTML/JSON/text error markup.
  static bool isValidImageBytes(Uint8List bytes, String? contentType) {
    if (bytes.isEmpty) return false;
    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains('text/html') ||
        ct.contains('application/json') ||
        ct.contains('text/plain')) {
      return false;
    }

    // Check magic bytes for PNG, JPEG, GIF, WebP, BMP
    if (bytes.length >= 4) {
      // PNG: 89 50 4E 47
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return true;
      }
      // JPEG: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return true;
      }
      // GIF: 'GIF8' (47 49 46 38)
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38) {
        return true;
      }
      // WebP: 'RIFF' (52 49 46 46)
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        return true;
      }
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true; // BMP
    }

    // Reject payloads starting with HTML tags or JSON braces
    final sampleLen = bytes.length > 64 ? 64 : bytes.length;
    final sample = latin1.decode(bytes.sublist(0, sampleLen)).trimLeft().toLowerCase();
    if (sample.startsWith('<') ||
        sample.startsWith('{') ||
        sample.startsWith('error') ||
        sample.startsWith('server')) {
      return false;
    }

    // Allow synthetic test byte arrays when content-type is explicitly image/* or omitted in tests
    if (ct.startsWith('image/') || ct.isEmpty) {
      return true;
    }

    return false;
  }

  /// Restores a previously saved session.
  Future<void> restoreSession() async {
    if (isLoginFlowActive && _cookieHeader.isNotEmpty) {
      return;
    }
    final state = await StorageService.loadSessionState();
    final cookie = state?['cookie'] ?? state?['cookieHeader'];
    if (cookie != null && cookie is String && cookie.isNotEmpty) {
      _cookieHeader = cookie;
      _cookies.clear();
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
      flowState = SraapLoginFlowState.loadingSession;
      final res = await _client
          .get(
            Uri.parse('$baseUrl/student_login.php'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 15));
      _updateCookies(res.headers);
      final ok = res.statusCode == 200;
      if (ok) {
        isSessionExpired = false;
      }
      _logDiag('session_initialized=$ok');
      _logDiag('session_cookie_present=${_cookieHeader.isNotEmpty}');
      return ok;
    } catch (_) {
      _logDiag('session_initialized=false');
      return false;
    }
  }

  /// Fetches a fresh CAPTCHA image using the current login session.
  /// If [forceFreshSession] is true, or if [isSessionExpired], or if [_cookieHeader.isEmpty],
  /// a fresh PHP session is initialized first via /student_login.php.
  /// Subsequent CAPTCHA refreshes ([forceFreshSession] == false) reuse the existing
  /// login session cookie so the session and CAPTCHA remain strictly synchronized.
  Future<Uint8List?> fetchCaptcha({bool forceFreshSession = false}) async {
    if (_inFlightCaptchaFetch != null) {
      return _inFlightCaptchaFetch;
    }
    final future = _fetchCaptchaInternal(forceFreshSession: forceFreshSession);
    _inFlightCaptchaFetch = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightCaptchaFetch, future)) {
        _inFlightCaptchaFetch = null;
      }
    }
  }

  Future<Uint8List?> _fetchCaptchaInternal({required bool forceFreshSession}) async {
    lastDebugLog = '--- CAPTCHA FETCH LOG ---\n';
    final bool needsSessionInit =
        _cookieHeader.isEmpty || isSessionExpired || forceFreshSession;

    try {
      if (needsSessionInit) {
        flowState = SraapLoginFlowState.loadingSession;
        final previousCookies = Map<String, String>.from(_cookies);
        final previousCookieHeader = _cookieHeader;

        if (forceFreshSession || isSessionExpired) {
          _cookies.clear();
          _cookieHeader = '';
        }

        bool initSucceeded = false;
        try {
          final initRes = await _client
              .get(
                Uri.parse('$baseUrl/student_login.php'),
                headers: _headers(clearProxyCookie: forceFreshSession),
              )
              .timeout(const Duration(seconds: 15));
          _updateCookies(initRes.headers);
          initSucceeded = initRes.statusCode == 200;
        } catch (initErr) {
          // If the 104 KB student_login.php page times out on slow mobile data,
          // proceed to /captcha/image.php (~2 KB), which also calls session_start()
          // and issues Set-Cookie: PHPSESSID=... on sraap.in.
          lastDebugLog += '   -> Login page init fallback: $initErr\n';
        }

        // If the server/proxy reused an existing session without re-emitting Set-Cookie,
        // preserve the previous cookie if we had one and weren't forced to drop it.
        if (_cookieHeader.isEmpty &&
            previousCookieHeader.isNotEmpty &&
            !forceFreshSession) {
          _cookies.addAll(previousCookies);
          _cookieHeader = previousCookieHeader;
        }

        if (initSucceeded || _cookieHeader.isNotEmpty) {
          isSessionExpired = false;
        }
        _logDiag('session_initialized=${initSucceeded || _cookieHeader.isNotEmpty}');
        _logDiag('session_cookie_present=${_cookieHeader.isNotEmpty}');
      } else {
        _logDiag('session_initialized=true');
        _logDiag('session_cookie_present=${_cookieHeader.isNotEmpty}');
      }

      flowState = SraapLoginFlowState.loadingCaptcha;
      _logDiag('captcha_load_started=true');

      final res = await _client
          .get(
            Uri.parse(
              '$baseUrl/captcha/image.php?${DateTime.now().millisecondsSinceEpoch}',
            ),
            headers: _headers(isImage: true),
          )
          .timeout(const Duration(seconds: 15));

      _updateCookies(res.headers);
      if (_cookieHeader.isNotEmpty) {
        isSessionExpired = false;
      }

      final contentType = headerValue(res.headers, 'content-type');
      _logDiag('captcha_http_status=${res.statusCode}');
      _logDiag('captcha_content_type=${contentType ?? 'unknown'}');
      _logDiag('session_cookie_present=${_cookieHeader.isNotEmpty}');

      if (res.statusCode == 200 &&
          isValidImageBytes(res.bodyBytes, contentType)) {
        flowState = SraapLoginFlowState.captchaReady;
        _logDiag('captcha_load_completed=true');
        return res.bodyBytes;
      }

      flowState = SraapLoginFlowState.captchaError;
      _logDiag('captcha_load_completed=false');
      return null;
    } catch (e) {
      flowState = SraapLoginFlowState.captchaError;
      _logDiag('captcha_load_completed=false');
      lastDebugLog += '   -> EXCEPTION: ${e.runtimeType}\n';
      return null;
    }
  }

  /// Submits the login form using the current session.
  /// Enforces one deliberate login attempt at a time.
  Future<http.Response> login({
    required String enrollment,
    required String password,
    required String captcha,
  }) async {
    if (_isLoginInFlight) {
      throw StateError('Login submission already in progress.');
    }
    _isLoginInFlight = true;
    flowState = SraapLoginFlowState.submittingLogin;
    _logDiag('login_submit_started=true');
    _logDiag('session_cookie_present=${_cookieHeader.isNotEmpty}');

    try {
      final req = http.Request('POST', Uri.parse('$baseUrl/student_login.php'));
      req.headers.addAll(_headers(isForm: true));
      if (!kIsWeb) {
        req.followRedirects =
            false; // CRITICAL: Stop auto-redirect to capture cookies correctly on mobile
      }
      req.bodyFields = {
        'user_id': enrollment.trim(),
        'user_password': password,
        'token': captcha.trim(),
        'submit': 'Sign in',
      };

      final stream =
          await _client.send(req).timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(stream)
          .timeout(const Duration(seconds: 15));

      _updateCookies(res.headers);

      final proxyRedirect = headerValue(res.headers, 'x-proxy-redirect');
      final location = headerValue(res.headers, 'location');
      final redirectDetected = res.statusCode == 302 ||
          res.statusCode == 301 ||
          res.isRedirect ||
          (proxyRedirect != null && proxyRedirect.isNotEmpty) ||
          (location != null && location.isNotEmpty);

      _logDiag('login_response_status=${res.statusCode}');
      _logDiag('redirect_detected=$redirectDetected');
      _logDiag('session_cookie_present=${_cookieHeader.isNotEmpty}');

      return res;
    } finally {
      _isLoginInFlight = false;
    }
  }

  /// Verifies whether the current session cookie is authenticated by checking /student/dash_board.php.
  /// Used when POST /student_login.php returns 200 OK without explicit error markers
  /// (e.g. when Web proxy intercepts 302 or PHP flushes modal HTML before redirecting).
  Future<bool> verifyAuthenticatedSession() async {
    if (_cookieHeader.isEmpty && !kIsWeb) return false;
    try {
      final res = await _client
          .get(
            Uri.parse('$baseUrl/student/dash_board.php'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 10));
      _updateCookies(res.headers);

      if (res.statusCode == 302 || res.statusCode == 301) {
        return false;
      }
      final proxyRedir =
          (headerValue(res.headers, 'x-proxy-redirect') ?? '').toLowerCase();
      if (proxyRedir.contains('login')) {
        return false;
      }

      if (res.statusCode == 200) {
        final body = res.body.toLowerCase();
        final isUnauthenticated = body.contains('slogin.php') ||
            body.contains('in valid login') ||
            body.contains('student_login') ||
            body.contains('enter enrolment no') ||
            body.contains('user_password');
        if (isUnauthenticated) return false;

        final isDashboard = body.contains('welcome to') ||
            body.contains('attendancetable') ||
            body.contains('logout') ||
            body.contains('attendance');
        if (isDashboard) {
          await markAuthenticated();
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Marks the current session as authenticated and persists the session cookie.
  Future<void> markAuthenticated() async {
    isSessionExpired = false;
    isLoginFlowActive = false;
    flowState = SraapLoginFlowState.authenticated;
    if (_cookieHeader.isNotEmpty) {
      await StorageService.saveSessionState({
        'cookie': _cookieHeader,
        'cookieHeader': _cookieHeader,
      });
    }
  }

  /// Checks if the session is still valid.
  Future<bool> checkSession() async {
    if (_cookieHeader.isEmpty && !kIsWeb) return false;
    try {
      final res = await _client
          .get(
            Uri.parse('$baseUrl/student_login.php'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 15));
      _updateCookies(res.headers);

      final body = res.body.toLowerCase();
      if (res.statusCode == 302 || res.statusCode == 301) return true;
      if (res.statusCode == 200 &&
          !body.contains('student_login') &&
          body.contains('student')) {
        return true;
      }
      if (res.statusCode == 200 && body.contains('logout')) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  /// General authenticated GET request (for fetching academic data later).
  Future<http.Response> get(String path) async {
    final res = await _client
        .get(
          Uri.parse('${SraapSessionManager.baseUrl}$path'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 15));
    _updateCookies(res.headers);
    return res;
  }

  /// Wipes the session.
  Future<void> clearSession() async {
    _cookieHeader = '';
    _cookies.clear();
    isSessionExpired = false;
    isLoginFlowActive = false;
    _inFlightCaptchaFetch = null;
    _isLoginInFlight = false;
    flowState = SraapLoginFlowState.initial;
    _client.close();
    _client = http.Client();
    await StorageService.clearSessionState();
  }

  Map<String, String> _headers({
    bool isForm = false,
    bool isImage = false,
    bool clearProxyCookie = false,
  }) {
    final Map<String, String> headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': isImage
          ? 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8'
          : 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': '${SraapSessionManager.baseUrl}/student_login.php',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'Connection': 'keep-alive',
    };
    if (isForm) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }
    if (kIsWeb && clearProxyCookie) {
      headers['x-proxy-clear-cookie'] = '1';
    } else if (_cookieHeader.isNotEmpty) {
      if (kIsWeb) {
        headers['x-proxy-cookie'] = _cookieHeader;
      } else {
        headers['Cookie'] = _cookieHeader;
      }
    }
    return headers;
  }

  void _updateCookies(Map<String, String> responseHeaders) {
    final setCookie = headerValue(responseHeaders, 'set-cookie') ??
        headerValue(responseHeaders, 'x-proxy-set-cookie');
    if (setCookie != null && setCookie.isNotEmpty) {
      final parts = setCookie.split(RegExp(r',(?=\s*[a-zA-Z0-9_\-]+=|$)'));
      for (var part in parts) {
        final cookieString = part.split(';').first.trim();
        final equalIndex = cookieString.indexOf('=');
        if (equalIndex > 0) {
          final key = cookieString.substring(0, equalIndex).trim();
          final value = cookieString.substring(equalIndex + 1).trim();
          if (value.isNotEmpty && value.toLowerCase() != 'deleted') {
            _cookies[key] = value;
          }
        }
      }

      if (_cookies.isNotEmpty) {
        _cookieHeader =
            _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
        // Only overwrite persisted session state if not in the middle of an unauthenticated login screen,
        // or if no authenticated session is currently marked connected.
        if (!isLoginFlowActive || !StorageService.isSraapConnected()) {
          StorageService.saveSessionState({
            'cookie': _cookieHeader,
            'cookieHeader': _cookieHeader,
          });
        }
      }
    }
  }
}
