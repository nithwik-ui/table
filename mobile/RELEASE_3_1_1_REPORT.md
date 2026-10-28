# SRU Timetable 3.1.1 Final Release Report

**Release Target:** SRU Timetable v3.1.1  
**Build Date:** 2026-10-28  
**Artifact:** `D:\sru\mobile\build\release\sru-timetable-3.1.1.apk`  
**Status:** READY FOR RELEASE

---

## 1. Release Identification & Metadata

- **Application ID:** `com.srutimetable.mobile`
- **Version Name:** `3.1.1`
- **Version Code:** `32` (incremented sequentially from `31`)
- **Compile SDK:** 36
- **Signing Keystore:** `android/app/upload-keystore.jks` (Key alias: `upload`, validated via `apksigner`)
- **APK Size:** 62,697,985 bytes (~59.8 MB)
- **APK Path:** `D:\sru\mobile\build\release\sru-timetable-3.1.1.apk`

---

## 2. Architecture & Backend Routing

- **Primary Backend:** Cloudflare Workers (`https://sru-cloudflare-backend.nithwik-ui.workers.dev`)
- **Fallback Backend:** Render (`https://table-ij9g.onrender.com`)
- **Database:** Supabase PostgreSQL
- **Routing Engine:** `BackendRouter` (`mobile/lib/core/backend_router.dart`)
  - Primary Timeout: 8.0 seconds
  - Fallback Timeout: 12.0 seconds
  - Status `< 500` (2xx, 4xx): Returns Cloudflare response immediately without calling Render.
  - Status `>= 500`, DNS failure, or Timeout: Automatically falls over to Render fallback.
  - Double failure: Retains local Hive cache (`sru_timetable_v3_cache`), shows non-blocking indicator, never blanks screen.

---

## 3. Verified Route Status (34 Routes)

| # | Route | Worker Implemented | Cloudflare Status | Render Reference Status |
|---|---|---|---|---|
| 1 | `GET /health` | Yes | 200 OK | Standby Fallback |
| 2 | `GET /api/degrees` | Yes | 200 OK | Standby Fallback |
| 3 | `GET /api/degrees/:degree/years` | Yes | 200 OK | Standby Fallback |
| 4 | `GET /api/degrees/:degree/years/:year/batches` | Yes | 200 OK | Standby Fallback |
| 5 | `GET /api/batches/:batchId/timetable` | Yes | 200 OK | Standby Fallback |
| 6 | `GET /api/batches/:batchId/today` | Yes | 200 OK | Standby Fallback |
| 7 | `GET /api/batches/:batchId/next-class` | Yes | 200 OK | Standby Fallback |
| 8 | `GET /api/batches/:batchId/changes` | Yes | 200 OK | Standby Fallback |
| 9 | `GET /api/faculty/:facultyId/changes` | Yes | 200 OK | Standby Fallback |
| 10 | `POST /api/devices/register` | Yes | 400 Bad Request (Schema Guarded) | Standby Fallback |
| 11 | `POST /api/devices/unregister` | Yes | 400 Bad Request (Schema Guarded) | Standby Fallback |
| 12 | `POST /api/devices/test-notification` | Yes | 400 Bad Request (FCM Guarded) | Standby Fallback |
| 13 | `POST /api/devices/attendance` | Yes | 400 Bad Request (Schema Guarded) | Standby Fallback |
| 14 | `POST /api/admin/pwa-test-notification` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 15 | `POST /api/devices/preferences` | Yes | 400 Bad Request (Schema Guarded) | Standby Fallback |
| 16 | `POST /api/admin/broadcast` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 17 | `GET /api/admin/announcements` | Yes | 200 OK / 401 | Standby Fallback |
| 18 | `POST /api/admin/test-class` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 19 | `DELETE /api/admin/test-class` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 20 | `POST /api/admin/faculty-test-class` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 21 | `DELETE /api/admin/faculty-test-class` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 22 | `GET /api/faculty/list` | Yes | 200 OK | Standby Fallback |
| 23 | `GET /api/faculty/:facultyId/timetable` | Yes | 200 OK | Standby Fallback |
| 24 | `GET /api/rooms/free` | Yes | 200 OK (35 free rooms in slot) | Standby Fallback |
| 25 | `GET /api/admin/faculty` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 26 | `POST /api/admin/faculty` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 27 | `POST /api/admin/faculty/:id/reset` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 28 | `PUT /api/admin/faculty/:id/status` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 29 | `DELETE /api/admin/faculty/:id` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 30 | `GET /api/admin/holidays` | Yes | 200 OK / 401 | Standby Fallback |
| 31 | `POST /api/admin/holidays` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 32 | `PUT /api/admin/holidays/:id` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 33 | `DELETE /api/admin/holidays/:id` | Yes | 401 Unauthorized (Auth Guarded) | Standby Fallback |
| 34 | `GET /api/calendar-overrides` | Yes | 200 OK | Standby Fallback |

