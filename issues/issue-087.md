# Issue 087: Streak on ice

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-31

## Context

#084 (Streak Details screen) already reserved exactly this feature: its
`daily_activity` table has a `DailyActivitySource.streakOnIce` enum value
that's unused today, and the calendar's `bucketFor` already guarantees a
`streakOnIce` day renders as at least the lowest non-empty bucket, never
"no activity" — both written specifically so this issue wouldn't need a
second schema migration.

This issue depends on #085 (Wheel of Fortune), which is itself still open
and unimplemented. **Build this after #085 lands**, and extend #085's wheel
at that point to include a "streak on ice" segment alongside its six coin
segments — #085's current "coins only" decision/out-of-scope line is
superseded by this issue once both are in.

## Goal

Let a user win a "streak on ice" from the Wheel of Fortune and stockpile
it. If the user misses exactly one day (opens the app on day N+2 with no
activity on day N+1), and has at least one streak-on-ice available, it's
automatically consumed to preserve the streak instead of resetting it to
1. The Streak Details calendar shows the saved day distinctly. Buying
streak-on-ice directly (separate from winning one) is a later, separate
issue.

## Decisions

- **Inventory — stackable count, uncapped**: new `profile_stats` column
  `streakFreezesAvailable` (INTEGER, default 0), written the same way
  `coinsTotal` is (a dedicated repository method, not ad-hoc SQL). No
  maximum; wheel wins just keep incrementing it. A future "buy ice" issue
  reuses the same increment method.
- **Winning it — new Wheel of Fortune segment, built on #085**: once #085
  ships, add a 7th wheel segment, "streak on ice", at a low draw weight
  (rarer than every coin amount — exact weight TBD at implementation time,
  but should read as a rare/exciting win compared to the 10-100 coin
  segments). Winning it increments `streakFreezesAvailable` by 1 instead of
  `coinsTotal`. This issue is blocked on #085's wheel mechanics (segment
  layout, predetermined-outcome-before-spin, `WheelScreen`) existing first.
- **Auto-apply trigger — app start, exactly one missed day**: checked once
  on app launch (alongside/near where `StreakService` already runs),
  before the user does anything else. Covers only a single missed day:
  `lastActiveDay` is exactly 2 local days before today (today's gap check
  in `StreakService.computeNext` terms) and `streakFreezesAvailable > 0`.
  A gap of 2+ full missed days is **not** covered — the streak resets to 1
  as today, and no ice is spent (multi-day bridging is explicitly out of
  scope, not an oversight).
- **Effect on streak state**: consumes one `streakFreezesAvailable`,
  writes a `daily_activity` row for the missed day (`source:
  DailyActivitySource.streakOnIce`, `xpEarned: 0`, reusing
  `StatsRepository.recordDailyActivity`), and advances
  `streak_count`/`last_active_day` as if the missed day had been active —
  i.e. the streak continues uninterrupted rather than resetting, without
  crediting any XP. This is a new, explicit code path (not inside the pure
  `computeNext` algorithm itself, so #011's existing streak-math contract
  and its tests stay untouched); it runs *before* `computeNext` would
  otherwise see and reset the gap.
- **One-time feedback on auto-apply**: when an ice is consumed, Home shows
  a one-time `FoxFeedbackBanner` (new `.info` or dedicated variant) stating
  the streak was saved with a streak-on-ice, so the save isn't silent.
  Shown once per occurrence, not persisted/repeated on subsequent app
  opens.
- **Calendar rendering — distinct icy-blue color, no icon**: superseding
  the original "ice cube icon" idea, a `streakOnIce` day renders in a
  distinct icy-blue color (a new token or a blue variant alongside
  `FoxSemanticColors.flame`, not reusing the flame hue at all) rather than
  the lowest flame bucket and rather than an icon overlay. `ActivityDay`
  (`lib/src/stats/activity_calendar.dart`) needs a way to distinguish
  "streakOnIce source" from a same-bucket low-XP lesson day (currently it
  only carries `xpEarned`/`hasActivity`/`level`) to drive this.
- **Count visibility**: the current `streakFreezesAvailable` count should
  be visible somewhere reasonable (e.g. Streak Details screen header, near
  the streak/longest-streak headline) so the user knows they have one
  banked — exact placement left to implementation, but it must be
  shown somewhere, not buried.

## Acceptance criteria

- [ ] New `profile_stats.streakFreezesAvailable` column (schema migration,
  default 0, existing rows migrate with no data loss).
- [ ] A repository method increments/decrements `streakFreezesAvailable`
  (mirroring `addCoins`'s shape); no ad-hoc SQL elsewhere.
- [ ] Once #085's wheel exists, one of its segments awards a streak-on-ice
  (increments `streakFreezesAvailable`) at a low/rare draw weight, never
  simultaneously with a coin win on the same spin.
- [ ] On app launch, if `lastActiveDay` is exactly 2 local days before
  today and `streakFreezesAvailable > 0`: one freeze is consumed, a
  `daily_activity` row is written for the missed day (`source:
  streakOnIce`, `xpEarned: 0`), and the streak continues (`streak_count`
  unchanged, `last_active_day` effectively bridged) instead of resetting
  to 1.
- [ ] A gap of 2+ full missed days still resets the streak to 1 as today,
  regardless of `streakFreezesAvailable` — no ice is spent.
- [ ] A one-time `FoxFeedbackBanner` on Home informs the user their streak
  was saved by a streak-on-ice, shown once for that occurrence only.
- [ ] Streak Details calendar renders a `streakOnIce` day in a distinct
  icy-blue color, visually different from every flame-bucket color.
- [ ] `streakFreezesAvailable` count is visible on screen (placement per
  implementation).
- [ ] New DE + EN l10n strings (auto-save banner text, freeze-count label)
  — no hardcoded strings.
- [ ] Tests: repository increment/decrement; the app-start auto-apply path
  (exactly-one-missed-day trigger, no-op when 0 available, no-op/reset-as-
  before when gap is 2+ days); calendar rendering of the icy-blue
  `streakOnIce` cell; wheel-segment win path (once #085 exists).
- [ ] `flutter analyze`, `dart format --output=none
  --set-exit-if-changed .`, `dart fix --dry-run`, and `flutter test` are
  all clean per AGENTS.md's Verify section.

## Out of scope

- Buying streak-on-ice directly — separate future issue (mentioned in the
  original draft, not designed here).
- Bridging gaps of 2+ missed days (spending multiple freezes to cover
  multiple missed days at once).
- A cap on `streakFreezesAvailable` — intentionally uncapped.
- An ice-cube icon/glyph — superseded by the icy-blue color decision above.
- Changing #085's coin segment table/weights beyond adding the new
  streak-on-ice segment.

## Dependencies

- Blocked on #085 (Wheel of Fortune) landing first — this issue adds a
  segment to that wheel and cannot be built before it exists.
- Builds on #084's reserved `DailyActivitySource.streakOnIce` enum value
  and calendar contract (`lib/src/stats/activity_calendar.dart`,
  `lib/src/data/stats_repository.dart`).
- Builds on #011 (`StreakService`/`streak_count`/`last_active_day`) without
  modifying its pure `computeNext` algorithm.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
