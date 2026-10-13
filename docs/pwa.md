# Progressive Web App (PWA) — SRU Timetable 3.0

## 1. Web Capabilities & Constraints
- **Offline Shell**: Service Worker caches static assets and Flutter engine files for fast offline loads.
- **Autofill Support**: HTML standard inputs with `autocomplete="username"`, `autocomplete="current-password"`, and `autocomplete="one-time-code"`.
- **Touch Responsiveness**: Touch listeners and gestures optimized for Safari iOS and Android Chrome.
- **Non-Blocking Boot**:
  - Web notifications / FCM service worker registered asynchronously.
  - Native plugins (e.g. AdMob) guarded by `!kIsWeb`.
  - First frame rendered from IndexedDB/Hive cache before attempting remote network calls.
