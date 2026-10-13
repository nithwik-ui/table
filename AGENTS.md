# AGENTS.md — Non-Negotiable AI Engineering Rules for SRU Timetable 3.0

This file contains the strict operational boundaries, architectural contracts, and safety rules for any AI agent or engineer working on the SRU Timetable 3.0 codebase.

---

## 1. Absolute Invariants

1. **NEVER Guess SRU API Endpoints**:
   - Do NOT invent paths, query parameters, or payload schemas.
   - Any SRU endpoint must be established from actual source code, Chrome DevTools Network captures, or explicit authoritative documentation.

2. **NEVER Bypass SRU Authentication or Security Controls**:
   - Do NOT bypass OTP, CSRF tokens, session verification, rate limits, or cookies.
   - Respect university access controls.

3. **Authentication is OPTIONAL for Timetable Display**:
   - The primary app experience (Home, Today's Classes, Next Class, Week Schedule, Changes, Calendar) MUST render immediately from local storage.
   - An expired session, missing credentials, or network failure must NEVER cause a blank screen (`CircularProgressIndicator` forever or empty UI).
   - Show cached data + a subtle, non-blocking sync status banner ("Sync unavailable" / "Showing saved timetable").

4. **Hard Reset for 2.0 → 3.0 Migration**:
   - App schema version: `3`.
   - Data namespace: `sru_timetable_v3` (isolated Hive boxes `sru_timetable_v3_prefs`, `sru_timetable_v3_cache`).
   - Old 2.0 storage (`sru_timetable_prefs`, `sru_timetable_cache`) is detected and ignored/archived, never merged blindly. No broken 2.0 session state is carried over.

5. **Decoupled Auth & Timetable State Machines**:
   - `AuthState`: `unauthenticated`, `authenticating`, `authenticated`, `sessionExpired`, `authUnavailable`.
   - `TimetableState`: `empty`, `loading`, `cached`, `syncing`, `fresh`, `stale`, `error`.
   - `AuthState.sessionExpired` MUST NOT transition `TimetableState` to `empty`. It transitions to `stale` while retaining cached classes.

6. **Shared Timetable State Across Tabs**:
   - `HomeTab`, `WeekTab`, `AcademicTab`, `ChangesTab`, `ProfileTab` must all consume a single shared `TimetableRepository` / `TimetableController`.
   - Switching tabs MUST NEVER trigger network requests, re-authentication, or data re-fetching.

7. **Safe Refresh Semantics**:
   - Pull-to-refresh must NEVER clear existing timetable data before a network fetch completes.
   - If network sync succeeds: atomically replace cache and notify UI.
   - If network sync fails: retain existing cache, show non-blocking feedback, never wipe the screen.
   - Always enforce strict timeouts (e.g. 10–15s).

8. **Credential & Password Vault Privacy**:
   - NEVER programmatically access Google Password Manager or Apple Passwords.
   - Use standard browser/PWA autofill attributes (`autocomplete="username"`, `autocomplete="current-password"`, `autocomplete="one-time-code"`).
   - NEVER request user email scraping permissions for OTP.
   - NEVER store passwords in plaintext or log credentials/cookies/tokens.

9. **AdMob Lifecycle & Rules**:
   - **Banner Ads ONLY**: No interstitial, rewarded, app-open, or popup ads.
   - Centralize banner lifecycle via `AdService`. Do not instantiate or destroy banners on every widget rebuild or tab switch.
   - Fix `launchMode="singleTask"` in `AndroidManifest.xml` to prevent task stacking and black screens upon returning from ads.

10. **Non-Blocking Background Services**:
    - FCM, AdMob, updater checks, and analytics must never block app launch or initial timetable render (< 100–300ms target).

---

## 2. Verification Protocol

Before declaring any task or phase complete:
1. Run `flutter analyze` in `mobile/`.
2. Run automated tests in `mobile/test/`.
3. Verify web/PWA build (`flutter build web`).
4. Validate offline resilience, tab switching, and cached rendering.
