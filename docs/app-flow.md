# SRU Timetable — App Flow v2

Companion to `sru-timetable-prd-v2.md`. This covers **navigation and
behavior** — what happens, in what order, under what conditions. The
**visual** spec (exact layout, copy, component styling) goes in `ui-flow.md`
once the new screen designs are shared.

---

## 1. Full navigation graph

```
App cold start
      │
      ▼
Local storage check: does a batch selection already exist?
      │
   ┌──┴──┐
  YES     NO
   │       │
   ▼       ▼
 Home   Welcome (name entry)
           │ Continue / Skip
           ▼
       Select Degree
           │ Continue (back → Welcome)
           ▼
       Select Year
           │ Continue (back → Select Degree)
           ▼
       Select Batch
           │ Continue (back → Select Year)
           ▼
        Syncing (automatic, no user action)
           │ on success
           ▼
          Home  ⇄  Week  ⇄  Changes  ⇄  Profile      (bottom nav, peer tabs)
           │                              │
     bell icon                  "Change timetable" link
           │                              │
           ▼                              ▼
    Notifications          re-enters onboarding from Select Degree,
       (back → Home)        clearing the existing degree/year/batch,
                             then returns to Profile (not Home) on
                             completion
```

## 2. Cold-start decision logic

Every app launch, before rendering anything user-facing:

1. Read local storage for an existing `{degree, year, batch}` selection.
2. If present → skip onboarding entirely, go straight to Home. Kick off a
   background sync (non-blocking — Home should render from cache instantly,
   then update in place if the sync returns newer data).
3. If absent → this is a first launch (or the person cleared data) → start
   the Welcome → Degree → Year → Batch → Syncing sequence.
4. Never show Welcome/onboarding again once a selection exists, except via
   the explicit "Change Degree/Year/Batch" rows in Profile.

## 3. Onboarding step dependencies

- **Degree** has no dependency — always fetched fresh from
  `GET /api/degrees`.
- **Year** depends on the chosen degree — refetch
  `GET /api/degrees/:degree/years` every time degree changes, discard any
  previously chosen year if degree changes (they're not independently valid).
- **Batch** depends on both degree and year — refetch
  `GET /api/degrees/:degree/years/:year/batches` every time either changes,
  discard any previously chosen batch if degree or year changes.
- Profile's single "Change timetable" link resets all three and re-enters
  the full Select Degree → Year → Batch → Syncing sequence — there's no
  granular "change just the batch" flow in this version, deliberately, to
  keep the state machine simple for the rebuild.

## 4. Syncing step — success/failure behavior

- On entering Syncing: register the device (FCM token + chosen batch) with
  the backend, fetch the chosen batch's timetable, write it to local cache.
- **Success:** persist `{degree, year, batch}` to local storage, navigate to
  Home.
- **Failure (API unreachable/timeout):** don't strand the person on an
  infinite spinner. After a reasonable timeout (e.g. 10–15s), show a retry
  option inline on the Syncing screen rather than silently failing or
  crashing. Do not persist the selection or navigate to Home until a sync
  has actually succeeded at least once — Home has nothing to show otherwise.

## 5. Bottom-nav tab behavior

- Home, Week, Changes, Profile are peers — switching between them swaps the
  visible tab, it does not push a new screen onto a stack. Each tab retains
  its own scroll position when you navigate away and back.
- None of the four tabs are reachable before onboarding completes at least
  once.
- Deep-linking from a push notification (Section 6) can land directly on a
  specific tab (typically Changes) even if the app was closed, but still
  respects "onboarding must be complete" — if somehow it isn't, fall back to
  onboarding instead of a broken tab.

## 6. Notifications flow

- Bell icon (visible on Home and Week headers) → Notifications screen, back
  chevron returns to wherever the bell was tapped from.
- A tapped **push** notification (app closed or backgrounded) deep-links:
  - Change-type notifications (room/faculty/subject/etc.) → Changes tab,
    ideally scrolled to the relevant entry if that's feasible; otherwise just
    open Changes.
  - Class-reminder notifications → Home.
- In-app Notifications screen itself does not have a bottom nav — it's a
  secondary/detail screen, back button is the only exit.

## 7. Offline / degraded-network behavior (applies everywhere)

- Any screen that reads live data (Home, Week, Changes, Notifications) must:
  1. Render instantly from local cache if available.
  2. Attempt a background refresh.
  3. If the refresh fails, show a small non-blocking banner ("Showing your
     last synced timetable — updated X ago") rather than an error screen or
     blank state.
  4. Silently retry/refresh when connectivity returns, without requiring the
     person to manually pull-to-refresh (though that should also work).
- Onboarding is the one place this doesn't apply — Select Degree/Year/Batch
  genuinely need a live connection, since there's no meaningful cached
  fallback for "which degrees exist" on a first launch with nothing cached
  yet. Show a clear retry state there instead, not a fake offline banner.

## 8. Data freshness display

- Compute all "Updated N min/hours ago" text client-side from a stored UTC
  timestamp of the last successful fetch — recompute on every render, don't
  cache the formatted string itself (it'll go stale).
- Show this on Home always. Profile's "Last synced" row and Sync Now action
  read/write the same underlying timestamp — they're the same piece of
  state, not two separate ones that could drift out of sync with each other.

## 9. What's intentionally NOT in this flow

- No account creation, login, or password reset flow anywhere.
- No multi-device sync of preferences — each install is independent local
  state; if someone reinstalls or switches phones, they redo onboarding.
- No way to follow more than one batch simultaneously in v2 (a professor or
  a student tracking a friend's schedule is a plausible future feature, but
  explicitly out of scope for this rebuild — don't let it creep in via
  Profile's "Change Batch" being generalized into "add a batch").
