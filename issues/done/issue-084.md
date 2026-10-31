# Issue 084: Streak Details screen (GitHub-style activity calendar)

Status: done | Priority: P3 | Type: feature | Refined-at: 2026-10-31 | Completed-at: 2026-10-31

## Context

Home's `StreakBadge` (#011, `lib/src/home/home_screen.dart`) currently shows
only the live streak count + a "today done" check — it has no tap handler.
There is currently no persisted history of daily activity: `profile_stats`
only stores the *current* `streak_count`/`last_active_day` and a `today_xp`
that resets every day (#010/#011). Building a day-by-day calendar requires a
new persisted daily log; this issue adds it.

## Goal

Tapping the Home `StreakBadge` opens a new full-screen `StreakDetailsScreen`
showing a GitHub-contribution-style calendar: one cell per day, color
intensity by XP earned that day, with the current streak's run of days
highlighted.

## Decisions

- **New persisted daily log**, `daily_activity` table (new schema version):
  `day` (TEXT, local `YYYY-MM-DD`, primary key), `xpEarned` (INTEGER,
  default 0), `activitySource` (TEXT, NOT NULL). `activitySource` is a plain
  TEXT column backed by a Dart enum `DailyActivitySource { lessonCompleted,
  streakOnIce }`, enforced in Dart (matching the house convention used by
  `Items.type`), not Drift's `textEnum()` converter. `lessonCompleted` is
  written by this issue; `streakOnIce` is reserved for a future "streak on
  ice"/freeze feature — a day marked `streakOnIce` can have `xpEarned: 0`
  and no lesson completed, and the calendar must still light that day up.
  A day is "active" simply because a row exists; no separate boolean.
- **Write path**: `StatsRepository` gains `recordDailyActivity({required
  String day, required int xpDelta, required DailyActivitySource source})`,
  an upsert that adds `xpDelta` to the day's `xpEarned` and sets
  `activitySource` (first write wins per day — see open question below).
  `XpService.applyLessonResult` calls it (`source:
  DailyActivitySource.lessonCompleted, xpDelta: earned`) at the same call
  site as today's `addXp`, reusing the existing `xpApplied` guard — no
  second guard. This is deliberately not a single-feature "sole writer"
  column like the rest of `StatsRepository`: a future streak-freeze feature
  calls the same method with `source: DailyActivitySource.streakOnIce,
  xpDelta: 0`.
  - *Open question for implementation*: if a day ever gets both a real
    lesson and (later, once freeze exists) a freeze applied, should
    `activitySource` prefer `lessonCompleted` over `streakOnIce` on
    conflict? Not resolvable now since streak-freeze doesn't exist yet —
    flag for that follow-up issue rather than guessing here.
- **No backfill.** Days before this ships have no `daily_activity` row and
  render as "no activity", even if the user was actually active (known,
  accepted gap — there's no source to backfill exact XP from).
- **Range**: last ~6 months, horizontally scrollable, GitHub-style week
  columns (7-day-tall columns, oldest on the left, today on the right,
  initial scroll position at today). A current streak longer than 6 months
  will have its earlier days scrolled out of the default range — accepted
  as a v1 edge case, not engineered around.
- **Streak highlighting**:
  - *Current streak*: exact, from `profile.streakCount`/`lastActiveDay` —
    highlight that many consecutive days ending today (or yesterday, if
    today's lesson isn't done yet).
  - *Longest streak*: derived at render time from the visible ~6-month
    window only (longest run of consecutive days with a `daily_activity`
    row), not a stored lifetime max. Label this clearly as "longest in the
    last 6 months" (or similar), not an unqualified "longest streak ever"
    claim.
- **Color intensity**: 4 buckets on the `FoxSemanticColors.flame` token
  (no activity: neutral/empty; else by `xpEarned` relative to
  `profile.dailyGoalXp` — e.g. `>0–<50%`, `50–99%`, `>=100%` of goal) — exact
  thresholds are a UI-polish detail, left to implementation, but must reuse
  the flame token (#015), no ad-hoc colors. A `streakOnIce` day (whenever
  that exists) still needs a visible, distinct-from-empty cell even at
  `xpEarned: 0` — treat it as the lowest non-empty bucket.
- **Entry point**: wrap the existing `StreakBadge` on Home in an `InkWell`
  (same pattern as the pet-avatar tap, `home_screen.dart:231-247`), pushing
  `StreakDetailsScreen` via `Navigator.of(context).push<void>`.
- **Screen shape**: `AppBar` with a title + back button (standard
  `MaterialPageRoute` default), current-streak and longest-in-range headline
  text above the grid, a small legend for the color buckets, composed on
  #015's kit — no ad-hoc styling.

## Acceptance criteria

- [x] Tapping Home's `StreakBadge` opens `StreakDetailsScreen`.
- [x] Schema migration adds `daily_activity` (`day` PK, `xpEarned`,
  `activitySource`); existing DBs migrate cleanly with no data loss.
- [x] `StatsRepository.recordDailyActivity` upserts correctly: new day ->
  inserts; existing day -> adds `xpDelta` to `xpEarned`, sets
  `activitySource`.
- [x] `XpService.applyLessonResult` calls `recordDailyActivity` exactly once
  per completed lesson (reusing the `xpApplied` guard — no double-apply on
  rebuild/rotation), same as its existing `addXp` call, with `source:
  DailyActivitySource.lessonCompleted`.
- [x] Calendar renders one cell per day for the last ~6 months, scrollable,
  oldest-left/today-right, initial scroll position at today.
- [x] Cell color intensity reflects that day's `xpEarned` in 4 buckets
  (no-activity, low, medium, high) via `FoxSemanticColors.flame`; a day with
  a `daily_activity` row and `xpEarned: 0` renders as the lowest non-empty
  bucket, not as "no activity".
- [x] Current streak (exact count from `profile.streakCount`) is visually
  highlighted as a connected run of days ending today/yesterday.
- [x] Longest streak within the visible ~6-month window is visually
  highlighted (if different from the current streak) and labeled as
  windowed, not lifetime.
- [x] Tests: `StatsRepository.recordDailyActivity` upsert behavior (new day,
  repeat day, `activitySource` persistence); `XpService` wiring
  (exactly-once, guard reuse, correct `source` value); calendar widget
  rendering (bucket thresholds, current-streak highlight, longest-in-window
  highlight, empty/no-data days); Home tap navigation to
  `StreakDetailsScreen`.
- [x] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md.

## Out of scope

- Backfilling `daily_activity` for days before this ships.
- A stored lifetime "longest streak ever" value (would need its own column
  and write path — separate follow-up if wanted).
- Streak freeze/repair itself ("streak on ice") — only the
  `DailyActivitySource.streakOnIce` enum value is reserved now so that
  future issue doesn't need a second migration.
- Exact color-bucket thresholds / pixel-level cell sizing (left to
  implementation as a UI-polish detail).

## Dependencies

- Builds on #010 (XP formulas, `XpService`), #011 (`streak_count`/
  `last_active_day`, `StreakService`), #015 (kit/tokens,
  `FoxSemanticColors.flame`).
