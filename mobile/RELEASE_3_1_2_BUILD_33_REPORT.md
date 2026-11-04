# SRU Timetable 3.1.2 Release Build 33 Report

## Version

```text
Version: 3.1.2
Version Code: 33
Update Type: Recommended
```

## Update message

```text
SRU Timetable 3.1.2 includes important stability, login, CAPTCHA and performance improvements.
```

## Verification

- **`flutter pub get`**: PASS (All dependencies resolved, 0 conflicts)
- **`flutter analyze`**: PASS (0 issues found, ran in 11.3s)
- **`flutter test`**: PASS (104/104 tests passed across 12 test suites, including full update policy and semantic version comparison tests)
- **AAB build**: PASS (`build/app/outputs/bundle/prodRelease/app-prod-release.aab` - 61.1 MB)
- **APK build**: PASS (`build/app/outputs/flutter-apk/app-prod-release.apk` - 60.0 MB)
- **version verification**: PASS (`versionName = 3.1.2`, `versionCode = 33`, verified via `aapt dump badging`)
- **applicationId verification**: PASS (`com.srutimetable.mobile`, verified via AndroidManifest & `aapt dump badging`)
- **signing verification**: PASS (Verified via `apksigner verify --verbose` using upload release keystore, APK Signature Scheme v2 = true)
- **update behavior verification**: PASS
  - Semantic versioning: `3.1.1` -> `3.1.2` triggers recommended update; `3.1.2` -> `3.1.2` triggers no update; `3.1.3` -> `3.1.2` triggers no update.
  - Recommended non-blocking update dialog: Title "New update available", Heading "SRU Timetable 3.1.2", Body "SRU Timetable 3.1.2 includes important stability, login, CAPTCHA and performance improvements.", Buttons "Update Now" and "Later".
  - Tapping "Later" dismisses update dialog, sets session-level suppression (`dismissedThisSession = true`), and lets user continue using the app without interruption or repeated alerts.
  - Silent startup check runs after a polite 3-second delay, never blocking cached timetable rendering or startup speed.
- **SRAAP regression status**: PASS
  - SRAAP session continuity preserved: in-flight CAPTCHA coalescing, session lock during login, reuse of active `PHPSESSID` on manual refresh.
  - Fallback to `/captcha/image.php` session bootstrap on slow networks preserved.
  - Multi-status HTTP 200 redirect verification against `/student/dash_board.php` preserved.
  - Error classification preserves distinct UI for wrong CAPTCHA vs invalid credentials vs network timeout.
  - Background keep-alive pings strictly suppressed during active login flow.

## Artifacts

```text
AAB:
- D:\sru\mobile\build\app\outputs\bundle\prodRelease\app-prod-release.aab
- D:\sru\mobile\build\app\outputs\bundle\release\app-release.aab
- D:\sru\mobile\build\release\sru-timetable-3.1.2.aab

APK:
- D:\sru\mobile\build\app\outputs\flutter-apk\app-prod-release.apk
- D:\sru\mobile\build\app\outputs\flutter-apk\app-release.apk
- D:\sru\mobile\build\release\sru-timetable-3.1.2.apk
```

## Final status

```text
READY FOR RELEASE
```
