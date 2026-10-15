# Issue 036: Home XP goal ring shows stale "full" state on days with no activity

Status: open | Priority: P2 | Type: bug

## Goal
Fix `FoxGoalRing` on the home dashboard showing a stale "X / Y XP today"
value (e.g. "30 / 30 XP today", fully lit) on a day where the user has not
opened the app or completed any lesson at all.

Root cause: `profile_stats.todayXp` (`lib/src/data/database.dart`) is a
day-scoped accumulator, but it is only reset lazily, at write time, inside
`StatsRepository.addXp()` (`lib/src/data/stats_repository.dart`) — it
compares `profile.lastActiveDay` against the current day and resets
`todayXp` to the new delta only when a lesson is actually completed. There
is no app-launch/display-time check that zeroes it out just because a new
calendar day started while the app was closed.

`HomeScreen` (`lib/src/home/home_screen.dart`) reads `profile.todayXp` /
`profile.dailyGoalXp` directly to compute `goalProgress` and the ring's
center label (`l10n.homeGoalRingValue`), with no gate on whether
`profile.lastActiveDay` is actually today. This is inconsistent with the
streak badge right next to it, which already computes
`todayDone = profile.lastActiveDay == toLocalDayString(now)` and uses that
to drive its own display — the goal ring needs the same treatment.

Found while investigating a user report: XP wheel showed "30 of 30" despite
no app usage that day.

## Acceptance criteria
- [ ] The goal ring shows `0 / dailyGoalXp` (not the previous day's stale
      `todayXp`) whenever `profile.lastActiveDay` is not the current local
      day — mirroring the existing `todayDone` check already used for the
      streak badge in `home_screen.dart`.
- [ ] No change to `StatsRepository.addXp()`'s write-time reset logic — the
      underlying `todayXp` column can stay a lazily-reset accumulator; the
      fix is only in how `HomeScreen`/`FoxGoalRing` *display* it, not a
      stored-data migration or a scheduled/background reset job.
- [ ] A widget/unit test reproduces the symptom: seed `profile_stats` with
      `todayXp == dailyGoalXp` and `lastActiveDay` set to a day before
      "today" (using the overridable `Clock` from `test/data/`), then
      assert the rendered goal ring shows `0 / dailyGoalXp`, not
      `dailyGoalXp / dailyGoalXp`.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
      `dart fix --dry-run`, `flutter test` stay clean/green.

## Out of scope
- The separate text-overflow/clipping issue where the goal ring's center
  label can overlap the ring's arc (no size/`FittedBox` constraint on the
  label vs. the ring's inner diameter) — track that as its own issue if
  wanted; not fixed here.
- Adding UI to edit `dailyGoalXp` (currently only settable via
  `StatsRepository.updateDailyGoal()`, no screen wired up) — unrelated to
  the staleness bug.
- Any change to `xp_total`/level-progress display (`FoxLevelProgressBar`,
  `xp_service.dart`) — untouched, unrelated column.

## Dependencies
- Builds on #010 (`todayXp` column, `StatsRepository.addXp`) and #011
  (`lastActiveDay`, `StreakService`).
- Touches `lib/src/home/home_screen.dart`; no `lib/src/data/` changes
  expected.

## Verify
```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
# Manual: seed a profile with todayXp == dailyGoalXp and lastActiveDay set
# to yesterday, open Home without completing a lesson, confirm the ring
# shows 0 / dailyGoalXp rather than the stale full value.
```
