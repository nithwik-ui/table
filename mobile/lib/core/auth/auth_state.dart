enum AuthState {
  unauthenticated,
  authenticating,
  awaitingOTP,
  verifyingOTP,
  authenticated,
  restoringSession,
  sessionExpired,
  refreshingSession,
  loggingOut,
  authenticationError,
  networkError,
  profileLoading,
  profileReady,
  timetableSyncing,
  ready
}
