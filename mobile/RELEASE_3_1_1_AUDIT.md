# SRU Timetable 3.1.1 Production-Readiness Audit Report

**Date:** 2026-10-28  
**Release Target:** SRU Timetable v3.1.1  
**Target Platform:** Flutter Mobile (Android APK) & PWA  
**Status:** AUDIT PASSED — READY FOR RELEASE CANDIDATE BUILD

---

## 1. Executive Summary & Architecture Overview

SRU Timetable 3.1.1 introduces full Cloudflare Workers backend integration as the primary serverless API, with Render maintained as an isolated fallback, while keeping student/faculty authentication flows directly attached to university endpoints (SRUNIV / SRAAP).

```
                            SRU TIMETABLE 3.1.1
                             │ Flutter / PWA │
                      ┌──────┴───────────────┴──────┐
                      │                             │
                 Student Auth                  Public APIs
                      │                             │
                      ▼                             ▼
              SRUNIV Direct Auth              BackendRouter
                                            ┌───────┴───────┐
                                            │               │
                                            ▼               ▼
                                       Cloudflare         Render
                                        PRIMARY          FALLBACK
                                            │               │
                                            └───────┬───────┘
                                                    ▼
                                                 Supabase
```

### Architectural Contracts
1. **Decoupled Auth & Timetable State Machines:** `AuthState` (`unauthenticated`, `authenticating`, `authenticated`, `sessionExpired`, `authUnavailable`) is completely decoupled from `TimetableState` (`empty`, `loading`, `cached`, `syncing`, `fresh`, `stale`, `error`). Session expiration NEVER blanks the screen or destroys cached timetable data.
2. **BackendRouter Failover Contract:**
   - Cloudflare `2xx`: Return Cloudflare response immediately.
   - Cloudflare `4xx` (400, 401, 403, 404, 429): Return client error response immediately; DO NOT fallback to Render.
   - Cloudflare `5xx` (500, 502, 503, 504), SocketException, TimeoutException: Automatically fail over to Render.
   - Render Failure: Retain local Hive cached data (`sru_timetable_v3_cache`), show non-blocking indicator, never blank screen.
3. **No Plaintext Secrets:** Passwords, OTPs, session cookies, and service keys are never stored in plaintext or logged. Native autofill (`AutofillGroup`) is enforced.
4. **AdMob Policy Compliance:** Single Banner Ad only (`ca-app-pub-4600395533739943~6015744970`). No interstitials, popups, or rewarded ads. `launchMode="singleTask"` configured to prevent black screens.

---

## 2. Version Audit

- **Previous Version:** `3.0.0+31`
- **Target Release Version Name:** `3.1.1`
- **Target Release Version Code:** `32` (incremented valid integer)
- **Files Synchronized:**
  - `D:\sru\mobile\pubspec.yaml` → `version: 3.1.1+32`
  - `D:\sru\mobile\lib\core\constants.dart` → `static const String currentVersion = '3.1.1';`
  - `D:\sru\mobile\android\app\build.gradle.kts` → reads `flutter.versionCode` and `flutter.versionName` automatically.

---

## 3. Backend Endpoints & Route Matrix (34 Verified Routes)

**Primary:** `https://sru-cloudflare-backend.nithwik-ui.workers.dev`  
**Fallback (Reference):** `https://table-ij9g.onrender.com`

| # | Route | Worker Implemented | Verified Status | Cloudflare Behavior | Render Comparison / Fallback Note |
|---|---|---|---|---|---|
| 1 | `GET /health` | Yes | PASS | `200 OK {"status":"ok","timestamp":"..."}` | Render reference returns 200 OK |
| 2 | `GET /api/degrees` | Yes | PASS | `200 OK` (returns list of active degrees) | Render fallback available |
| 3 | `GET /api/degrees/:degree/years` | Yes | PASS | `200 OK` (e.g. `/api/degrees/BTECH/years`) | Render fallback available |
| 4 | `GET /api/degrees/:degree/years/:year/batches` | Yes | PASS | `200 OK` (returns active batches) | Render fallback available |
| 5 | `GET /api/batches/:batchId/timetable` | Yes | PASS | `200 OK` (with valid batch UUID / code) | Render fallback available |
| 6 | `GET /api/batches/:batchId/today` | Yes | PASS | `200 OK` (IST filtered timetable for today) | Render fallback available |
| 7 | `GET /api/batches/:batchId/next-class` | Yes | PASS | `200 OK` (next upcoming class slot) | Render fallback available |
| 8 | `GET /api/batches/:batchId/changes` | Yes | PASS | `200 OK` (active cancellations/substitutions) | Render fallback available |
| 9 | `GET /api/faculty/:facultyId/changes` | Yes | PASS | `200 OK` (faculty specific schedule changes) | Render fallback available |
| 10 | `POST /api/devices/register` | Yes | PASS | `400 Bad Request` on empty body; `200 OK` on valid payload | Validated schema check |
| 11 | `POST /api/devices/unregister` | Yes | PASS | `400 Bad Request` on empty body; `200 OK` on token unregister | Validated schema check |
| 12 | `POST /api/devices/test-notification` | Yes | PASS | `400 Bad Request` on empty payload; Web Crypto FCM triggered | Uses HTTP v1 FCM |
| 13 | `POST /api/devices/attendance` | Yes | PASS | `400 Bad Request` without device token | Validated schema check |
| 14 | `POST /api/admin/pwa-test-notification` | Yes | PASS | `401 Unauthorized` without admin auth | Secure endpoint |
| 15 | `POST /api/devices/preferences` | Yes | PASS | `400 Bad Request` without token/preferences | Validated schema check |
| 16 | `POST /api/admin/broadcast` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 17 | `GET /api/admin/announcements` | Yes | PASS | `200 OK` / `401` depending on credentials | Handled securely |
| 18 | `POST /api/admin/test-class` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 19 | `DELETE /api/admin/test-class` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 20 | `POST /api/admin/faculty-test-class` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 21 | `DELETE /api/admin/faculty-test-class` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 22 | `GET /api/faculty/list` | Yes | PASS | `200 OK` (returns faculty directory) | Supabase verified |
| 23 | `GET /api/faculty/:facultyId/timetable` | Yes | PASS | `200 OK` (returns faculty schedule) | Supabase verified |
| 24 | `GET /api/rooms/free` | Yes | PASS | `200 OK` (returns free rooms for IST day/time slot) | Supabase verified |
| 25 | `GET /api/admin/faculty` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 26 | `POST /api/admin/faculty` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 27 | `POST /api/admin/faculty/:id/reset` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 28 | `PUT /api/admin/faculty/:id/status` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 29 | `DELETE /api/admin/faculty/:id` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 30 | `GET /api/admin/holidays` | Yes | PASS | `200 OK` / `401` based on token | Verified |
| 31 | `POST /api/admin/holidays` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 32 | `PUT /api/admin/holidays/:id` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 33 | `DELETE /api/admin/holidays/:id` | Yes | PASS | `401 Unauthorized` without admin auth | Admin role guarded |
| 34 | `GET /api/calendar-overrides` | Yes | PASS | `200 OK` (returns academic calendar overrides) | Verified |

