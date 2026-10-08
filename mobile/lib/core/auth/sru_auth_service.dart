enum AuthState {
  loggedOut,
  roleSelected,
  authenticating,
  otpRequired,
  authenticated,
  profileLoading,
  timetableSyncing,
  ready,
  error
}

class SruSession {
  final String token;
  final DateTime expiresAt;
  final String role; // 'student' or 'faculty'

  SruSession({
    required this.token,
    required this.expiresAt,
    required this.role,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

abstract class SruAuthService {
  Future<SruSession> login(String identifier, String password);
  Future<SruSession> verifyOtp(String otp, String trackingId);
  Future<void> logout();
  Future<bool> validateSession(SruSession session);
  Future<Map<String, dynamic>> fetchProfile(SruSession session);
}
