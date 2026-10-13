# Issue 010: XP + levels system

Status: open | Priority: P1 | Type: gamification | Refined-at: 2026-10-13

## Goal
Duolingo-like XP per correct answer, levels to chase — gives learners a number that goes up every lesson, without punishing wrong answers.

## Duolingo reference
~10 XP per lesson, combo bonuses. Levels give progression without punishing teens.

## Decisions (2026-10-12, with repo owner)
- Trigger: `LessonController` applies XP once when the lesson reaches `phase: done` (same place `correctCount`/`scorePct` are computed, `lesson_controller.dart:278-287`) via `XpService`; a guard flag in `LessonState` prevents re-applying on rebuild/rotation.
- XP tiers: correct & no hint = 10 XP; correct & hint used (`hintUsed: true`, already live via #008, planned for #007/#009) = 5 XP; wrong or skipped = 0 XP. `firstTry` stays recorded on the outcome but drops out of the XP formula — no retry mechanism exists in v1 (#005 one-shot grading), so it's always true; the old "second try" wording is dropped as dead.
- Lesson bonus: +5 XP flat when `scorePct == 100` (zero wrong/skipped), added once per lesson on top of per-item XP.
- Bonus display (2026-10-13): shown as a separate callout, not folded into the per-item count-up — e.g. a "+5 Perfect!" badge/line that appears alongside/after the XP-earned count-up when the bonus applies, distinct from the main total.
- Daily goal: dropped from #010 entirely. #002 already owns `dailyGoalXp`/`updateDailyGoal` on `StatsRepository`; the goal-ring UI is #012's acceptance criterion.
- Level widget scope: #010 builds the level-progress widget (composed on #015's `FoxProgressBar`) and wires it into `LessonResultScreen` only, replacing the "XP — coming soon" stub. Home wiring is #012's job (its task 1: "HomeScreen composition from #010/#011 widgets").
- Animation: simple non-lottie XP count-up/pop reusing #015 `FoxCelebration` tokens — consistent with #015's "animation budget leaves room for #014 lottie, no lottie dep" note.
- Persistence: `StatsRepository` gains `addXp(int delta)` (read-modify-write `xpTotal`, mirrors the existing `updateDailyGoal` pattern); `XpService` is its only caller, per #002's sole-writer rule.
- Daily XP tracking (added 2026-10-13, flagged by #012): `profile_stats` gains a `today_xp` column (schema migration v2→v3, part of #012's Task 1 migration). `XpService`'s call into `StatsRepository` must also maintain it: reset `today_xp` to this lesson's earned XP when `last_active_day` shows the day has rolled over, otherwise accumulate — same call site, same guard flag as the `xp_total` write. #012's `FoxGoalRing` reads `today_xp` read-only; #010 remains its sole writer.

## Acceptance criteria
- [ ] XP formula: 10 XP per correct answer with no hint; 5 XP per correct answer with `hintUsed: true`; 0 XP for wrong or skipped; +5 flat lesson bonus when `scorePct == 100`
- [ ] Level formula: `level = floor(sqrt(xpTotal / 100)) + 1`; thresholds `xpForLevel(n) = (n-1)^2 * 100`; progress-to-next = `(xpTotal - xpForLevel(level)) / (xpForLevel(level+1) - xpForLevel(level))`
- [ ] `XpService.applyLessonResult(LessonResult)` is the sole writer of `xp_total` (via new `StatsRepository.addXp`), called exactly once per completed lesson by `LessonController` on reaching `phase: done`; a `LessonState` guard flag prevents double-apply on rebuild/rotation
- [ ] `LessonResultScreen`'s XP/level stub rows replaced with: animated XP-earned count-up (no lottie dep) + a separate "+5 Perfect!" bonus callout shown only when `scorePct == 100` + level-progress widget (gold fill, "Level N", progress-to-next; composed on `FoxProgressBar` per #015)
- [ ] `xp_total` is a lifetime accumulator — no daily reset; accumulates correctly across multiple lessons/sessions same day and across days
- [ ] `today_xp` (per #012) resets to the lesson's earned XP on a day change and accumulates across same-day lessons, written at the same call site/guard as `xp_total`
- [ ] Unit tests: XP per tier (10/5/0 + bonus), level formula edge cases (xp=0, exact thresholds, large values), accumulation across multiple `applyLessonResult` calls, no double-apply on repeated calls / simulated rebuild
- [ ] Follows #015: level-progress widget reuses `FoxProgressBar` + XP-gold semantic token, no ad-hoc styling; all strings via `lib/l10n` arb params (DE + EN)

## Tasks
1. `StatsRepository.addXp(int delta)` (mirrors `updateDailyGoal`)
2. `XpService` (pure logic: `xpForOutcome`, `lessonBonus`, `levelForXp`, `progressToNextLevel`) + `applyLessonResult(LessonResult)` wiring to `StatsRepository.addXp`
3. Wire into `LessonController`: call once on transition to `phase: done`; add guard flag to `LessonState`
4. Also maintain `today_xp` at the same call site (per #012): reset on day change, else accumulate — depends on #012's Task 1 migration (schema v2→v3) landing first
5. Level-progress widget (composed on `FoxProgressBar`) wired into `LessonResultScreen`, replacing the XP stub row; include the separate "+5 Perfect!" bonus callout (only rendered when the bonus applied)
6. l10n: arb keys for XP-earned label, level label, progress text, bonus-callout text (DE + EN)
7. Stable keys for #016: e.g. `xpEarnedLabel`, `levelProgressBar`
8. Tests: `test/stats/xp_service_test.dart` (formula + level math + `today_xp` reset/accumulate) + lesson-shell integration test asserting `xp_total`/`today_xp` update exactly once per lesson and survive rotation without double-counting

## Out of scope
- Streaks (#011), leaderboards (post-MVP)
- Daily-goal ring widget itself (`FoxGoalRing`) and its Home wiring — #012 builds and owns the UI; #010 only writes the `today_xp` value it reads
- Home-screen wiring of the level-progress widget (#012)
- "Second try" XP tier — dropped, no retry mechanism exists in v1

## Dependencies
- Builds on #002 (`xp_total` sole-writer rule), #005 (`LessonResult`/`LessonItemOutcome`, with `hintUsed` live via #008), #015 (`FoxProgressBar`, XP-gold token, `FoxCelebration`)
- Depends on #012's Task 1 (schema migration v2→v3 adding `today_xp`) landing before Task 4 of this issue can write to it
- Unblocks #011 (streak write must happen after #010's XP write — see #011's own follow-up note) and #012 (Home composes the level-progress widget and reads `today_xp` for `FoxGoalRing`)

## Follow-up (from #005 review 2026-10-11)
- Consumes #005 `LessonResult`: maps each outcome (`correct`/`skipped`/`hintUsed`) to XP (10 / 5 hint / 0 wrong); sole writer of `xp_total` per #002.

## Follow-up (from #012 refinement 2026-10-13)
- #012 needs an "XP earned today" value for its new `FoxGoalRing` widget. Rather than #012 writing it, `today_xp` was added to #010's scope (Decisions above) since it's the same sole-writer call site as `xp_total` — keeps the "#010 is the only thing touching XP columns" rule intact instead of splitting writes across two services.

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```
