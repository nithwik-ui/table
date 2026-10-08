/// All possible states the SRAAP authentication session can be in.
enum SraapSessionState {
  /// SRAAP has never been connected or has been explicitly disconnected.
  notConnected,

  /// The login flow is in progress.
  authenticating,

  /// A valid session exists and academic data can be fetched.
  connected,

  /// Checking whether the existing stored session is still valid.
  checkingSession,

  /// SRAAP server has returned a session-expired or unauthorized response.
  sessionExpired,

  /// Credentials were rejected by SRAAP (wrong enrollment or password).
  authError,

  /// CAPTCHA was submitted but SRAAP rejected it.
  captchaError,

  /// SRAAP portal itself is down or returning unexpected errors.
  portalUnavailable,

  /// Device has no internet connectivity.
  networkError,
}
