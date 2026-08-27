# Master prompt — paste this into Antigravity to start the build

You are building **SRU Timetable**, a Flutter (Android + iOS) app with a
Node/TypeScript backend deployed on Render and Supabase (PostgreSQL) as the
database. Three documents in `docs/` are the full specification — read all
three before writing code, and treat them as authoritative:

- `docs/prd.md` — product requirements, architecture, database schema, API
  surface, Render deployment, and the phase-by-phase build plan.
- `docs/app-flow.md` — navigation graph and behavioral logic (what happens,
  in what order, under what conditions).
- `docs/ui-flow.md` — exact screen-by-screen visual spec (layout, copy,
  component treatment).

## The five rules that override everything else

1. **Never hardcode SRU data.** No degree names, year names, batch codes,
   subjects, faculty, rooms, or time slots anywhere in the codebase. All of
   it comes from the live SRU adapter → sync engine → database → API →
   app pipeline. If you're about to type a literal batch code or degree
   name into application logic (not a test fixture), stop.
2. **No login, no accounts, anywhere.** The only "identity" is a locally
   stored first name (optional, skippable) used for a greeting, plus a
   locally stored degree/year/batch selection. No email, password, or
   signup screens.
3. **The Flutter app never talks to SRU directly** — only to your own
   Render-hosted API. SRU's endpoints, CSRF handling, and session logic are
   isolated entirely inside the backend's SRU adapter.
4. **Follow the phase order in `docs/prd.md` exactly**, and don't move to
   the next phase until the current one's acceptance test passes. Phase 6
   (Flutter) specifically requires running the crash-prevention checklist
   in PRD Section 11 and testing an installed **release** APK on a physical
   device — not just `flutter run` in debug — before being considered done.
   The previous version of this app shipped a release build that crashed
   on launch (black screen, ~2s, close); that checklist exists specifically
   to prevent a repeat.
5. **Commit and push to GitHub after every phase passes its acceptance
   test**, not just at the end. Use the repo structure and `.gitignore`
   from `docs/prd.md` Section 8 — secrets (`.env`, keystores, Firebase
   config files) must never be committed.

## Explicitly out of scope — do not build these

- A global Search screen (Subjects/Faculty/Rooms). It appeared in an
  exploratory design but is confirmed cut from this build.
- Granular "Change Degree / Change Year / Change Batch" as separate flows.
  Profile has a single "Change timetable" link that resets all three.
- Photo avatars or full names anywhere — initials + first name only.
- Multi-batch following, admin roles beyond the single shared-password
  dashboard gate, or any account system.

## Start here

Begin with **Phase 0** from `docs/prd.md`: scaffold the monorepo
(`backend/`, `mobile/`, `docs/`), set up `.gitignore`, and make the initial
commit to GitHub. Then proceed to **Phase 1** (the `SRUClient` adapter) —
report back with the live-tested output for `BTECH-CSE / Third /
24BTCAICYB02` before moving to Phase 2, so the adapter is verified working
against the real SRU site before anything is built on top of it.
