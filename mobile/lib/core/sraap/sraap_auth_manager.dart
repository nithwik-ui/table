import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  /// Attempt to restore a previous session from storage.
  /// Decoupled from network so boot is instant and offline cache remains usable.
  Future<bool> restoreSession() async {
    final stored = await StorageService.loadSessionState();
    if (stored == null) {
      _setState(SraapSessionState.notConnected);
      return false;
    }

    final cookieHeader =
        (stored['cookieHeader'] ?? stored['cookie']) as String?;
    if (cookieHeader == null || cookieHeader.isEmpty) {
      _setState(SraapSessionState.notConnected);
      return false;
    }

    await SraapSessionManager.instance.restoreSession();
    _setState(SraapSessionState.connected);
    return true;
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
    await SraapSessionManager.instance.markAuthenticated();
    final cookieHeader = SraapSessionManager.instance.cookieHeader;
    await StorageService.saveSessionState({
      'cookie': cookieHeader,
      'cookieHeader': cookieHeader,
    });
    await StorageService.setSraapConnected(true);
    _lastSuccessfulRequest = DateTime.now();
    _setState(SraapSessionState.connected);
  }

  /// Securely disconnect and wipe all stored SRAAP state.
  /// Does NOT touch timetable, notifications, or student/faculty mode.
  Future<void> disconnect() async {
    await StorageService.clearSessionState();
    await StorageService.setSraapConnected(false);
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
  static Future<Uint8List?> fetchCaptchaBytes({
    bool forceFreshSession = false,
  }) async {
    return await SraapSessionManager.instance.fetchCaptcha(
      forceFreshSession: forceFreshSession,
    );
  }

  /// Deterministically evaluates a SRAAP login HTTP response without side effects.
  static SraapLoginResult evaluateLoginResponse(http.Response response) {
    final body = response.body.toLowerCase();
    final proxyRedirect =
        SraapSessionManager.headerValue(response.headers, 'x-proxy-redirect');
    final locationHeader =
        SraapSessionManager.headerValue(response.headers, 'location');
    final redirectTarget =
        (proxyRedirect ?? locationHeader ?? '').trim().toLowerCase();

    final bool hasHttpRedirect = response.statusCode == 302 ||
        response.statusCode == 301 ||
        response.isRedirect ||
        redirectTarget.isNotEmpty;

    if (hasHttpRedirect) {
      final bool redirectsToLogin =
          redirectTarget.contains('student_login') ||
          redirectTarget.contains('slogin.php');
      if (!redirectsToLogin) {
        return SraapLoginResult(
          success: true,
          cookieHeader: SraapSessionManager.instance.cookieHeader,
        );
      }
    }

    // Check explicit portal/network restrictions first
    if (body.contains('access restricted') ||
        body.contains('shared public ip') ||
        body.contains('server busy') ||
        body.contains('server under maintenance')) {
      return const SraapLoginResult(
        success: false,
        error: SraapLoginError.portalUnavailable,
      );
    }

    // Check explicit script redirect to session expired / slogin
    if (body.contains('../slogin.php') ||
        body.contains("location.href = '../slogin.php'") ||
        body.contains("location.href='../slogin.php'")) {
      return const SraapLoginResult(
        success: false,
        error: SraapLoginError.sessionExpired,
      );
    }

    // Check explicit CAPTCHA rejection markers from sraap.in
    if (body.contains('enter captcha code') ||
        body.contains('enter captcha') ||
        body.contains('invalid captcha') ||
        body.contains('wrong captcha') ||
        body.contains('captcha code is invalid') ||
        body.contains('captcha mismatch')) {
      return const SraapLoginResult(
        success: false,
        error: SraapLoginError.invalidCaptcha,
      );
    }

    // Check explicit invalid credential markers from sraap.in
    if (body.contains("sorry, i don't recognize you") ||
        body.contains('kindly recheck') ||
        body.contains('recheck') ||
        body.contains('wrong password') ||
        body.contains('invalid password') ||
        body.contains('invalid user') ||
        body.contains('in valid login') ||
        body.contains('invalid login') ||
        body.contains('user not found') ||
        body.contains('enter enrolment no') ||
        body.contains('forgot_passwords.php') ||
        body.contains('forgot / reset password')) {
      return const SraapLoginResult(
        success: false,
        error: SraapLoginError.invalidCredentials,
      );
    }

    // Compatibility check for general slogin.php redirection
    if (body.contains('slogin.php')) {
      return const SraapLoginResult(
        success: false,
        error: SraapLoginError.sessionExpired,
      );
    }

    // Check HTTP 200 dashboard or JS redirect success markers
    if (response.statusCode == 200) {
      final bool hasJsDashboardRedirect =
          body.contains('dash_board.php') ||
          body.contains("location.href='student/") ||
          body.contains('location.href="student/') ||
          body.contains("location.href = 'student/") ||
          body.contains('location.href = "student/');

      final bool hasDashboardContent =
          (body.contains('logout') ||
              body.contains('attendancetable') ||
              body.contains('welcome to')) &&
          !body.contains('student_login');

      if (hasJsDashboardRedirect || hasDashboardContent) {
        return SraapLoginResult(
          success: true,
          cookieHeader: SraapSessionManager.instance.cookieHeader,
        );
      }
    }

    return const SraapLoginResult(
      success: false,
      error: SraapLoginError.unknown,
    );
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
      final normalizedEnrollment = enrollment.trim().toUpperCase();
      final response = await SraapSessionManager.instance.login(
        enrollment: normalizedEnrollment,
        password: password,
        captcha: captcha,
      );

      var result = evaluateLoginResponse(response);

      // Compatibility fallback: if POST /student_login.php returned 200 OK without
      // any error banner (e.g. PHP headers already flushed after modal include on sraap.in,
      // or proxy 200 with empty body), verify once against /student/dash_board.php
      // before declaring failure or touching the CAPTCHA.
      if (!result.success &&
          result.error == SraapLoginError.unknown &&
          response.statusCode == 200) {
        final verified =
            await SraapSessionManager.instance.verifyAuthenticatedSession();
        if (verified) {
          result = SraapLoginResult(
            success: true,
            cookieHeader: SraapSessionManager.instance.cookieHeader,
          );
        }
      }

      if (result.success) {
        await SraapSessionManager.instance.markAuthenticated();
        instance._lastSuccessfulRequest = DateTime.now();
        instance._setState(SraapSessionState.connected);
        return result;
      }

      switch (result.error) {
        case SraapLoginError.invalidCaptcha:
          SraapSessionManager.instance.flowState =
              SraapLoginFlowState.captchaError;
          instance._setState(SraapSessionState.captchaError);
          break;
        case SraapLoginError.invalidCredentials:
          SraapSessionManager.instance.flowState =
              SraapLoginFlowState.invalidCredentials;
          instance._setState(SraapSessionState.authError);
          break;
        case SraapLoginError.sessionExpired:
          SraapSessionManager.instance.flowState =
              SraapLoginFlowState.sessionExpired;
          instance._setState(SraapSessionState.sessionExpired);
          break;
        case SraapLoginError.portalUnavailable:
          SraapSessionManager.instance.flowState =
              SraapLoginFlowState.networkError;
          instance._setState(SraapSessionState.portalUnavailable);
          break;
        case SraapLoginError.networkUnavailable:
        case SraapLoginError.timeout:
          SraapSessionManager.instance.flowState =
              SraapLoginFlowState.networkError;
          instance._setState(SraapSessionState.networkError);
          break;
        case SraapLoginError.unknown:
        case null:
          SraapSessionManager.instance.flowState =
              SraapLoginFlowState.sessionExpired;
          break;
      }

      return result;
    } catch (e) {
      SraapSessionManager.instance.flowState = SraapLoginFlowState.networkError;
      if (e is TimeoutException) {
        instance._setState(SraapSessionState.networkError);
        return const SraapLoginResult(
          success: false,
          error: SraapLoginError.timeout,
        );
      }
      final eStr = e.toString().toLowerCase();
      if (eStr.contains('socketexception') ||
          eStr.contains('clientexception') ||
          eStr.contains('xmlhttprequest') ||
          eStr.contains('handshakeexception') ||
          eStr.contains('connection')) {
        instance._setState(SraapSessionState.networkError);
        return const SraapLoginResult(
          success: false,
          error: SraapLoginError.networkUnavailable,
        );
      }
      instance._setState(SraapSessionState.portalUnavailable);
      return const SraapLoginResult(
        success: false,
        error: SraapLoginError.portalUnavailable,
      );
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
  sessionExpired,
  networkUnavailable,
  timeout,
  portalUnavailable,
  unknown,
}
