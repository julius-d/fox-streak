# Issue 081: Streak milestones have no distinct pet visual (on-fire painter was retired without a replacement)

Status: open | Priority: P3 | Type: tech-debt | Refined-at: 2026-11-04

## Goal

On a streak-milestone completion (3/7/14/30/50/100-day streak,
`StreakService.isMilestone`), show a distinct visual: the player's equipped
pet appears on both `StreakSavedScreen` and `XpUpScreen`, plus an enhanced
confetti burst on `StreakSavedScreen` — replacing the old on-fire painter
(#059) that was retired without a replacement.

## Context

`integration_test/streak_result_test.dart` (issue #011) originally asserted
a `foxPet-onFire` widget appeared on a streak-milestone completion. Issue
#059 retired the old on-fire/lit/empty-state pet painter in favor of the
plain equipped-pet celebration (`FoxPet` + `FoxCelebration`, no
streak-aware variant) — but never updated this test, which had asserted on
a pet id (`onFire`) that hasn't existed in any catalog since. Found and the
stale assertion removed while implementing issue #078 (lesson-completion
screen split), which moved the streak content to its own
`StreakSavedScreen`.

`StreakService.isMilestone` (lib/src/stats/streak_service.dart) already
exists and is unit-tested, but nothing in the UI calls it today.

## Decision

Implement a distinct milestone visual (not closing as "working as
intended"). Same treatment for every milestone size — no escalation by
3 vs. 100 days.

## Acceptance Criteria

- `LessonScreen._runCompletionSequence` (lesson_screen.dart) computes
  `final isMilestone = StreakService.isMilestone(state.streakCountAfterLesson ?? 0);`
  once, and resolves the equipped `PetEntry` the same way
  `_buildResultScreen` already does — from `state.equippedPetId` against
  `petCatalogProvider` (falling back to `PetCatalog.defaultEntry`), not via
  the live `equippedPetProvider` (see that method's existing comment for
  why). Passes `isMilestone` and `pet` into both `StreakSavedScreen` and
  `XpUpScreen`.
- `StreakSavedScreen` gains `isMilestone` (bool) and `pet` (PetEntry)
  params. When `isMilestone` is true, inserts `FoxPet(pet: pet, size: 96,
  semanticLabel: null)` between the heading (`lessonStreakSavedHeading`)
  and the existing `FoxCelebration`-wrapped streak-result text. On
  non-milestone days the layout is unchanged — no pet, as today.
- `_StreakConfettiEffects` gains an `isMilestone` param; when true, fires a
  denser/longer burst than today's fixed 60 particles / 500ms. Exact
  numbers are an implementation call, but must be clearly, visibly distinct
  from the non-milestone burst (e.g. roughly 2-3x the particles, and a
  noticeably longer duration).
- `XpUpScreen` gains the same `isMilestone` + `pet` params. When
  `isMilestone` is true, inserts `FoxPet(pet: pet, size: 96, semanticLabel:
  null)` before the existing `+XP` count-up. `_LevelUpEffects`'
  confetti/chime stays gated purely on `leveledUp`, unaffected by
  `isMilestone`.
- Both new `FoxPet` instances use `semanticLabel: null` — the kit's
  documented "purely decorative repeat next to a labelled heading"
  allowance (fox_pet.dart's doc comment) applies here, since each screen's
  heading/streak text is already announced. No new l10n strings needed.
- Pet size is 96 (FoxPet's default) on both screens, not Lootbox's larger
  160 — an accent here, not the screen's whole point like Lootbox's reveal.
- Test coverage:
  - `test/lesson/streak_saved_screen_test.dart`: a milestone case shows a
    `foxPet-<id>` key; a non-milestone case does not.
  - The equivalent test file for `XpUpScreen`: same milestone/non-milestone
    pet-presence split, independent of `leveledUp`.
  - A test asserting the milestone confetti burst's particle count/duration
    differ from the non-milestone defaults.
  - `test/lesson/lesson_shell_test.dart` (already exercises the completion
    sequence): a case where a milestone streak count results in both pushed
    screens receiving `isMilestone: true` and the correct equipped pet.

## Out of scope

- Re-adding the old on-fire/lit/empty-state custom painter — any new
  treatment fits today's `FoxCelebration`/Lottie kit (#015), not a
  resurrected painter.
- Escalating the visual by milestone tier (30/50/100 vs. 3/7/14) — identical
  treatment for every milestone.
- Any sound/haptics change, or reward/economy change (coins, XP, pet-draw
  odds) tied to hitting a milestone.
- Hero-animating the pet between `StreakSavedScreen`/`XpUpScreen`/the
  summary screen/Home — tracked separately as issue #109.
