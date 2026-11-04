# RELEASE 3.1.4 REPORT — SRU TIMETABLE

## Executive Summary
SRU Timetable 3.1.4 (Android `versionCode: 35`) is a major quality-of-life, stability, UX, notification, offline, dark-mode and monetization release. All 110 automated tests pass with 0 warnings/errors under `flutter analyze`. Production release artifacts have been successfully built and verified for Android APK, Android App Bundle (AAB), and Web/PWA.

---

## Version
- **Version Name**: `3.1.4`
- **Version Code**: `35`
- **Package / Application ID**: `com.srutimetable.mobile`
- **Schema Version**: `3` (Namespace: `sru_timetable_v3`)

---

## Features Implemented & Verified

### 1. Stability & Data Freshness (P0)
- **Authoritative `lastSyncedAt`**: Fixed "Updated 36 hr ago" staleness behavior. Timestamp updates exclusively upon successful fetch → validate → parse → atomic cache write cycle. On network error or failed refresh, old `lastSyncedAt` and cached data are preserved without displaying false "just now" stamps.
- **Offline Mode Resilience**: Subtle, non-blocking indicator ("Offline • Showing saved timetable • Last updated...") when network is unreachable. No blank screen, infinite spinners, or cache wipes.
- **Smart Non-Blocking Sync**: Startup and app-lifecycle resume trigger background sync while immediately rendering cached UI (<100ms first frame).
- **Centralized Canonical Class Status Engine**: Fixed incorrect future class status (`Completed` regression). Future classes are strictly `Upcoming`; past classes are strictly `Completed`; ongoing and midnight-crossing classes accurately transition based on real-time IST.
- **Update Architecture**: Semantic version comparison (`3.1.2` < `3.1.4`). Configured as a non-blocking recommended update with "Update Now" and "Later" options, adhering to session dismissal semantics.

### 2. Core User Experience (P1)
- **Home 2.0**: Header with greeting, verified student roll/branch context line, subtle sync status, and prominent **Up Next** card displaying subject, IST timings, classroom, faculty, class type, and real-time countdown badge ("Starts in X min" / "Ongoing • Ends in X min").
- **Week 2.0**: Day selector with touch targets, class type badges (Lecture, Lab, Tutorial), reference date calculations, and gap detection.
- **Free Period Detection**: Automatically computes schedule gaps on Home and Week views, surfacing inline "Free Period" / "Lunch Break" cards and the "Next free period" indicator.
- **Free Classrooms Finder**: Room availability dashboard with time/day/block filters, grouped view ("All Blocks" and individual blocks: A, B, C, etc.), utilizing verified room schedule data.
- **Timetable Search**: Zero-latency local search engine matching across Subject, Faculty, and Classroom.
- **Weekly Statistics**: Live statistics card calculating total classes, labs, free periods, busiest day, and lightest scheduled day directly from local timetable cache without server roundtrips.
- **Academic & Attendance 2.0**:
  - Distinguishes "Fresh" vs "Cached" attendance records.
  - Overall attendance progress indicator and threshold status badges (Safe 75%+, Condonation 65–74%, Detention Risk <65%).
  - Preserved placement attendance integration (Campus Recruitment & Training attendance percentage without phantom attended/conducted numbers).
  - Preserved SRAAP session/CAPTCHA protections and decoupled state machines.
- **Profile 2.0**: High-density student identity card (Name, Roll No, Branch, Semester), Appearance settings, Notification reminder controls, Sync/Update status, and Account management.
- **Class Reminders & Notification Preferences**: Profile settings for Class Reminders (`OFF`, `15 minutes before`, `30 minutes before`), integrating with local alarms and Web/PWA notifications without delaying app launch.
- **Announcements**: Dynamic announcement banner with "Important" tags and notification integration.

### 3. Dark Mode Architecture (P1)
- **System-Wide Theming**: Real dark mode implementation with semantic layered tokens (`background`, `surface`, `surfaceElevated`, `primary`, `textPrimary`, `textSecondary`, `textMuted`, `outline`, `infoContainer`, `warningContainer`, `errorContainer`, `successContainer`).
- **Appearance Options**: Selectable between `System`, `Light`, and `Dark`, with immediate UI adaptation.
- **Persistence**: Saved to Hive box `sru_timetable_v3_prefs` (`theme_mode`), reliably persisting across app restarts and reboots.
- **PWA & Web Support**: Instant dark/light CSS splash in `index.html` responding to `prefers-color-scheme` (<20ms paint) with dual `<meta name="theme-color">` headers for mobile Safari and Android Chrome.

---

## Monetization Architecture
- **Ad Network**: `InMobi`
- **Format**: Banner ONLY
- **Placement**:
  - Bottom of Home tab (above bottom navigation)
  - Bottom of Week tab
  - Strict exclusion from Splash, Login, CAPTCHA, Onboarding, Syncing, and Error views.
- **Central AdService**:
  - Singleton lifecycle (`initialize()`, `loadBanner()`, `disposeBanner()`, `diagnostics`)
  - Complete isolation from the critical path: failures to load InMobi ads cleanly collapse to `SizedBox.shrink()` without crashing, hanging, or locking navigation.
  - Telemetry diagnostics tracking requests, impressions, fill rate, latency, and eCPM metrics.

---

## Verification & Test Results

| Check | Tool / Command | Result | Details |
|---|---|---|---|
| Static Analysis | `flutter analyze` | **PASSED** | 0 issues found |
| Unit & Widget Tests | `flutter test` | **PASSED** | 110 passed, 0 failed |
| Freshness & Offline Tests | `release_3_1_4_features_test.dart` | **PASSED** | Verified cache preservation and lastSyncedAt immutability on failure |
| Status Engine Tests | `status_engine_and_auth_stability_test.dart` | **PASSED** | Verified IST boundaries, midnight crossing, and future date Upcoming logic |
| Placement Attendance Tests | `placement_attendance_test.dart` | **PASSED** | Verified parser, cache, and clean non-overflowing UI layout |
| Update Policy Tests | `update_policy_test.dart` | **PASSED** | Verified 3.1.4 recommended prompt, semver, and dismissal |
| Web / PWA Build | `flutter build web --release` | **PASSED** | Output in `mobile/build/web` |
| Release APK Build | `flutter build apk --flavor prod --release` | **PASSED** | Output: `mobile/build/release/sru-timetable-3.1.4.apk` (60.2 MB) |
| Release AAB Build | `flutter build appbundle --flavor prod --release` | **PASSED** | Output: `mobile/build/release/sru-timetable-3.1.4.aab` (61.3 MB) |

---

## Release Artifacts
1. **Release APK**:
   - Path: `mobile/build/release/sru-timetable-3.1.4.apk`
   - Size: `63,076,377 bytes` (~60.2 MB)
2. **Release AAB**:
   - Path: `mobile/build/release/sru-timetable-3.1.4.aab`
   - Size: `64,243,151 bytes` (~61.3 MB)
3. **Web / PWA**:
   - Path: `mobile/build/web/`

---

## Final Status
**READY FOR RELEASE**

