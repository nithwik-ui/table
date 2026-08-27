# SRU Timetable — UI Flow v2

Companion to `sru-timetable-prd-v2.md` and `app-flow-v2.md`. This is the
**visual** spec — exact layout, copy, and component treatment — matching the
latest generated screens. Where earlier docs described something
differently, this file wins; it reflects the resolved, current design.

**Explicitly out of scope for this build:** a global Search screen
(Subjects/Faculty/Rooms filters) appeared in one exploratory frame but is
confirmed **not** part of this rebuild. Don't implement it.

---

## 0. Logo & brand asset

The app logo is a standalone wordmark: **"sru"**, lowercase, bold, SRU Blue,
no icon/glyph attached to it. Use this as:
- The app icon / splash image (centered on white or `#F7F9FC`).
- A small-scale version of the same wordmark in every screen header,
  immediately left of the "SRU Timetable" header text.

Don't introduce a separate graduation-cap icon mark — earlier drafts assumed
one, but the actual logo asset is text-only. Keep it that way everywhere.

## 1. Global components

- **Header (standard):** small "sru" wordmark + "SRU Timetable" text,
  left-aligned. Right side varies by screen (see each screen below).
- **Header (onboarding):** back chevron top-left (except the very first
  Welcome screen, which has none) + centered "sru" wordmark, no "SRU
  Timetable" text needed on these — the wordmark alone is enough since the
  headline below carries the context.
- **Bottom nav:** Home / Week / Changes / Profile, 4 items, icon + label,
  active tab in SRU Blue, inactive in secondary grey. Changes tab can carry
  a small red dot/badge when there are unread changes — badge disappears
  once the Changes screen has been opened.
- **Primary button:** full-width, SRU Blue fill, white text, 12px radius.
  On onboarding screens (Degree/Year/Batch) it includes a trailing "→"
  arrow icon; on Welcome's "Continue" it does not — keep that distinction,
  it's a deliberate visual downgrade of emphasis on the very first,
  lowest-stakes step.
- **Progress indicator:** use the 3-dot indicator (outline dots, current
  step filled/enlarged) consistently across Select Degree, Select Year, and
  Select Batch — Select Batch labels itself "Step 4" in addition to (not
  instead of) the dots, since Welcome counts as step 1 implicitly even
  though it shows no indicator itself.

## 2. Welcome (name entry)

- Header: "sru" wordmark + "SRU Timetable" text, small scale, no back
  chevron (first screen).
- Headline: "What should we call you?"
- Subtext: "We'll use this to greet you — nothing else."
- Text input, placeholder "First name".
- "Continue" button (no arrow — see Section 1).
- "Skip for now" centered ghost link below the button.

## 3. Select Degree

- Header: back chevron + centered "sru" wordmark. 3-dot progress, first dot
  current.
- Headline: "Choose your degree."
- Search input: "Search degree — e.g. BTECH-CSE", live-filters the list.
- Degree list, each row: degree code (bold) + a friendly subtitle (e.g.
  "BTECH-CSE" / "Computer Science & Engineering", "BCA-CSAI" / "Computer
  Applications (AI focus)", "MBA-BM" / "Business Management", "PhD-ECE" /
  "Electronics & Communication"). Selected row shows a checkmark instead of
  a trailing chevron.
- Subtitle sourcing: maintain a local code→description lookup map for known
  degrees; any degree the sync engine discovers that isn't in the map
  renders with just the code, no subtitle — never block rendering on a
  missing description.
- "Continue →" button, disabled until a degree is selected.

## 4. Select Year

- Header: "sru" wordmark + "SRU Timetable" text, back chevron. 3-dot
  progress, second dot current.
- Chip below header showing the chosen degree (e.g. "BTECH-CSE").
- Headline: "Which year are you in?"
- Year cards (vertical stack, not a dropdown), each with an icon + year name
  + semester subtitle:
  - First Year — "Semesters 1 & 2"
  - Second Year — "Semesters 3 & 4"
  - Third Year — "Semesters 5 & 6"
  - Fourth Year — "Semesters 7 & 8"
- Selected card: solid SRU Blue fill, white text, checkmark. Unselected
  cards: white/outline with icon in a light tinted circle.
- Subtitle derivation: computed from ordinal position
  `(index*2+1) & (index*2+2)`, not hardcoded per year name — works for any
  year list length SRU returns. Omit the subtitle if ordering can't be
  determined confidently.
- "Continue →" button, disabled until a year is selected.

## 5. Select Batch (+ Syncing)

- Header: back chevron, small "Step 4" label instead of dots (batch lists
  can be long, so a numeric step label reads better than trying to fit a
  4th dot).
- Two chips: chosen degree, chosen year.
- Headline: "Select your batch."
- Search input: "Search batch code" — batch codes render in a mono/code
  style throughout this screen (e.g. `24BTCAICYB02`).
- Batch list: selected row is solid SRU Blue fill + checkmark; unselected
  rows are plain outlined rows — this solid-fill selection style is unique
  to this screen (Degree/Year use checkmark-on-white instead), intentional
  as the final, most-committal step of onboarding.
- "Continue →" button.
- **On Continue**, transition automatically to the Syncing state (full
  screen, no header): centered "sru" wordmark, spinner, "Setting up your
  timetable..." text. See `app-flow-v2.md` Section 4 for success/failure
  behavior — don't strand the person on an infinite spinner if the API
  times out.

## 6. Home (dashboard)

- Header: "sru" wordmark + "SRU Timetable" title, settings gear icon, bell
  icon (right side).
- Greeting: "Good morning, {name}" — time-of-day aware, falls back
  gracefully with no name if skipped.
