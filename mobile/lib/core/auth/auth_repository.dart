import 'package:flutter/foundation.dart';
import 'auth_state.dart';
import 'secure_session_store.dart';
import '../sru/sru_auth_client.dart';
import '../storage.dart';
import '../sraap/sraap_session_manager.dart';
import '../sraap/sraap_academic_service.dart';

class AuthRepository extends ChangeNotifier {
  static final AuthRepository instance = AuthRepository._();
  AuthRepository._();

  AuthState _state = AuthState.unauthenticated;
  AuthState get state => _state;

  String? _currentRole;
  String? get currentRole => _currentRole;

  String? _savedIdentifier;
  String? get savedIdentifier => _savedIdentifier;
  String? _savedPassword;
  bool _rememberMe = true;
  DateTime? _lastOtpRequestedAt;

  int get otpCooldownSecondsRemaining {
    if (_lastOtpRequestedAt == null) return 0;
    final elapsed = DateTime.now().difference(_lastOtpRequestedAt!).inSeconds;
    final remaining = 60 - elapsed;
    return remaining > 0 ? remaining : 0;
  }

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
    final cachedRole = targetRole ?? StorageService.getUserMode();
    if (cachedRole == null || cachedRole.isEmpty) {
      _currentRole = null;
      _savedIdentifier = null;
      _savedPassword = null;
      _setState(AuthState.unauthenticated);
      return;
    }

    final sessionData = await SecureSessionStore.getSession(role: cachedRole);

    if (sessionData != null && 
        sessionData['cookie'] != null && 
        (sessionData['cookie'] as String).trim().isNotEmpty) {
      SruAuthClient.instance.restoreCookies(sessionData['cookie']);
      _currentRole = sessionData['role'] ?? cachedRole;
      await StorageService.setUserMode(_currentRole!);

      if (sessionData['identifier'] != null) {
        _savedIdentifier = sessionData['identifier'];
      }
      if (sessionData['password'] != null) {
        _savedPassword = sessionData['password'];
      }

      _setState(AuthState.authenticated);
      _setState(AuthState.ready);
      return;
    } else {
      _currentRole = null;
      _savedIdentifier = null;
      _savedPassword = null;
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
      if (_savedPassword != null && _savedPassword!.isNotEmpty) {
        sessionMap['password'] = _savedPassword;
      }
    }
    await SecureSessionStore.saveSession(sessionMap, role: role);
  }

  Future<bool> hasSavedCredentials({String? role}) async {
    final targetRole = role ?? _currentRole ?? StorageService.getUserMode() ?? 'student';
    final sessionData = await SecureSessionStore.getSession(role: targetRole);
    if (sessionData == null) return false;
    final id = sessionData['identifier']?.toString();
    final pass = sessionData['password']?.toString() ?? _savedPassword;
    return id != null && id.isNotEmpty && pass != null && pass.isNotEmpty;
  }

  Future<void> clearSavedPassword({String? role}) async {
    _savedPassword = null;
    final targetRole = role ?? _currentRole ?? StorageService.getUserMode() ?? 'student';
    final sessionData = await SecureSessionStore.getSession(role: targetRole);
    if (sessionData != null) {
      sessionData.remove('password');
      await SecureSessionStore.saveSession(sessionData, role: targetRole);
    }
  }

  /// Safe, explicit user-triggered session renewal via OTP.
  /// Strictly non-automatic: never invoked from background syncs or timers.
  Future<Map<String, dynamic>> renewSessionWithOtp({String? role}) async {
    final cooldown = otpCooldownSecondsRemaining;
    if (cooldown > 0) {
      return {
        'status': 'cooldown',
        'remainingSeconds': cooldown,
        'message': 'Please wait $cooldown seconds before requesting another OTP.',
      };
    }

    final targetRole = role ?? _currentRole ?? StorageService.getUserMode() ?? 'student';
    final sessionData = await SecureSessionStore.getSession(role: targetRole);
    final id = sessionData?['identifier']?.toString() ?? _savedIdentifier;
    final pass = sessionData?['password']?.toString() ?? _savedPassword;

    if (id == null || id.isEmpty || pass == null || pass.isEmpty) {
      return {
        'status': 'no_credentials',
        'message': 'Saved credentials not found. Please log in with password.',
      };
    }

    _savedIdentifier = id;
    _savedPassword = pass;
    _currentRole = targetRole;

    _setState(AuthState.authenticating);
    try {
      final result = await SruAuthClient.instance.login(id, pass);
      _lastOtpRequestedAt = DateTime.now();

      if (result['status'] == 'otp_required') {
        _setState(AuthState.awaitingOTP);
        return {
          'status': 'otp_required',
          'message': 'OTP sent to your registered mobile/email.',
        };
      } else if (result['status'] == 'authenticated') {
        await _saveSession();
        _setState(AuthState.authenticated);
        _setState(AuthState.ready);
        return {
          'status': 'authenticated',
          'message': 'Session renewed successfully.',
        };
      }
      return {
        'status': 'unknown',
        'message': 'Unexpected response from university server.',
      };
    } on SruAuthException catch (e) {
      _setState(AuthState.authenticationError);
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('password') || msg.contains('credential')) {
        // Clear stale password to prevent repeated failed attempts & account lockouts
        await clearSavedPassword(role: targetRole);
        return {
          'status': 'credential_error',
          'message': 'Your university password appears to have changed. Please log in again.',
        };
      }
      return {
        'status': 'error',
        'message': e.message,
      };
    } catch (e) {
      _setState(AuthState.networkError);
      return {
        'status': 'network_error',
        'message': 'Unable to connect to university server. Please check your network.',
      };
    }
  }

  Future<void> logout() async {
    _setState(AuthState.loggingOut);
    SruAuthClient.instance.clearSession();
    await SecureSessionStore.clearSession();
    await SraapSessionManager.instance.clearSession();
    await SraapAcademicService.instance.disconnect();
    await StorageService.fullLogout();
    _savedIdentifier = null;
    _savedPassword = null;
    _currentRole = null;
    _setState(AuthState.unauthenticated);
  }
}