- `activitySource` enum is introduced now so a future streak-freeze/
  "streak on ice" issue doesn't need a second schema migration.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

Added schema v12 (`DailyActivity` table) + `DailyActivitySource` enum and
`StatsRepository.recordDailyActivity`/`getDailyActivityRange`
(transactional upsert, "first write wins" for `activitySource`).
`XpService.applyLessonResult` now writes `daily_activity` in the same
transaction as `addXp`. New pure logic in `lib/src/stats/activity_calendar.dart`
(window/bucket/streak-run math, independently unit-tested) backs
`ActivityCalendarView` (GitHub-style scrollable grid) and
`StreakDetailsScreen`, reached by tapping Home's `StreakBadge`
(now an `InkWell` + `MergeSemantics`). New `activityCalendarProvider`.
Coverage: data-layer + migration tests, `XpService`/`LessonController`
wiring tests, pure-logic unit tests, two widget-test files, a Home
navigation test, and `integration_test/issue084_streak_details_test.dart`
driving the real app end-to-end. Screenshots in `issues/done/`.

## Code review

- `XpService.applyLessonResult` ran `addXp` and `recordDailyActivity` as
  two separate un-transacted writes, with the `xpApplied` guard already
  latched before either ran — a crash between them could permanently
  desync `xpTotal` from `daily_activity`.
  Fixed: both now run inside one `StatsRepository.transaction()` call.
- `recordDailyActivity`'s select-then-insert/update wasn't itself
  transactional — harmless today, but a latent race once a second writer
  (e.g. a future streak-freeze feature) exists.
  Fixed: wrapped its body in `_db.transaction()`.
- Home's streak-badge tap target renders ~40dp tall, short of the 48dp a11y
  floor (`FoxButtonMetrics.minSize`).
  Not fixed here: resizing `StreakBadge` affects other (non-interactive)
  screens and its golden tests; tracked as follow-up issue #088.
- The `InkWell`+`Semantics(button)`+`Navigator.push` scaffolding is now
  hand-copied three times in `home_screen.dart`.
  Not fixed: two of the three call sites predate this issue; extracting a
  shared helper is a repo-wide refactor out of scope here.
- `activityCalendarProvider` sequentially awaited two independent reads
  (the profile future, the `daily_activity` range query).
  Fixed: both futures are now started before either is awaited.
- The legend swatch hardcoded `12` instead of the `FoxSpacing.md` token.
  Fixed: now uses `FoxSpacing.md`.
- `ActivityCalendarData.build`'s `activeDaysInWindow` re-filters `byDay`
  through the window days, which the reviewer flagged as possibly
  redundant given the sole current caller's query bounds.
  Not fixed: not dead code — it defends the function's general contract
  (callers aren't required to pre-bound `entries` to the window) at
  negligible cost.
- `longestRunInWindow` rebuilds its candidate run via a spread-copy on
  every active day (O(n²) over the ~183-day window).
  Not fixed: trivial at this scale (a cold path run once per screen open);
  not worth the added complexity.
- The streak badge's outer `Semantics(button: true)` nested with
  `StreakBadge`'s own internal `Semantics(label: ...)`, risking two
  separate screen-reader announcements instead of one.
  Fixed: wrapped both in `MergeSemantics`.