- Context line: "{Degree} · {Year} · {Batch}".
- Sync row: refresh icon + "Updated {N} min ago" — always visible, computed
  live, never a static string.
- **"Up Next" section:** one prominent card — badge "Starts in {N} min" (or
  a live-state badge if in progress, per `app-flow-v2.md` Section 8 logic),
  subject name (headline weight), clock icon + time range, pin icon + room,
  trailing chevron.
- **"Today" section** (with a "View All" link → Week, scrolled to today):
  remaining classes as compact rows — subject, a type tag ("Lecture" in one
  tag style, "Lab" in a visually distinct — e.g. warmer-toned — tag style),
  time range, room. Empty state: "Day complete" / "No more classes today"
  if nothing remains.
- Bottom nav: Home active.

## 7. Week

- Header: "sru" wordmark + title, bell icon (no gear here — settings lives
  on Home/Profile only).
- Headline: "This week."
- Horizontal day-pill row (date + short day label stacked per pill),
  selected day solid SRU Blue fill.
- Sub-headline: full date of the selected day, e.g. "Wednesday, 26 August".
- Class list for that day, each card showing: time range (top-right of the
  card), subject name, room + building, faculty name. **If one of the
  day's classes is the actual next upcoming class relative to real time,**
  give it a small "Next" tag/badge distinct from the others — this only
  appears when viewing *today*, not other days.
- "— End of classes —" divider/label at the bottom of a populated list.
- Empty-day variant: centered icon, "No classes today", "Enjoy your free
  day".
- Bottom nav: Week active.

## 8. Changes

Unchanged from the earlier build — header, "Changes" headline, "{N} updates
this week" chip, diff-style cards (`1106-B → 1202-B`), bottom nav with
Changes active.

## 9. Profile — resolved: single reset link

- Header: "sru" wordmark + title, bell icon.
- Profile card: initials avatar (e.g. "N" on an SRU-Blue-tinted circle —
  never a photo), first name only (or a neutral fallback if skipped at
  Welcome, never a fabricated full name), degree/year chip, batch code
  below in mono style, and a single ghost link: **"Change timetable."**
  Tapping it clears the current degree/year/batch and re-enters onboarding
  at Select Degree; completing onboarding again returns to Profile, not
  Home.
- **"Preferences" section:** "Notifications" toggle, "Class reminders"
  toggle — both local device preferences.
- **"Data" section** (right-aligned "Last synced: {timestamp}" label at the
  section header level, not per-row):
  - "Refresh timetable" — triggers immediate re-sync, updates the timestamp.
  - "Check for updates" — chevron row (can be a manual "check now without
    full refresh" or simply an alias for the same refresh action — your
    call, keep only one real action if they'd otherwise be identical).
  - "Clear cache" — clears local timetable cache only (not the name or
    selected batch), re-syncs immediately after. Rendered in a slightly
    warmer/muted tone since it's a more consequential action than the
    others, without going full destructive-red.
- "About" — chevron row.
- Footer: "SRU Timetable v{version}" centered, small, muted.
- Bottom nav: Profile active.

## 10. Notifications (bell icon destination)

- Header: back chevron + "Notifications" title + "Mark all read" ghost link.
- Grouped under date headers: "TODAY", "YESTERDAY" (extend to "THIS WEEK" /
  older groups as needed).
- Row anatomy: colored icon badge by type, bold title, detail line,
  timestamp, unread dot for unread items. Established color coding:
  - Class Reminder → blue icon
  - Room Changed → amber/orange icon
  - Faculty Changed → a distinct third color (e.g. purple) for the
    person-related icon
  - Class Cancelled → treat as more severe than a room change; give it its
    own visually distinct treatment (don't reuse the plain blue reminder
    color for something as disruptive as a cancellation)
- Copy patterns (reuse exactly):
  - "Class Reminder" — "{Subject} starting in {N} mins ({Room})."
  - "Room Changed" — "{Subject} ({Code}) moved to {NewRoom}."
  - "Faculty Changed" — "{Subject} will be taken by {NewFaculty} today."
  - "Class Cancelled" — "{Subject} ({Code}) has been cancelled for today."
- "No older notifications" at the end of the list.
- Empty state: reuse the bell-icon "You're all caught up" pattern.
- No bottom nav — back chevron is the only exit.

## 11. Offline banner (applies wherever live data is shown)

A specific visual treatment, not just a text note — matches the exploratory
frame exactly:
- A dismissible-looking but persistent banner card near the top of the
  screen, warm/coral tint background, an icon indicating no connectivity,
  bold "You're offline" title, "Showing last synchronized timetable." body
  text, and a "Try again" action on the same row.
- Appears on Home, Week, Changes, Notifications whenever a background
  refresh fails — not just Home. See `app-flow-v2.md` Section 7 for the
  full behavioral rule (render from cache first, attempt refresh, show this
  banner only if the refresh fails).
- "Try again" triggers an immediate manual retry of the failed fetch; on
  success, the banner dismisses itself rather than requiring the person to
  navigate away and back.

## 12. Sync/splash screen

Reused at (a) the end of onboarding (Section 5) and (b) app cold-start while
checking local storage for an existing selection. Centered "sru" wordmark,
spinner, status text (blank/minimal on cold start, "Setting up your
timetable..." during onboarding).

---

## 13. Explicitly out of scope

- **Global Search** (Subjects/Faculty/Rooms filter chips + result cards) —
  appeared in an exploratory frame, confirmed not part of this build. Don't
  wire it, don't leave dead UI for it either.
- No photo avatars, no full names, no login/account screens anywhere (holds
  from `app-flow-v2.md`).
- No granular per-field "Change Degree / Change Year / Change Batch" —
  superseded by the single "Change timetable" reset link (Section 9).
