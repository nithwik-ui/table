import 'package:flutter/foundation.dart';
import 'auth_state.dart';
import 'secure_session_store.dart';
import '../sru/sru_auth_client.dart';
import '../storage.dart';

class AuthRepository extends ChangeNotifier {
  static final AuthRepository instance = AuthRepository._();
  AuthRepository._();

  AuthState _state = AuthState.unauthenticated;
  AuthState get state => _state;

  String? _currentRole;
  String? get currentRole => _currentRole;

  String? _savedIdentifier;
  String? _savedPassword;
  bool _rememberMe = true;

  void _setState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void setRole(String role) {
    _currentRole = role;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    _setState(AuthState.restoringSession);
    final sessionData = await SecureSessionStore.getSession();
    final cachedRole = StorageService.getUserMode();
    final hasCache = StorageService.getTimetableCache().isNotEmpty || 
                     StorageService.getFacultyTimetableCache().isNotEmpty ||
                     StorageService.getStudentRollNumber() != null;

    if (sessionData != null && (sessionData['cookie'] != null || sessionData['identifier'] != null)) {
      if (sessionData['cookie'] != null) {
        SruAuthClient.instance.restoreCookies(sessionData['cookie']);
      }
      _currentRole = sessionData['role'] ?? cachedRole ?? 'student';
      await StorageService.setUserMode(_currentRole!);

      if (sessionData['identifier'] != null) {
        _savedIdentifier = sessionData['identifier'];
      }
      if (sessionData['password'] != null) {
        _savedPassword = sessionData['password'];
      }

      // CRITICAL FIX: The user is already authenticated on this device!
      // Immediately set AuthState.ready so the app opens the Dashboard with cached timetable.
      // NEVER block the user or bounce them to ModeSelectionScreen after 8 hours!
      _setState(AuthState.ready);

      // Perform non-blocking background validation / silent refresh
      _validateAndRefreshInBackground(sessionData);
      return;
    } else if (hasCache && cachedRole != null) {
      _currentRole = cachedRole;
      _setState(AuthState.ready);
      return;
    } else {
      _setState(AuthState.unauthenticated);
    }
  }

  void _validateAndRefreshInBackground(Map<String, dynamic> sessionData) async {
    try {
      final isValid = await _validateSession();
      if (isValid) {
        _setState(AuthState.authenticated);
        _setState(AuthState.ready);
        return;
      }

      // Session expired on remote PHP portal (e.g. after 8 hours)
      // If credentials were saved with Remember Me, attempt silent background re-authentication
      final id = sessionData['identifier'] as String? ?? _savedIdentifier;
      final pwd = sessionData['password'] as String? ?? _savedPassword;
      if (id != null && id.isNotEmpty && pwd != null && pwd.isNotEmpty) {
        try {
          final result = await SruAuthClient.instance.login(id, pwd);
          if (result['status'] == 'authenticated') {
            await _saveSession();
            _setState(AuthState.authenticated);
            _setState(AuthState.ready);
            return;
          }
        } catch (_) {}
      }

      // Even if remote session requires an OTP for fresh scrape,
      // the user MUST NOT be logged out of their mobile app or kicked to login!
      // Cached timetable and FCM updates remain fully available.
      _setState(AuthState.ready);
    } catch (_) {
      // Offline / network error: maintain ready state with cached data
      _setState(AuthState.ready);
    }
  }

  Future<bool> _validateSession() async {
    try {
      final response = await SruAuthClient.instance.getAuthenticated('${SruAuthClient.baseUrl}/student/timetable');
      if (response.statusCode == 200 && !response.body.toLowerCase().contains('login')) {
        return true;
      }
      return false;
    } catch (_) {
      throw Exception('Network Error');
    }
  }

  Future<void> login(String identifier, String password, {bool rememberMe = true}) async {
    _savedIdentifier = identifier;
    _savedPassword = password;
    _rememberMe = rememberMe;
    _setState(AuthState.authenticating);
    try {
      final result = await SruAuthClient.instance.login(identifier, password);
      if (result['status'] == 'otp_required') {
        _setState(AuthState.awaitingOTP);
      } else if (result['status'] == 'authenticated') {
        await _saveSession();
        _setState(AuthState.authenticated);
        _setState(AuthState.ready);
      }
    } on SruAuthException {
      _setState(AuthState.authenticationError);
      rethrow;
    } catch (e) {
      _setState(AuthState.networkError);
      rethrow;
    }
  }

  Future<void> verifyOtp(String otp) async {
    _setState(AuthState.verifyingOTP);
    try {
      final result = await SruAuthClient.instance.verifyOtp(otp);
      if (result['status'] == 'authenticated') {
        await _saveSession();
        _setState(AuthState.authenticated);
        _setState(AuthState.ready);
      }
    } on SruAuthException {
      _setState(AuthState.awaitingOTP);
      rethrow;
    } catch (e) {
      _setState(AuthState.networkError);
      rethrow;
    }
  }

  Future<void> saveSession() => _saveSession();

  Future<void> _saveSession() async {
    final role = _currentRole ?? 'student';
    await StorageService.setUserMode(role);
    final sessionMap = <String, dynamic>{
      'cookie': SruAuthClient.instance.cookieHeader,
      'role': role,
      'lastAuthenticated': DateTime.now().toIso8601String(),
    };
    if (_rememberMe && _savedIdentifier != null && _savedPassword != null) {
      sessionMap['identifier'] = _savedIdentifier;
      sessionMap['password'] = _savedPassword;
      sessionMap['rememberMe'] = true;
    }
    await SecureSessionStore.saveSession(sessionMap);
  }

  Future<void> logout() async {
    _setState(AuthState.loggingOut);
    SruAuthClient.instance.clearSession();
    await SecureSessionStore.clearSession();
    _savedIdentifier = null;
    _savedPassword = null;
    _currentRole = null;
    _setState(AuthState.unauthenticated);
  }
}
