# Issue 111: XpUpScreen's milestone pet (#081) has no a11y announcement

Status: done | Priority: P3 | Type: tech-debt | Refined-at: 2026-11-05 | Completed-at: 2026-11-05

## Goal

Give `XpUpScreen`'s milestone-only `FoxPet` (issue #081) a real
`semanticLabel` instead of `null`, so a screen-reader user is told about
the milestone, not just sighted users via the pet's presence.

## Context

Found during #081's code review. `FoxPet`'s doc (`fox_pet.dart`) allows
`semanticLabel: null` only for "a purely decorative repeat next to a
labelled heading" — the heading/streak text already announces the
moment, so the pet repeating it would be redundant. `StreakSavedScreen`
fits that: the pet sits right under `lessonStreakSavedHeading` and above
the streak-count text, both announced.

`XpUpScreen` doesn't fit it. That screen has no heading and no
streak/milestone text anywhere — just the milestone pet, immediately
followed by the unrelated `+XP` count-up. A screen-reader user reaching
`XpUpScreen` on a milestone completion hears the XP count but nothing
about the milestone at all; `semanticLabel: null` there silently drops
the moment for that user, which is the opposite of #081's goal.

Not fixed as part of #081 itself: a real label needs a new l10n string
(DE + EN, per AGENTS.md's "user-visible strings flow via `lib/l10n` arb
params"), which #081's acceptance criteria explicitly scoped out ("No new
l10n strings needed") — doing it right is a small but real product/copy
decision, not a one-line fix.

## Decision

A standalone "milestone streak" announcement, not a repeat of the exact
streak-day count. `StreakSavedScreen` (shown immediately before
`XpUpScreen` in the same completion sequence, whenever `isMilestone` is
true — see `LessonScreen._runCompletionSequence`) already announces the
exact `{streakCount}-day streak!` via its heading/streak text; `XpUpScreen`
only needs to flag that the pet showing up here is the same milestone
moment, not restate the number. This also avoids threading a new
`streakCount` param through `XpUpScreen`/`lesson_screen.dart` for a value
the user already heard seconds earlier.

## Acceptance Criteria

- New l10n string key `xpUpMilestonePetSemanticLabel` (DE + EN, no
  placeholders), added to both `lib/l10n/app_en.arb` and
  `lib/l10n/app_de.arb` with an `@xpUpMilestonePetSemanticLabel`
  description block (matching the existing `.arb` convention):
  - EN: "Streak milestone!"
  - DE: "Streak-Meilenstein!"
- `XpUpScreen`'s milestone `FoxPet` (xp_up_screen.dart) passes
  `l10n.xpUpMilestonePetSemanticLabel` as `semanticLabel` instead of `null`.
- `StreakSavedScreen`'s milestone `FoxPet` is unaffected (its `null` is
  already justified by its own heading/streak text) — no change to
  streak_saved_screen.dart.
- Test coverage: the `XpUpScreen` milestone test (added by #081, likely
  `test/lesson/xp_up_screen_test.dart`) asserts the `FoxPet`'s
  `semanticLabel` equals `l10n.xpUpMilestonePetSemanticLabel` on the
  milestone case, instead of (or in addition to) just asserting the
  `foxPet-<id>` key is present.

## Out of scope

- Any change to `StreakSavedScreen`, its confetti, or its existing
  streak-count text.
- Threading `streakCount` into `XpUpScreen` — the chosen wording doesn't
  need it (see Decision above).

## Summary

Added `xpUpMilestonePetSemanticLabel` ("Streak milestone!" / "Streak-
Meilenstein!") to both `.arb` files and regenerated l10n; `XpUpScreen`'s
milestone `FoxPet` now passes it as `semanticLabel` instead of `null`.
`StreakSavedScreen` untouched. Extended `test/lesson/xp_up_screen_test.dart`
and the existing end-to-end `integration_test/streak_result_test.dart` to
assert the label via `find.bySemanticsLabel`.

## Code review

- No findings from the `code-review` skill (medium effort) on the full diff.
  Nothing to fix.