---

## 4. Test & Verification Results

### Flutter Client Suite
- **`flutter analyze`:** **0 issues found** (clean baseline).
- **`flutter test`:** **69/69 tests passed** (including unit, widget, failover simulation, autofill, update policy, and repository race protection).

### Cloudflare Worker
- **TypeScript Typecheck:** `npm run typecheck` (`tsc --noEmit`) → **0 errors**.
- **Wrangler Dry-Run Deploy:** `wrangler deploy --dry-run --outdir dist` → **0 errors** (1018.53 KiB upload bundle).
- **FCM Web Crypto Engine:** `src/lib/fcm.ts` implemented using native `crypto.subtle` (no `firebase-admin` dependency).
- **Scheduled Cron Trigger:** `0 * * * *` configured in `wrangler.jsonc`.

### Failure Simulation Tests
- Cloudflare 200: Served directly.
- Cloudflare 400/401/404/429: Returned directly, no fallback triggered.
- Cloudflare 500/503/Timeout/SocketException: Render failover executed smoothly.
- Both Backends Down: Graceful error propagation with Hive cache retention.

### Storage & Offline Cache
- Fully isolated v3 namespaces: `sru_timetable_v3_prefs` and `sru_timetable_v3_cache`.
- Cached timetable renders instantly upon app open.
- Offline pull-to-refresh preserves existing cached cards.

### Authentication State
- Separate `AuthState` machine independent of timetable display.
- SRUNIV & SRAAP credentials managed securely with native autofill.
- Explicit logout purges stored session cookies and roll numbers.

---

## 5. Security Audit Findings

- No hardcoded API keys, private keys, or passwords committed to Git.
- Single Banner Ad only (`ca-app-pub-4600395533739943~6015744970`). No intrusive ad formats.
- `launchMode="singleTask"` configured to prevent black screens and multi-instance stacking.
- Google Password Manager & Safari Keychain standard autofill supported via `AutofillGroup`.

---

## 6. Real Device Install Verification

- **ADB Status:** `DEVICE INSTALL TEST NOT AVAILABLE` (no physical Android device or emulator currently attached to test host).
- **Static Verification:** Performed using Android SDK Build-Tools 28.0.3 (`aapt dump badging` and `apksigner verify -v`). Validated package `com.srutimetable.mobile`, `versionCode=32`, `versionName=3.1.1`, and upload key signature.

---

## 7. Known Remaining Risks

1. **Render Free-Tier Standby:** The Render fallback backend (`table-ij9g.onrender.com`) is on free tier and may sleep after inactivity (~50s cold start). Cloudflare Workers handle primary traffic (<50ms response), and Hive offline cache shields the user if both are slow.
2. **SRUNIV University Server Reliability:** SRUNIV website periodically suffers upstream timeouts or CAPTCHA resets during semester registration windows; the app gracefully reports session expiry without wiping the stored timetable.
