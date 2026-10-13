# Issue 011: Streak system (fox-streak core)

Status: done | Priority: P1 | Type: gamification | Refined-at: 2026-10-13

## Goal
Daily streak = retention hook and namesake of fox-streak.

## Duolingo reference
Streak counts consecutive days with ≥1 lesson; Duolingo uses streak freeze/repair — we do simple v1, no shop.

## Decisions (2026-10-13, with repo owner)
- Trigger: streak counts *lesson completion*, not XP earned — a lesson with 0 correct answers still extends the streak (matches #010's "without punishing wrong answers" spirit and the Duolingo reference's "≥1 lesson" wording). `StreakService.recordActivity(now)` is called by `LessonController` on the same `phase: done` transition #010 uses, right after `XpService.applyLessonResult`, reusing #010's existing guard flag (one shared one-time-per-lesson gate, not a second guard).
- Day algorithm (local tz, via `Clock`/`toLocalDayString`/`parseDayString` in `clock.dart` — already built for #011 reuse, do not reimplement day math):
  - `lastActiveDay == null` (first ever activity) → `streak_count = 1`, `isNewDay = true`
  - `lastActiveDay == today` → unchanged, `isNewDay = false` (same-day replay never double-counts)
  - `lastActiveDay == yesterday` → `streak_count = streak_count + 1`, `isNewDay = true`
  - otherwise (gap of ≥2 days, i.e. a missed day) → `streak_count` resets and restarts at `1` for today, `isNewDay = true`
- Mascot/badge states (shared enum with #015's `FoxMascotState`): `empty` — no activity today and `streak_count == 0`; `on-fire` — today's `streak_count` is a milestone value, fixed v1 set `{3, 7, 14, 30, 50, 100}`; `lit` — active today (or `streak_count > 0`) and not a milestone. Since `streak_count` changes at most once per day, a milestone value is only ever current on the day it's reached, so this doubles as the "moment" without extra state.
- Persistence: `StatsRepository` gains a streak-write method (mirrors #010's `addXp`, e.g. `setStreak({required int streakCount, required String lastActiveDay})`); `StreakService` is its only caller, per #002's sole-writer rule.
- Result-screen closeout: `LessonResultScreen`'s `lessonStreakComingSoon` stub (parallel to the XP stub #010 just closed) is replaced with real streak info. The screen's existing `FoxMascot` (currently `lit`/`empty` by `scorePct`) is upgraded: show `on-fire` when this lesson's `StreakService.recordActivity` call just hit a milestone, otherwise keep the existing lit/empty-by-score behavior.
- Notifications/reminders: dropped from this issue's tasks entirely — no notification issue exists, and #002 already lists notifications as fully out of scope for the app. Moved to `Out of scope` below rather than left as a dangling "hook point".

## Acceptance criteria
- [x] Streak +1 when the first lesson of a new calendar day (local tz) completes — any outcome, including a lesson with 0 correct answers; same-day replays never double-count
- [x] Day algorithm exactly as decided above: no prior day → 1; same day → unchanged; consecutive day → +1; gap of ≥2 days → resets to 1
- [x] Mascot/badge state: `empty` (streak 0, no activity today), `lit` (active/streak>0, not a milestone), `on-fire` (today's `streak_count` ∈ `{3, 7, 14, 30, 50, 100}`)
- [x] `StreakService.recordActivity` is the sole writer of `streak_count`/`last_active_day` (via new `StatsRepository` method), called exactly once per completed lesson by `LessonController`, after #010's XP write, reusing its `phase: done` guard — no double-apply on rebuild/rotation
- [x] `StreakBadge` widget: flame icon (`FoxSemanticColors.flame` token) + streak count + "today done" indicator, composed on #015's kit (no ad-hoc styling)
- [x] `LessonResultScreen`'s `lessonStreakComingSoon` stub replaced with real streak info; mascot shows `on-fire` when this lesson just hit a milestone, else existing lit/empty-by-score behavior holds
- [x] Unit tests: day-boundary matrix (no-prior-day / same-day / consecutive-day / gap-day, local-tz edges) with fake clock, milestone detection for all six values, no double-apply on repeated calls / simulated rebuild
- [x] Follows #015: `FoxMascot` on-fire state + `flame` semantic token reused, no ad-hoc styling; all strings via `lib/l10n` arb params (DE + EN)

## Tasks
1. `StatsRepository.setStreak({required int streakCount, required String lastActiveDay})` (mirrors #010's `addXp`)
2. `StreakService` (pure logic: `recordActivity(DateTime now, {required int currentStreak, required String? lastActiveDay})` → `{streakCount, isNewDay}`, `isMilestone(int streakCount)`) + wiring to `StatsRepository.setStreak`
3. Wire into `LessonController`: call once on transition to `phase: done`, immediately after the #010 XP write, reusing its existing guard flag
4. `StreakBadge` widget (flame icon + count + "today done" check), composed on #015 kit
5. Update `LessonResultScreen`: replace `lessonStreakComingSoon` stub with real streak info; upgrade `FoxMascot` to show `on-fire` on milestone lessons
6. l10n: arb keys for streak-count label, "today done" indicator, result-screen streak text (DE + EN)
7. Stable keys for #016: e.g. `streakBadge`, `streakCountLabel`
8. Tests: `test/stats/streak_service_test.dart` (day-boundary matrix + milestone detection) + lesson-shell integration test asserting `streak_count`/`last_active_day` update exactly once per lesson and survive rotation without double-counting

## Out of scope
- Streak freeze / repair (post-MVP)
- Push/local notifications and reminders — no issue currently plans this; #002 already lists notifications as fully out of scope for the app
- Leaderboards (post-MVP)
- Home-screen wiring of `StreakBadge` (#012's job, parallel to #010's level widget)

## Dependencies
- Builds on #002 (`streak_count`/`last_active_day` sole-writer rule + schema), #005 (`LessonResult`, `LessonController`'s `phase: done` hook), #010 (XP write happens first at the same trigger site; #011 reuses its guard flag), #015 (`FoxMascot` on-fire state, `flame` semantic token, widget kit)
- Unblocks #012 (Home composes `StreakBadge`)

## Follow-up (from #005 review 2026-10-11)
- Consumes #005 `LessonResult` after #010's XP write: first lesson of a new local day increments `streak_count`; sole writer of `streak_count`/`last_active_day` per #002. `on-fire` mascot state belongs here — replacing the result-screen stub — never shown from #005/#010 score logic alone.

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

## Summary (implemented 2026-10-13)
- `StreakService` (`lib/src/stats/streak_service.dart`) holds the pure day algorithm (`computeNext`), `isMilestone` (fixed `{3,7,14,30,50,100}` set), and `recordActivity()` — reads the profile, runs `computeNext` against the clock's current time, and persists via the new `StatsRepository.setStreak(streakCount, lastActiveDay)` (full overwrite, mirrors #010's `addXp`).
- `LessonController._completeLesson()` now calls `_streakService.recordActivity()` right after `_xpService.applyLessonResult(result)`, reusing the single `xpApplied` guard — no second guard flag. New `LessonState.streakCountAfterLesson` field (parallel to `xpTotalAfterLesson`) is set in the same atomic state update as `phase: done`, for the same "no transient pre-write render" reason #010 fixed.
- `LessonResultScreen`: mascot is `on-fire` whenever `StreakService.isMilestone(streakCountAfterLesson)`, else falls back to the existing lit/empty-by-score behavior; `lessonStreakComingSoon` stub replaced with a streak headline (`lessonStreakResultText`) + the new `StreakBadge` widget (keys `streakBadge`, `streakCountLabel`).
- New kit widget `StreakBadge` (`lib/src/widgets/streak_badge.dart`): dumb/display-only, flame icon + count + optional "today done" check, token-driven via `FoxSemanticColors.flame`.
- l10n: 3 new arb keys (`lessonStreakResultText`, `streakCountLabel`, `streakTodayDoneLabel`), DE+EN; removed the now-dead `lessonStreakComingSoon` key.
- Tests: `test/stats/streak_service_test.dart` (day-boundary matrix incl. local-tz edges, milestone detection, `recordActivity` persistence/idempotence), `test/lesson/lesson_controller_streak_test.dart` (controller wiring: exactly-once via CONTINUE/SKIP, 0-correct-answer lesson still extends streak, shared-guard no-double-apply, restart), extended `stats_repository_test.dart`/`kit_test.dart`, updated `lesson_shell_test.dart`'s now-obsolete "streak untouched" assertion, new `integration_test/streak_result_test.dart` (drives a real milestone lesson, asserts on-fire mascot + badge render + exactly-once DB write). Full suite (255 tests) + integration tests pass; `flutter analyze`/`dart format`/`dart fix --dry-run` clean.
- Fixed in review: `computeNext`'s "yesterday" was computed via `now.subtract(Duration(days: 1))`, absolute-time arithmetic that lands on the wrong local calendar date across a DST transition (a civil "day" isn't always 24 wall-clock hours) — a user active the day before a spring-forward could get their streak wrongly reset instead of incremented. Fixed to calendar-field subtraction (`DateTime(now.year, now.month, now.day - 1)`), which is TZ-independent; added a regression test documenting the EU 2026-03-29 spring-forward case.
