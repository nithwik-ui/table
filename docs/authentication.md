# Authentication Architecture — SRU Timetable 3.0

## 1. Principles
- **Authentication is an Enhancement, NOT a Barrier**: The core app experience (schedule, classes, week view, calendar) must render without requiring an active authenticated session.
- **No Plaintext Passwords**: Passwords must never be stored on device or in logs.
- **Autofill First**: Support native browser and OS credential managers (Google Password Manager, Apple Keychain, Android Autofill) via proper semantic input attributes (`autocomplete="username"`, `autocomplete="current-password"`).
- **Session Decoupling**: SRU portal sessions naturally expire every ~8 hours. This MUST NOT log out the user from the app or wipe their timetable.

## 2. State Machine

```
AuthState
├── unauthenticated   (User hasn't logged in yet)
├── authenticating     (Login request in flight)
├── awaitingOtp        (OTP prompt displayed)
├── authenticated      (Active session verified)
├── sessionExpired     (Portal cookie expired; background sync pauses)
└── authUnavailable    (SRU portal down or unreachable)
```

## 3. Session Expiration Handling
When `SruStudentSource` or `SruAuthClient` detects an expired session:
1. `AuthState` transitions to `sessionExpired`.
2. `TimetableState` remains `cached` (or `stale`).
3. The UI displays an unobtrusive sync warning badge: *"Session expired • Showing saved timetable"*.
4. A re-authentication prompt is offered as an enhancement (e.g., in Profile or sync center), never a full-screen block.
