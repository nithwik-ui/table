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

  Future<void> restoreSession({String? targetRole}) async {
    _setState(AuthState.restoringSession);
    final cachedRole = targetRole ?? StorageService.getUserMode() ?? 'student';
    final sessionData = await SecureSessionStore.getSession(role: cachedRole);
    final hasCache = (cachedRole == 'faculty'
        ? StorageService.getFacultyTimetableCache().isNotEmpty
        : StorageService.getTimetableCache().isNotEmpty) ||
        StorageService.getStudentRollNumber() != null;

    if (sessionData != null && (sessionData['cookie'] != null || sessionData['identifier'] != null)) {
      if (sessionData['cookie'] != null) {
        SruAuthClient.instance.restoreCookies(sessionData['cookie']);
      }
      _currentRole = sessionData['role'] ?? cachedRole;
      await StorageService.setUserMode(_currentRole!);

      if (sessionData['identifier'] != null) {
        _savedIdentifier = sessionData['identifier'];
      }

      _setState(AuthState.ready);
      return;
    } else if (hasCache) {
      _currentRole = cachedRole;
      await StorageService.setUserMode(_currentRole!);
      _setState(AuthState.ready);
      return;
    } else {
      _setState(AuthState.unauthenticated);
    }
  }

  bool _isLoginInProgress = false;
  bool _isVerifyInProgress = false;

  Future<void> login(String identifier, String password, {bool rememberMe = true}) async {
    if (_isLoginInProgress) {
      debugPrint('[AUTH] Login already in flight, ignoring duplicate call.');
      return;
    }
    _isLoginInProgress = true;
    _savedIdentifier = identifier;
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
    } finally {
      _isLoginInProgress = false;
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (_isVerifyInProgress) {
      debugPrint('[AUTH] OTP verification already in flight, ignoring duplicate call.');
      return;
    }
    _isVerifyInProgress = true;
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
    } finally {
      _isVerifyInProgress = false;
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
    if (_rememberMe && _savedIdentifier != null) {
      sessionMap['identifier'] = _savedIdentifier;
      sessionMap['rememberMe'] = true;
    }
    await SecureSessionStore.saveSession(sessionMap, role: role);
  }

  Future<void> logout() async {
    _setState(AuthState.loggingOut);
    SruAuthClient.instance.clearSession();
    await SecureSessionStore.clearSession();
    _savedIdentifier = null;
    _currentRole = null;
    _setState(AuthState.unauthenticated);
  }
}
