import 'dart:async';
import 'package:flutter/foundation.dart';
import '../storage.dart';
import 'sraap_session_state.dart';
import 'sraap_session_manager.dart';

/// Singleton manager responsible for the entire SRAAP authentication lifecycle.
///
/// It is deliberately isolated from all timetable/notification logic.
/// It does NOT store passwords, CAPTCHAs, or raw session cookies in logs.
class SraapAuthManager extends ChangeNotifier {
  SraapAuthManager._();
  static final SraapAuthManager instance = SraapAuthManager._();

  SraapSessionState _state = SraapSessionState.notConnected;
  SraapSessionState get state => _state;
  bool get isConnected => _state == SraapSessionState.connected;

  DateTime? _lastSuccessfulRequest;
  DateTime? get lastSuccessfulRequest => _lastSuccessfulRequest;

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Attempt to restore a previous session from secure storage.
  /// Returns true if the session is still valid on the server.
  Future<bool> restoreSession() async {
    _setState(SraapSessionState.checkingSession);
    final stored = await StorageService.loadSessionState();
    if (stored == null) {
      _setState(SraapSessionState.notConnected);
      return false;
    }
    
    final cookieHeader = stored['cookieHeader'] as String?;
    if (cookieHeader == null || cookieHeader.isEmpty) {
      _setState(SraapSessionState.notConnected);
      return false;
    }
    
    await SraapSessionManager.instance.restoreSession();
    final valid = await SraapSessionManager.instance.checkSession();
    
    if (valid) {
      _lastSuccessfulRequest = DateTime.now();
      _setState(SraapSessionState.connected);
      return true;
    } else {
      await StorageService.clearSessionState();
      await SraapSessionManager.instance.clearSession();
      _setState(SraapSessionState.sessionExpired);
      return false;
    }
  }

  /// Check whether the currently held session is still valid.
  Future<bool> checkSession() async {
    if (_state == SraapSessionState.notConnected) return false;
    _setState(SraapSessionState.checkingSession);
    
    final valid = await SraapSessionManager.instance.checkSession();
    
    if (valid) {
      _lastSuccessfulRequest = DateTime.now();
      _setState(SraapSessionState.connected);
      return true;
    } else {
      _setState(SraapSessionState.sessionExpired);
      return false;
    }
  }

  /// Called after the user completes the login form in the UI.
  /// NEVER log cookieHeader or its contents.
  Future<void> onLoginSuccess() async {
    final cookieHeader = SraapSessionManager.instance.cookieHeader;
    await StorageService.saveSessionState({'cookieHeader': cookieHeader});
    _lastSuccessfulRequest = DateTime.now();
    _setState(SraapSessionState.connected);
  }

  /// Securely disconnect and wipe all stored SRAAP state.
  /// Does NOT touch timetable, notifications, or student/faculty mode.
  Future<void> disconnect() async {
    await StorageService.clearSessionState();
    await SraapSessionManager.instance.clearSession();
    _lastSuccessfulRequest = null;
    _setState(SraapSessionState.notConnected);
  }

  /// Explicitly set state to authenticating (called by login screen before POST).
  void setAuthenticating() => _setState(SraapSessionState.authenticating);

  void setAuthError() => _setState(SraapSessionState.authError);
  void setCaptchaError() => _setState(SraapSessionState.captchaError);
  void setPortalUnavailable() => _setState(SraapSessionState.portalUnavailable);
  void setNetworkError() => _setState(SraapSessionState.networkError);

  // ─── CAPTCHA ────────────────────────────────────────────────────────────────

  /// Fetches the raw bytes of the SRAAP CAPTCHA image.
  /// The student must solve this manually.
  static Future<Uint8List?> fetchCaptchaBytes() async {
    return await SraapSessionManager.instance.fetchCaptcha();
  }

  /// Submit login credentials + CAPTCHA to SRAAP.
  /// Returns a [SraapLoginResult] describing the outcome.
  /// NEVER log enrollment, password, or captcha.
  static Future<SraapLoginResult> submitLogin({
    required String enrollment,
    required String password,
    required String captcha,
  }) async {
    try {
      final response = await SraapSessionManager.instance.login(
        enrollment: enrollment,
        password: password,
        captcha: captcha,
      );

      final body = response.body.toLowerCase();

      if (response.statusCode == 302 || (response.statusCode == 200 && body.contains('logout'))) {
        return SraapLoginResult(
          success: true,
          cookieHeader: SraapSessionManager.instance.cookieHeader,
        );
      }
      if (body.contains('invalid captcha') || body.contains('captcha')) {
        return SraapLoginResult(success: false, error: SraapLoginError.invalidCaptcha);
      }
      if (body.contains('invalid') || body.contains('incorrect') || body.contains('wrong')) {
        return SraapLoginResult(success: false, error: SraapLoginError.invalidCredentials);
      }
      return SraapLoginResult(success: false, error: SraapLoginError.unknown);
    } catch (e) {
      if (e is TimeoutException) {
        return SraapLoginResult(success: false, error: SraapLoginError.timeout);
      }
      final eStr = e.toString().toLowerCase();
      if (eStr.contains('socketexception') || eStr.contains('clientexception') || eStr.contains('xmlhttprequest')) {
        return SraapLoginResult(success: false, error: SraapLoginError.networkUnavailable);
      }
      return SraapLoginResult(success: false, error: SraapLoginError.portalUnavailable);
    }
  }

  void _setState(SraapSessionState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }
}

/// Result of attempting a SRAAP login submission.
class SraapLoginResult {
  final bool success;
  final String? cookieHeader;
  final SraapLoginError? error;

  const SraapLoginResult({
    required this.success,
    this.cookieHeader,
    this.error,
  });
}

enum SraapLoginError {
  invalidCredentials,
  invalidCaptcha,
  networkUnavailable,
  timeout,
  portalUnavailable,
  unknown,
}
