# SRU Timetable App — PRD v2 (Antigravity rebuild)

**Stack:** Flutter (Android + iOS) · Node/TypeScript backend on **Render** ·
Supabase (PostgreSQL) · Firebase Cloud Messaging · GitHub for source control

This is a rebuild, not a redesign — the product decisions from v1 (dynamic
discovery, no hardcoding, no-login local storage, the screen set) all carry
forward. What changed: platform stays Flutter, but this doc adds explicit
repo/deployment structure and a crash-prevention checklist, because v1's APK
crashed on launch (black screen, ~2s, close) and that failure mode needs to
be designed against from day one this time, not patched after the fact.

---

## 0. Why the rebuild — carry-forward vs. fix-forward

Keep everything below unless this doc says otherwise:

- Dynamic discovery architecture (Section 3–4)
- Database schema (Section 5)
- API surface (Section 6)
- Change detection via hashing (Section 7)
- No-login, local-storage-only onboarding
- The resolved screen set and Profile hybrid decision from the UI flow work
  already done (Welcome → Degree → Year → Batch → Syncing → Home/Week/
  Changes/Profile, Notifications off the bell icon)

New in v2: Section 8 (repo structure), Section 9 (Render deployment),
Section 11 (crash-prevention checklist) — these exist specifically because
v1 got to "installed on a phone" and failed there.

---

## 1. Product vision

An intelligent SRU academic schedule platform that continuously synchronizes
official SRU timetable data and immediately tells students when their
schedule changes. Open the app, see current/next class, room, faculty in
under a second — even offline — get notified the moment SRU moves something.

## 2. Non-negotiable architectural rule

**Nothing about SRU's data is hardcoded.** Not degrees, years, batch codes,
subjects, faculty, rooms, or time slots. New SRU data appears automatically
after the next sync — zero app update required.

```
SRU DATA → DISCOVERY → SYNC ENGINE → NORMALIZATION → DATABASE
         → CHANGE DETECTION → API → MOBILE APP → STUDENT
```

The Flutter app never talks to SRU directly — only to your API.

## 3. Source of truth

```
https://timetable.sruniv.com/batchReport
```

| Purpose | Endpoint |
|---|---|
| Page + CSRF token | `GET /batchReport` |
| Years for a degree | `GET /get-yearbpublic?degree=` |
| Batches for degree+year | `GET /get-batchbpublic?degree=&year=` |
| Grid-format timetable | `POST /searchBatchReportPublic` |
| Detailed structured timetable (canonical) | `POST /searchBatchReport2Public` |

CSRF: Laravel session-bound `_token`, scraped from `/batchReport`'s hidden
input, reused via a persistent cookie jar, refreshed on HTTP 419 or every
few minutes.

## 4. System architecture

```
                    SRU WEBSITE
                         │
                         ▼
                 ┌────────────────┐
                 │   SRU CLIENT   │  getDegrees / getYears / getBatches
                 │  (adapter)     │  getTimetable / getDetailedTimetable
                 └───────┬────────┘
                         ▼
                 ┌────────────────┐
                 │  SYNC ENGINE   │  normalize → hash → diff → detect changes
                 └───────┬────────┘
                         ▼
                 ┌────────────────┐
                 │    SUPABASE    │  degrees / years / batches /
                 │   PostgreSQL   │  timetable_entries / snapshots / changes
                 └───────┬────────┘
                         ▼
              YOUR REST API (Node/TS, hosted on Render)
                         │
                         ▼
                 ┌────────────────┐
                 │  FLUTTER APP   │  onboarding → home → week → changes → profile
                 └────────────────┘
```

## 5. Database schema (Supabase / Postgres)

```
degrees              (id, name, source_value, active, first_seen_at, last_seen_at)
years                (id, degree_id, name, active, first_seen_at, last_seen_at)
batches              (id, degree_id, year_id, batch_code, active, first_seen_at, last_seen_at)
timetable_entries    (id, batch_id, day, start_time, end_time, subject, faculty,
                       room, semester, ltp, source_hash)
timetable_snapshots  (id, batch_id, hash, raw_json, synced_at)
timetable_changes    (id, batch_id, timetable_entry_id, change_type, field_name,
                       old_value, new_value, detected_at)
device_tokens        (id, fcm_token, batch_id, notifications_enabled, created_at)
```

Note: `users` from v1 is renamed/reduced to `device_tokens` — since there's
no login, the only thing you actually need to persist server-side per
install is an FCM token mapped to a batch, for push notifications. Everything
else (name, preferences, appearance) lives only on-device.

`change_type` enum: `CLASS_ADDED`, `CLASS_REMOVED`, `SUBJECT_CHANGED`,
`FACULTY_CHANGED`, `ROOM_CHANGED`, `TIME_CHANGED`, `LTP_CHANGED`.

## 6. Public API surface

```
GET  /api/degrees
GET  /api/degrees/:degree/years
GET  /api/degrees/:degree/years/:year/batches
GET  /api/batches/:batchId/timetable
GET  /api/batches/:batchId/today
GET  /api/batches/:batchId/next-class
GET  /api/batches/:batchId/changes
POST /api/devices/register        (fcm_token, batch_id)
POST /api/devices/preferences     (fcm_token, notifications_enabled)
GET  /health                      (Render health check — see Section 9)
```