---

## 4. BackendRouter Audit & Failure Simulation

`BackendRouter` (`lib/core/backend_router.dart`):
- **Cloudflare Primary Timeout:** 8.0 seconds (`primaryTimeout = Duration(seconds: 8)`)
- **Render Fallback Timeout:** 12.0 seconds (`fallbackTimeout = Duration(seconds: 12)`)
- **Automated Failover Suite:** 12 unit tests in `test/backend_router_failure_simulation_test.dart`:
  1. Cloudflare 200 OK: Returns Cloudflare response immediately, does NOT call Render.
  2. Cloudflare 400 Bad Request: Returns 400 immediately, does NOT fallback.
  3. Cloudflare 401 Unauthorized: Returns 401 immediately, does NOT fallback.
  4. Cloudflare 404 Not Found: Returns 404 immediately, does NOT fallback.
  5. Cloudflare 429 Rate Limited: Returns 429 immediately, does NOT fallback.
  6. Cloudflare 500 Internal Error: Automatically falls back to Render.
  7. Cloudflare 503 Service Unavailable: Automatically falls back to Render.
  8. Cloudflare SocketException (DNS / Network down): Automatically falls back to Render.
  9. Cloudflare TimeoutException (>8s delay): Automatically falls back to Render.
  10. Both Cloudflare & Render down: Throws exception, permitting UI/Repository to retain cached data.
  11. POST request 200: Returns Cloudflare response directly.
  12. POST request 500: Automatically falls back to Render.

---

## 5. Cache & Offline Resilience Audit

- **Isolated Hive Namespaces:**
  - `sru_timetable_v3_prefs`
  - `sru_timetable_v3_cache`
  - Completely separate from legacy v2 storage boxes.
- **Cache Persistence & Fallback:**
  - Pull-to-refresh or background sync never zeroes the cache prior to fetch.
  - If network or server fails, existing cached data remains displayed with a subtle offline status indicator.
  - Refresh replaces data atomically upon 200 OK.
  - Out-of-order race conditions guarded by generation counters (`_refreshGeneration`).

---

## 6. Authentication & Security Audit

1. **State Isolation:**
   - SRUNIV student login and SRAAP faculty login remain completely separate from public timetable retrieval.
   - Authenticated sessions use HTTP cookies and native `AutofillGroup`.
   - App restart without active session defaults to `AuthState.unauthenticated`.
   - Logout clears all stored session identifiers and returns user to onboarding role selection.
2. **Secrets Scanning:**
   - No hardcoded passwords, private keys, or API secrets found in source repository.
   - `.env`, `.dev.vars`, and credentials files are untracked and excluded in `.gitignore`.
3. **PWA Integration:**
   - iOS/iPad standalone PWA gate preserved.
   - Touch interactions, safe areas, and bottom navigation tested for desktop/tablet/mobile screens.

---

## 7. Quality Assurance & Regression Test Suite

- **`flutter analyze`:**
  ```
  Analyzing mobile...
  No issues found! (ran in 9.1s)
  ```
  **0 warnings, 0 errors, 0 lints.**

- **`flutter test`:**
  ```
  00:13 +69: All tests passed!
  ```
  **69/69 automated unit & widget tests passed.**

- **Cloudflare Worker Typecheck:**
  ```
  npm run typecheck -> 0 errors
  ```

- **Cloudflare Worker Dry-Run Deploy:**
  ```
  wrangler deploy --dry-run --outdir dist -> 0 errors (Total Upload: 1018.53 KiB)
  ```

---

## 8. Android Release Configuration

- **Application ID:** `com.srutimetable.mobile`
- **Keystore:** `android/app/upload-keystore.jks`
- **Properties:** `android/key.properties` configured for release build signing.
- **Activity Launch Mode:** `launchMode="singleTask"` (prevents black screens when returning from ads).
- **ProGuard / R8:** Enabled via `proguard-rules.pro` and `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))`.

---

## 9. Release Blockers

**None.** All criteria satisfied. The codebase is verified ready for final production release artifact generation.
