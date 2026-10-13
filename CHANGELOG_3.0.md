# CHANGELOG_3.0.md — Engineering Audit & Recovery Changelog

## 3.0.0 Architecture Recovery (In Progress)

### P0 — Data Architecture & Cache-First Timetable
- Created unified `TimetableRepository` with reactive `ChangeNotifier`.
- Instant rendering from local cache target: < 100–300ms.
- Timetable data decoupled from network synchronization.

### P0 — Authentication Isolation
- Decoupled `AuthState` (`unauthenticated`, `authenticating`, `authenticated`, `sessionExpired`, `authUnavailable`) from `TimetableState`.
- Expired session no longer blanks or blocks the timetable; cached timetable remains fully interactive.
- Stale status badge displayed when session is expired or network is unreachable.

### P0 — Tab State Sharing
- Removed independent timetable fetches in `HomeTab`, `WeekTab`, `AcademicTab`, and `ChangesTab`.
- All dashboard views now consume shared `TimetableRepository` state.

### P1 — Storage Isolation (2.0 → 3.0 Hard Reset)
- Separated Hive boxes into `sru_timetable_v3_prefs` and `sru_timetable_v3_cache`.
- Guaranteed isolation from legacy V2 data, preventing session corruption and repetitive re-login loops.

### P1 — AdMob Lifecycle Stabilization
- Refactored `AdBanner` and `AdService` to maintain a single banner instance across tabs.
- Eliminated redundant banner creation/destruction on tab switches and page rebuilds.
- Updated `AndroidManifest.xml` `launchMode` to `singleTask` to eliminate task-switching glitches.

### P1 — PWA & Web Autofill
- Added standard web password manager autofill support (`username`, `current-password`, `one-time-code`).
- Ensured non-blocking background initialization on web and mobile.