## 7. Change detection

```
fetch timetable → normalize → sort deterministically → serialize
→ SHA-256 → compare against last stored hash
   same → NO CHANGE
   different → diff field-by-field → write timetable_changes row → notify
```

## 8. Repo structure & GitHub

Two repos (cleaner CI/deploy separation than a monorepo for this project
size) or one monorepo — pick one and stay consistent. Recommended: monorepo,
since it's a solo project and keeps the PRD/flow docs alongside both codebases.

```
sru-timetable/
├── backend/                 ← Node/TS, deployed to Render
│   ├── src/
│   │   ├── sru/             (SRUClient adapter)
│   │   ├── sync/             (sync worker, hashing, diffing)
│   │   ├── db/                (Supabase client, queries)
│   │   ├── api/                (Express/Fastify routes)
│   │   └── index.ts
│   ├── package.json
│   ├── render.yaml            ← Render service definition (Section 9)
│   └── .env.example
├── mobile/                  ← Flutter app
│   ├── lib/
│   │   ├── app/
│   │   ├── core/
│   │   ├── features/
│   │   └── widgets/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── docs/
│   ├── prd.md                 (this file)
│   ├── app-flow.md
│   └── ui-flow.md
├── .gitignore
└── README.md
```

**`.gitignore` must exclude** (this matters more than usual given the D-drive
setup and the fact you already leaked risk once with the CSRF-token/keystore
handling): `.env`, `**/key.properties`, `**/*.jks`, `**/google-services.json`,
`**/GoogleService-Info.plist`, `build/`, `.dart_tool/`, `node_modules/`,
`android/local.properties`.

**GitHub workflow:**
```bash
git init
git add .
git commit -m "Initial commit: PRD, app flow, repo scaffold"
git branch -M main
git remote add origin https://github.com/<you>/sru-timetable.git
git push -u origin main
```
Push after every phase passes its acceptance test, not just at the end —
small, phase-tagged commits make it far easier to bisect if a later Flutter
build starts crashing again.

## 9. Render deployment (backend)

- Render Web Service, root directory `backend/`.
- Build command: `npm install && npm run build`
- Start command: `npm start`
- Environment variables set in Render's dashboard, never committed:
  `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `FCM_SERVER_KEY` (or service
  account JSON path), `SYNC_INTERVAL_MINUTES`.
- Add a `GET /health` route returning `200 { status: "ok" }` — Render uses
  this for health checks, and it's also useful for you to sanity-check the
  deploy from a browser.
- The sync worker (Phase 3) runs as a scheduled job. Two options: (a) Render
  Cron Job as a separate service hitting an internal `/api/internal/sync`
  endpoint on a schedule, or (b) `node-cron` running inside the same web
  service process. (a) is more resilient (survives the web service
  restarting) — prefer it if Render's free/starter tier supports Cron Jobs
  on your plan; otherwise (b) is fine for a student-scale project.
- `render.yaml` should live in `backend/` so the service is reproducible from
  git, not manually clicked-together in the dashboard.

## 10. UI direction (summary — full detail in `ui-flow.md` once screens are shared)

- Minimalist, premium, mobile-first. Academic Precision design system: SRU
  Blue `#0B4F96`/`#003870`, background `#F7F9FC`, white cards, Inter + Geist
  type, 8px grid, 16px card radius.
- No login screens. Onboarding: Welcome (local name, skippable) → Select
  Degree → Select Year → Select Batch → Syncing → Home.
- Bottom nav: Home, Week, Changes, Profile. Bell icon → Notifications.
- Profile: initials avatar + first name (never a photo or fabricated full
  name), single "Change timetable" link that resets degree/year/batch
  together and re-runs onboarding from Select Degree. (Supersedes the
  earlier granular per-field hybrid decision — simplified deliberately for
  this rebuild to reduce state/flow surface area.)
- Always show data freshness (`✓ Updated 12 min ago`) and handle offline
  gracefully everywhere, not just on Home.

## 11. Crash-prevention checklist (why v1 broke on launch)

A black screen that appears for ~2 seconds and then closes is Android/iOS
killing the process during initialization — almost always one of these.
Antigravity should verify every item below before the first release build,
not after:

- **Firebase init order:** if FCM is wired in early, a missing or malformed
  `google-services.json` (Android) / `GoogleService-Info.plist` (iOS), or
  calling `Firebase.initializeApp()` before `WidgetsFlutterBinding
  .ensureInitialized()`, crashes at launch before any UI renders. Always:
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    runApp(const App());
  }
  ```
  and wrap `Firebase.initializeApp()` in a try/catch that logs but doesn't
  rethrow during early development, so a Firebase misconfig degrades to
  "notifications don't work yet" instead of "app doesn't open."
- **Splash screen conflicts:** if using `flutter_native_splash`, regenerate
  it (`dart run flutter_native_splash:create`) after any icon/asset change
  and test on Android 12+ specifically — the Android 12 SplashScreen API
  conflicts with manually-drawn splash activities if both are configured.
- **Release signing:** a release build referencing a keystore path or
  `key.properties` that doesn't exist on the build machine fails silently in
  ways that can present as a crash-on-launch rather than a build failure,
  if the CI/build step doesn't hard-fail correctly. Verify `flutter build apk
  --release` actually completes with no warnings before installing, not just
  that it produces a file.
- **minSdkVersion:** confirm `android/app/build.gradle`'s `minSdkVersion` is
  compatible with the actual test device's Android version — a plugin
  bumping the effective minimum (common with newer Firebase/camera/location
  plugins) silently mismatches against an older test phone.
- **Uncaught exception before `runApp`:** any local-storage read in `main()`
  (e.g. checking for an existing onboarding selection) must handle the
  "key doesn't exist yet" case explicitly — a null-check failure here throws
  before any widget tree exists, so nothing catches it and the OS just kills
  the process, which looks exactly like "black screen then closes."
- **ProGuard/R8 (release only):** if enabled, missing `-keep` rules for
  Firebase/Supabase model classes cause reflection-based failures only in
  release builds, never in debug — this is a classic "works on `flutter run`,
  crashes as an installed release APK" cause. Test the actual release APK on
  a device early and often, not just debug builds during development.
- **Always test with `flutter run --release`** (or an installed release APK)
  at the end of every phase from Phase 6 onward, not only debug mode — debug
  mode hides most of the above.

## 12. Phase-wise build plan

### Phase 0 — Repo & environment
Set up the monorepo structure (Section 8), `.gitignore`, D-drive Flutter/
Android SDK config, initial commit + push to GitHub.

**Acceptance test:** `git log` shows an initial commit on GitHub containing
this PRD, an empty `backend/` and `mobile/` scaffold, and a working
`.gitignore` that keeps secrets out.

### Phase 1 — SRU Adapter
`SRUClient` (TypeScript): CSRF/session handling, `getDegrees`, `getYears`,
`getBatches`, `getDetailedTimetable`, `normalize()`. Pure adapter, no DB, no
UI, retries with backoff.

**Acceptance test:** live call for `BTECH-CSE / Third / 24BTCAICYB02` returns
a correctly normalized timetable, no hardcoded values in the adapter.

### Phase 2 — Supabase schema
Create the Section 5 tables with RLS (public read on degrees/years/batches/
timetable_entries, service-role-only write).

**Acceptance test:** RLS blocks anonymous writes; service role can insert.

### Phase 3 — Sync worker
Discover degrees → years → batches live, upsert into Supabase, fetch +
normalize each batch's timetable, concurrency-limited with retries that
don't abort the whole run on one failure.

**Acceptance test:** `npm run sync` prints live counts; one failing batch
doesn't stop the rest.

### Phase 4 — Change detection
Hash → compare → diff → write `timetable_changes` rows with correct
`change_type`/old/new values.

**Acceptance test:** manually altering a test fixture's room and rerunning
sync produces a correct `ROOM_CHANGED` row.

### Phase 5 — REST API + Render deploy
Expose Section 6 endpoints, deploy to Render per Section 9, confirm
`/health` responds publicly.

**Acceptance test:** all endpoints return normalized JSON from a live Render
URL, not `localhost`; sync worker runs on schedule in production.

### Phase 6 — Flutter app
Onboarding + Home/Week/Changes/Profile/Notifications wired to the live
Render API, local storage only, animations, matching the eventual
`ui-flow.md`. Run the full Section 11 crash-prevention checklist before
calling this phase done.

**Acceptance test:** a `flutter build apk --release` installs and opens
successfully on a physical device — no black-screen crash — with every
screen fully wired to live data.

### Phase 7 — Notifications
FCM wired to `device_tokens`, change-triggered pushes, grouping, quiet
hours, per the earlier notification-style spec.

**Acceptance test:** a simulated `ROOM_CHANGED` event delivers a correctly
formatted push to a real test device.

### Phase 8 — Offline cache
Local Hive cache, offline banner, silent re-sync on reconnect.

**Acceptance test:** airplane mode after first load still shows a full,
accurately-timestamped timetable.

### Phase 9 — Admin dashboard
Next.js dashboard, shared-password gate (no accounts — see the earlier auth
decision), sync status/counts, manual sync actions.

**Acceptance test:** bare password gate works; dashboard reflects real
Supabase counts; "Sync failed" retries only failed batches.

---

## 13. Cross-cutting rules

- Never expose SRU CSRF tokens, the Supabase service role key, or Firebase
  service account credentials client-side — Render env vars only.
- SRU being temporarily unreachable must never corrupt or wipe existing
  data — students keep seeing their last synced timetable.
- One failing batch must never abort a whole sync run.
- No literal degree name, batch code, or time slot string anywhere in the
  Flutter codebase — if you're typing one into a `.dart` file, fetch it from
  the API instead.
- Test every Phase-6-onward change against an installed **release** APK, not
  just `flutter run` in debug — see Section 11.
