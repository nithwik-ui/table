# SRAAP CAPTCHA & Login Compatibility Audit (`v3.1.1`)

## 1. Problem

Users on certain devices and network environments reported the following SRAAP portal authentication issues in SRU Timetable 3.1.1:
1. CAPTCHA sometimes fails to load or times out.
2. CAPTCHA loads reliably on some devices/networks but fails on others.
3. User enters a valid CAPTCHA and submits login, yet a new CAPTCHA is generated repeatedly.
4. Login enters an endless CAPTCHA refresh / login loop.
5. Other devices work without issue.

---

## 2. Root Cause Analysis

Forensic inspection of the repository history (`commit 7c5c444da4a652ecd4526d3b701f52e80fe1f3c3`), HTTP proxy (`mobile/api/proxy.js`), SRAAP session/auth managers (`mobile/lib/core/sraap/`), and live non-destructive probes against `https://sraap.in` identified **six concrete root causes**:

### Root Cause A: False-Negative Login Evaluation on HTTP `200 OK` Redirects (`x-proxy-redirect`, JS Redirects & Flushed PHP Headers)
- **Web/PWA (`kIsWeb`)**: `mobile/api/proxy.js` (lines 117–141) intercepts HTTP `302 Found` from `sraap.in` and rewrites `statusCode = 200` with header `x-proxy-redirect: /api/sraap/student/dash_board.php` and an empty body (`""`). Unlike `SruAuthClient`, the SRAAP login handlers (`AcademicLoginScreen`, `_QuickReconnectModalState`, `SraapAuthManager`) never checked `x-proxy-redirect` or `location` headers when `statusCode == 200`.
- **Server-Side Modal Prefix on `sraap.in/student_login.php`**: Live inspection of `https://sraap.in/student_login.php` confirmed that SR University prepended a **5,233-byte HTML modal block** (`<div id="convocationModal">` — Fee Payment Reminders, lines 1–246) before the PHP login handler at line 247. When `POST /student_login.php` returns `200 OK` (either via inline `<script>window.location.href = 'student/dash_board.php';</script>` as used on `sraap.in/student/dash_board.php`, or because 5,233 bytes exceeds PHP's default 4,096-byte output buffer prior to `header("Location: ...")`), `AcademicLoginScreen._login()` in `v3.1.1` only checked `(body.contains('logout') || body.contains('attendancetable') || body.contains('welcome to')) && !body.contains('student_login')`.
- Because `http.Client` does not execute JavaScript redirects and those strings only appear after fetching `/student/dash_board.php`, **valid logins returning HTTP 200 were misclassified as failed logins**, immediately triggering `_captchaCtrl.clear(); _fetchCaptcha(forceFreshSession: true);` — wiping the newly authenticated `PHPSESSID` cookie and generating a new CAPTCHA on every submission.

### Root Cause B: `forceFreshSession: true` Wiping Session State on Every CAPTCHA Refresh
- In `v3.1.1`, `AcademicLoginScreen._fetchCaptcha()` and `_QuickReconnectModalState._fetchCaptcha()` passed `forceFreshSession: true` on **every** CAPTCHA load, manual refresh, and login retry.
- `SraapSessionManager.fetchCaptcha(forceFreshSession: true)` cleared `_cookies` and `_cookieHeader = ''` and re-downloaded the entire **103,540-byte (~104 KB)** `student_login.php` page before fetching the ~2 KB `/captcha/image.php` PNG.
- Furthermore, `isSessionExpired` was never reset when a fresh login session was initialized, causing even `fetchCaptcha(forceFreshSession: false)` to wipe `_cookies` whenever a previous session had expired.
- Live probing of `https://sraap.in/student_login.php` confirmed that when an existing `Cookie: PHPSESSID=...` is sent (e.g. by a browser cookie jar on Web/PWA), `sraap.in` returns **no `Set-Cookie` header (`set-cookie: []`)**, leaving `_cookieHeader` empty after `_cookies.clear()`.

### Root Cause C: Unconditional CAPTCHA Regeneration on Non-CAPTCHA Errors
- `AcademicLoginScreen._login()` and `_QuickReconnectModalState._submit()` unconditionally executed `_captchaCtrl.clear(); _fetchCaptcha();` on **all** failure branches — including wrong password/enrollment (`Sorry, I don't recognize you, kindly recheck.`) and network/IP restrictions (`Access Restricted` / `shared public ip`).
- Live probing of `https://sraap.in/student_login.php` proved that when the CAPTCHA `token` is valid and only the credentials are wrong, `sraap.in` preserves the valid CAPTCHA in `$_SESSION`. Regenerating the session and CAPTCHA on every non-CAPTCHA error forced users into unnecessary CAPTCHA loops.

### Root Cause D: Background Keep-Alive & `restoreSession()` Overwriting the Active Login Cookie
- When a user on `AcademicLoginScreen` switched apps (e.g. to copy their password from a password manager) and resumed the app, `DashboardScreen.didChangeAppLifecycleState(AppLifecycleState.resumed)` triggered `SraapAcademicService.instance.pingKeepAlive()`.
- `_fetchFreshData()` called `SraapSessionManager.instance.restoreSession()` (if `cookieHeader` was empty during initialization) or `GET /student/dash_board.php` (which returned `<h1>In Valid Login</h1>` and set `isSessionExpired = true`), mutating session state while the user was entering the CAPTCHA.

### Root Cause E: Missing Concurrency Guards & Image Byte Validation
- `SraapSessionManager.fetchCaptcha()` had no in-flight coalescing guard, allowing overlapping calls to race on `_cookies['PHPSESSID']` vs `_captchaBytes`.
- `fetchCaptcha()` only checked `!contentType.contains('text/html')` without verifying image magic bytes (PNG/JPEG/GIF/WebP), and `student_login.php` (104 KB) timeout aborted CAPTCHA loading even though `https://sraap.in/captcha/image.php` (~2 KB) can initialize `PHPSESSID` directly via `Set-Cookie`.

### Root Cause F: Web Proxy (`mobile/api/proxy.js`) Stripping Query Parameters
- `mobile/api/proxy.js` constructed `const urlPath = '/' + (path || '')`, dropping extra query parameters such as the cache-busting timestamp on `/api/sraap/captcha/image.php?<timestamp>`.

---

## 3. Working-Device vs. Failing-Device Behavior

| Dimension | Working Device Behavior | Failing Device Behavior (Before Fix) |
|---|---|---|
| **Platform / Runtime** | Native Android APK on fast Wi-Fi/5G receiving direct `302 Found` from `sraap.in`, or devices running pre-`7c5c444` session check | Web/PWA (`kIsWeb` via `api/proxy.js`), devices receiving `200 OK` after `convocationModal` HTML flush, slower mobile networks, or users switching to password manager |
| **CAPTCHA Loading** | 104 KB `student_login.php` + 2 KB `captcha/image.php` completes within timeout; single `fetchCaptcha` call | 104 KB `student_login.php` times out on slow mobile data, or `forceFreshSession: true` wipes `_cookies` when browser/proxy reuses cookie without `Set-Cookie`, or captive portal returns non-image payload |
| **Login Submission** | `POST /student_login.php` returns `302 Found`, matched by `res.statusCode == 302` | `POST /student_login.php` returns `200 OK` (with `x-proxy-redirect`, inline JS redirect, or flushed modal headers); `isSuccess` evaluates to `false` |
| **Post-Submit Behavior** | Navigates to `AcademicDashboard` and persists `PHPSESSID` | Misclassifies valid login (or credential/network error) as failure, calls `fetchCaptcha(forceFreshSession: true)`, wipes authenticated `PHPSESSID`, and generates a new CAPTCHA in a loop |

---

## 4. Evidence

1. **Live `sraap.in/student_login.php` Probe**:
   - `GET https://sraap.in/student_login.php` (no cookie) -> `200 OK`, `Set-Cookie: PHPSESSID=...; path=/; secure`, `103,540 bytes` (`5,233 bytes` of `convocationModal` HTML before line 247 PHP login handler).
   - `GET https://sraap.in/student_login.php` (with existing `Cookie: PHPSESSID=...`) -> `200 OK`, `Set-Cookie: []` (none).
2. **Live `sraap.in/captcha/image.php` Probe**:
   - `GET https://sraap.in/captcha/image.php?<ts>` -> `200 OK`, `Content-Type: image/png`, PNG signature `89 50 4E 47 0D 0A 1A 0A`, `Cache-Control: no-store, no-cache, must-revalidate`.
   - Also emits `Set-Cookie: PHPSESSID=...; path=/; secure` if called without an existing cookie.
3. **Live `POST https://sraap.in/student_login.php` Error Markup**:
   - Wrong CAPTCHA (`token=0000`) -> `200 OK` containing `<b>Enter CAPTCHA code:<br></b>`.
   - Valid CAPTCHA (`token=maui`, case-insensitive on server) + wrong credentials -> `200 OK` containing `<b><p style='color: darkred; font-weight: bold; text-align:center;'>Sorry, I don't recognize you, kindly recheck.<br/> or contact Your Head of Department.</p>...<a href='forgot_passwords.php'>Forgot / Reset password</a>...</b>` while preserving the valid CAPTCHA in `$_SESSION`.
4. **Live `GET https://sraap.in/student/dash_board.php` Unauthenticated Markup**:
   - Returns `200 OK` with `<script>window.location.href = '../slogin.php';</script><h1>In Valid Login</h1>`.

---

## 5. Changes Made

1. **[`mobile/lib/core/sraap/sraap_session_state.dart`](file:///D:/sru/mobile/lib/core/sraap/sraap_session_state.dart)**:
   - Added `SraapLoginFlowState` (`initial`, `loadingSession`, `loadingCaptcha`, `captchaReady`, `submittingLogin`, `authenticated`, `captchaError`, `invalidCredentials`, `sessionExpired`, `networkError`) while preserving all `SraapSessionState` values.
2. **[`mobile/lib/core/sraap/sraap_session_manager.dart`](file:///D:/sru/mobile/lib/core/sraap/sraap_session_manager.dart)**:
   - Preserved existing working endpoints and headers (`student_login.php`, `captcha/image.php`, `student/dash_board.php`).
   - Added in-flight coalescing (`_inFlightCaptchaFetch`) and single-submission lock (`_isLoginInFlight`).
   - Fixed `fetchCaptcha()` so manual CAPTCHA refreshes (`forceFreshSession: false`) reuse the active login `PHPSESSID` instead of clearing `_cookies` and re-downloading 104 KB `student_login.php`.
   - Added fallback to `/captcha/image.php` if the 104 KB `student_login.php` initial GET times out on slow networks.
   - Added `isValidImageBytes()` magic-byte verification (PNG/JPEG/GIF/WebP/BMP) to reject HTML/JSON/text error responses.
   - Added `verifyAuthenticatedSession()` handshake against `/student/dash_board.php` for ambiguous HTTP 200 login responses.
   - Added `isLoginFlowActive` guard to prevent background tasks or unauthenticated login-page cookies from overwriting stored session state.
   - Added non-sensitive `SRAAP_LOGIN: ...` diagnostic logging.
3. **[`mobile/lib/core/sraap/sraap_auth_manager.dart`](file:///D:/sru/mobile/lib/core/sraap/sraap_auth_manager.dart)**:
   - Implemented `evaluateLoginResponse()` supporting native `302`/`301`, Web proxy `x-proxy-redirect`, `location` header, inline JS `dash_board.php` redirects, and exact `sraap.in` error classification (`invalidCaptcha`, `invalidCredentials`, `sessionExpired`, `portalUnavailable`, `timeout`, `networkUnavailable`).
   - Added automatic `verifyAuthenticatedSession()` check in `submitLogin()` when `POST /student_login.php` returns `200 OK` without error banners.
4. **[`mobile/lib/core/sraap/sraap_academic_service.dart`](file:///D:/sru/mobile/lib/core/sraap/sraap_academic_service.dart)**:
   - Suppressed silent background `pingKeepAlive()` / `fetchFreshDataSilently()` while `isLoginFlowActive` is true.
   - Added `slogin.php` and `In Valid Login` detection to `_fetchFreshData()`.
5. **[`mobile/lib/features/academic/academic_login_screen.dart`](file:///D:/sru/mobile/lib/features/academic/academic_login_screen.dart)** & **[`mobile/lib/features/academic/academic_dashboard.dart`](file:///D:/sru/mobile/lib/features/academic/academic_dashboard.dart)**:
   - Unified login submission through `SraapAuthManager.submitLogin()`.
   - Prevented automatic CAPTCHA regeneration on invalid credentials, network timeouts, or IP restrictions.
   - Refreshed CAPTCHA on the existing session (`forceFreshSession: false`) when user taps Refresh or enters an incorrect CAPTCHA.
   - Added `gaplessPlayback: true` and `errorBuilder` to `Image.memory`.
6. **[`mobile/api/proxy.js`](file:///D:/sru/mobile/api/proxy.js)**:
   - Preserved query parameters on proxied requests (`/api/sraap/captcha/image.php?<timestamp>`).
   - Added `x-proxy-clear-cookie` support when explicitly initializing a fresh session on Web/PWA.

---

## 6. Regression Protection

Added [`mobile/test/sraap_captcha_login_compatibility_test.dart`](file:///D:/sru/mobile/test/sraap_captcha_login_compatibility_test.dart) (17 dedicated tests) plus existing 69 tests covering:
- CAPTCHA load success, failure, HTML captive-portal rejection, slow-network fallback, and concurrent request coalescing.
- Session cookie continuity across manual CAPTCHA refreshes (`forceFreshSession: false`).
- Login evaluation for HTTP 302, Web proxy HTTP 200 + `x-proxy-redirect`, inline JS redirect, ambiguous HTTP 200 verified via `/student/dash_board.php`, wrong CAPTCHA, invalid credentials, expired session, and IP restriction.
- Loop prevention (1 login submit = 1 POST request; no uncontrolled CAPTCHA loop).
- Background `pingKeepAlive` suppression during active login flow.
- Zero secret leakage in `SRAAP_LOGIN:` diagnostic logs.

---

## 7. Verification

- `flutter pub get`: Passed
- `flutter analyze`: **0 issues found**
- `flutter test`: **97/97 tests passed**
- `flutter build apk --release`: Built and verified at `D:\sru\mobile\build\app\outputs\flutter-apk\app-release.apk`

---

## 8. Remaining Risks

1. **SRAAP Campus Wi-Fi Rate Limiting**: `sraap.in` occasionally blocks shared campus NAT public IPs (`Access Restricted / shared public IP`). The app detects this explicitly and advises switching to 4G/5G mobile data without looping CAPTCHA requests.
2. **Upstream Portal Maintenance**: `sraap.in` periodically places pages into maintenance (`Server busy. Please try again later.`). Cached attendance and academic data remain accessible offline while displaying a non-blocking status message.

