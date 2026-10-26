# Issue 081: Streak milestones have no distinct pet visual (on-fire painter was retired without a replacement)

Status: open | Priority: P3 | Type: tech-debt

## Context

`integration_test/streak_result_test.dart` (issue #011) originally asserted
a `foxPet-onFire` widget appeared on a streak-milestone completion (3/7/14/
30/50/100-day streaks, see `StreakService.kStreakMilestones`). Issue #059
retired the old on-fire/lit/empty-state pet painter in favor of the plain
equipped-pet celebration (`FoxPet` + `FoxCelebration`, no streak-aware
variant) — but never updated this test, which has asserted on a pet id
(`onFire`) that hasn't existed in any catalog since. Found and the stale
assertion removed while implementing issue #078 (lesson-completion screen
split), which moved the streak content to its own `StreakSavedScreen` and
would otherwise have carried the dead assertion forward.

## Goal

Decide (product call, not an engineering default) whether hitting a streak
milestone should show something visually distinct — e.g. a celebratory
pet variant/effect on `StreakSavedScreen` — and either implement it (with
test coverage) or close this issue as "working as intended, no milestone-
specific visual planned".

## Out of scope

Re-adding the specific old on-fire/lit/empty-state painter mechanism —
any new treatment should fit today's `FoxCelebration`/Lottie-based kit
(#015), not resurrect the retired custom painter.
