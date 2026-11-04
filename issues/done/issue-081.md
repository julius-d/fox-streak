# Issue 081: Streak milestones have no distinct pet visual (on-fire painter was retired without a replacement)

Status: done | Priority: P3 | Type: tech-debt | Refined-at: 2026-11-04 | Completed-at: 2026-11-04

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

## Summary

`LessonScreen._runCompletionSequence` computes `isMilestone` (gated on
`streakIsNewDayAfterLesson`, not just the count, so a same-day repeat
lesson sitting at a milestone count doesn't re-trigger it) and resolves
the equipped pet once, passing both into `StreakSavedScreen` and
`XpUpScreen`. Each shows a size-96 `FoxPet` (semanticLabel: null) only on
`isMilestone`; `StreakSavedScreen`'s confetti burst triples particles
(60 -> 180) and more than doubles duration (500ms -> 1200ms) on a
milestone, `XpUpScreen`'s level-up confetti/chime stays untouched.
Screenshots: `issue-081-streak-saved-milestone.png`,
`issue-081-xp-up-milestone.png`.

## Code review

- `isMilestone` was derived from the streak count alone, not gated on
  `streakIsNewDayAfterLesson` — a same-day repeat lesson sitting at an
  already-hit milestone count would wrongly re-show the pet on `XpUpScreen`.
  Fixed: gated on `streakIsNewDayAfterLesson == true` too; added a
  same-day-repeat regression case to the `lesson_shell_test.dart` milestone
  test.
- `XpUpScreen`'s milestone pet uses `semanticLabel: null`, but (unlike
  `StreakSavedScreen`) that screen has no heading/streak text to justify
  the kit's "decorative repeat next to a labelled heading" allowance —
  a screen-reader user gets no announcement of the milestone there.
  Not fixed here (needs a new l10n string, which this issue's acceptance
  criteria explicitly scoped out); filed as issue #111.
- The equipped pet is resolved once via `ref.read` in
  `_runCompletionSequence` and passed down, while `_buildResultScreen`
  independently re-resolves it via `ref.watch` for the same completion —
  two reads that could in theory diverge. Not fixed: both read the same
  already-completed `state.equippedPetId` from a static, near-instantly-
  loaded catalog, so the divergence window is theoretical; `ref.watch`
  isn't usable in `_runCompletionSequence`'s post-frame-callback context
  anyway.
- The new `_resolveEquippedPet` duplicates `equippedPetProvider`'s
  catalog-fallback matching logic. Not fixed: this is the same
  resolution `_buildResultScreen` already did pre-#081 (just extracted
  into a shared helper) — the issue's own acceptance criteria call for
  reusing exactly that resolution, not `equippedPetProvider`, so it's
  pre-existing, not new debt.
- The new `kStreakConfettiParticles`/`kStreakConfettiDuration` constants
  duplicate magic numbers (60 / 500ms) still inlined in `xp_up_screen.dart`'s
  level-up confetti. Not fixed: that confetti is a deliberately separate,
  milestone-unaffected burst per this issue's acceptance criteria: sharing
  constants across the two would be unrelated-scope cleanup.
