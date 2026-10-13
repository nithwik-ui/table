# SRU Timetable 3.0 — System Architecture

## 1. High-Level Architecture Overview

```
                      ┌─────────────────────┐
                      │    SRU Timetable    │
                      │         3.0         │
                      └──────────┬──────────┘
                                 │
                      ┌──────────▼──────────┐
                      │  Local App Storage  │
                      │ Hive (v3 Namespace) │
                      └──────────┬──────────┘
                                 │
                   ALWAYS SHOW LAST VALID DATA
                                 │
                   ┌─────────────▼─────────────┐
                   │    TimetableRepository    │
                   │    (Reactive State)       │
                   └─────────────┬─────────────┘
                                 │
                   ┌─────────────▼─────────────┐
                   │       Sync Manager        │
                   └─────────────┬─────────────┘
                                 │
       ┌─────────────────────────┼─────────────────────────┐
       │                         │                         │
 ┌─────▼───────┐         ┌───────▼────────┐        ┌───────▼────────┐
 │   Backend   │         │ Authorized SRU │        │  Admin / Public│
 │ Cache / API │         │  Portal Scrape │        │     Import     │
 └─────────────┘         └────────────────┘        └────────────────┘
```

The fundamental philosophy of SRU Timetable 3.0 is **Offline-First, Cache-Immediate, Decoupled-Auth**.

---

## 2. Core Subsystems

### A. Data & Cache Architecture
- **Namespace**: `sru_timetable_v3_prefs` and `sru_timetable_v3_cache`.
- **Target Startup Render**: < 100–300ms from local Hive storage.
- **Data Model**:
  ```json
  {
    "entries": [...],
    "lastUpdated": "2026-10-12T10:00:00Z",
    "source": "cache",
    "version": 3,
    "isStale": false
  }
  ```
- **State Semantics**:
  - `empty`: No timetable exists yet (first run/onboarding needed).
  - `cached`: Displaying persisted local data immediately.
  - `syncing`: Performing background network reconciliation without blocking UI.
  - `fresh`: Newly synchronized data successfully loaded and stored.
  - `stale`: Sync failed (offline, timeout, expired session), but last valid data is fully intact and readable.
  - `error`: Non-blocking error notification for the user.

### B. Authentication Subsystem
- **States**:
  - `unauthenticated`
  - `authenticating`
  - `authenticated`
  - `sessionExpired`
  - `authUnavailable`
- **Decoupling**:
  - Authentication state governs access to dynamic remote scrapers (SRU portal) and personal features (SRAAP attendance).
  - It does **NOT** gate timetable rendering. Even if `AuthState = sessionExpired`, the timetable displays immediately from cache with a subtle warning badge ("Sync unavailable").

### C. Tab & UI Navigation Layer
- **Shared State**: All tabs (`HomeTab`, `WeekTab`, `AcademicTab`, `ChangesTab`, `ProfileTab`) listen to the single `TimetableRepository`.
- **No Side-Effects on Navigation**: Switching tabs in `IndexedStack` executes zero network requests and does not reset page controllers or state.

### D. AdMob Lifecycle Management
- **Single Banner Instance**: Managed by `AdService`.
- **Controlled Retention**: The banner ad remains mounted and alive across tab switches. It is not destroyed and recreated on each navigation event or screen rebuild.
- **Banner-Only Policy**: No interstitial, rewarded, app-open, or popup ads.

### E. Background & Push Infrastructure (FCM)
- Handled asynchronously via `_firebaseMessagingBackgroundHandler` and `NotificationService`.
- Completely non-blocking during initial application bootstrapping.
