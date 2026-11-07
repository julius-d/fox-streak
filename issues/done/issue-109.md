# Issue 109: Hero-animate the equipped pet across the post-lesson completion sequence

Status: done | Priority: P3 | Type: enhancement
Completed-at: 2026-11-07

## Goal

When the equipped pet appears on consecutive screens in the post-lesson
flow — the summary screen's (`LessonResultScreen`) always-shown pet, and
`StreakSavedScreen`/`XpUpScreen`'s milestone-only pet (#081) — give it a
Hero flight between them instead of popping in fresh each time, and
best-effort extend that flight to Home when the completion sequence ends
there.

## Context

`LessonResultScreen` already renders the equipped pet
(`FoxPet(pet: pet, size: 120)`) unconditionally, underneath whatever
completion screens `LessonScreen._runCompletionSequence` pushes on top of
it. Each of `LootboxScreen`/`StreakSavedScreen`/`XpUpScreen` is pushed on
top of — and popped back down to — that same summary screen; they are
never pushed directly on top of each other. So a pet shown on, say,
`StreakSavedScreen` and then (per #081) on `XpUpScreen` right after doesn't
fly from one to the other directly: the transitions are
`Summary -> StreakSaved`, `StreakSaved -> Summary` (Continue),
`Summary -> XpUp`, `XpUp -> Summary` (Continue) — always through the shared
summary screen underneath.

A Hero tag already exists for the equipped pet: `equippedPetHeroTag`
(`lib/src/pet/pet_hero.dart`), used today only for Home <->
`PetCollectionScreen`. Its doc comment states the current invariant: "Each
screen renders at most one `FoxPet` wrapped with this tag at a time" —
adding it to `LessonResultScreen`/`StreakSavedScreen`/`XpUpScreen` stays
within that invariant (each still shows at most one pet), but widens where
the tag is used.

Going all the way to Home is harder: `LessonScreen._goHome` calls
`Navigator.popUntil((route) => route.isFirst)`, which can remove several
intermediate routes in one call depending on entry point (Lesson can be
reached from Home directly, or via Library/a Set's "Start lesson" FAB,
with other routes in between). Flutter's Hero mechanism is built around a
single push/pop between two adjacent routes; a multi-level `popUntil` isn't
guaranteed to animate a continuous flight the way a direct push/pop does.

## Decision

Best-effort: wire the Hero where it's a direct push/pop (`Summary <->
StreakSaved`, `Summary <-> XpUp`), and attempt it for the final pop-to-Home
too, but that leg isn't a hard requirement — if `popUntil`'s multi-level pop
can't carry the Hero cleanly for some entry points, falling back to
today's instant swap (no flight) there is acceptable, the same fallback
shape `FoxPet`/`wrapEquippedPetHero` already use for OS reduce-motion.

## Acceptance Criteria

- `LessonResultScreen`'s existing `FoxPet` is wrapped with
  `equippedPetHeroTag` (via `wrapEquippedPetHero`), consistent with
  Home/`PetCollectionScreen`'s existing usage.
- `StreakSavedScreen`'s and `XpUpScreen`'s milestone-only pet (#081) are
  each wrapped the same way, only when `isMilestone` is true — matching
  #081's "no pet at all on non-milestone days" (no Hero wrapper needed when
  there's no pet to wrap).
- Verify (automated test where feasible, otherwise manual + noted in the
  PR) that `Summary -> StreakSaved`, `StreakSaved -> Summary`,
  `Summary -> XpUp`, `XpUp -> Summary` each show a Hero flight rather than
  an instant pop-in, on a milestone completion.
- Investigate whether `_goHome`'s `popUntil` can carry the Hero flight to
  Home's pet, at least for the direct Home-entry case; document the
  outcome (works / falls back to instant swap) before closing this issue.
- No change to `pet_hero.dart`'s "at most one `FoxPet` wrapped per screen"
  invariant — every screen gaining the Hero still shows at most one.
- Respects the existing reduce-motion fallback (`wrapEquippedPetHero`
  already returns the child bare when OS reduce-motion is on) — no new
  motion toggle needed.

## Out of scope

- Any change to *whether* the pet appears on `StreakSavedScreen`/
  `XpUpScreen` — that's #081's milestone gate, assumed already shipped.
- Guaranteeing the Home leg works for every entry point — best-effort per
  the Decision above.

## Summary

- `LessonResultScreen`, `StreakSavedScreen` and `XpUpScreen` (milestone only) now wrap their pet with `wrapEquippedPetHero`; reduce-motion fallback and the "one wrapped pet per screen" invariant are unchanged.
- Home leg: verified by integration test (`issue109_pet_hero_completion_test.dart`) that the Hero flies Summary -> Home for the direct Home-entry case (single-route `popUntil`). Deeper entry points (Library / Set detail) are not tested; they may fall back to an instant swap.
- Gotcha: `confettiAwareSettle` can return mid-flight, so a widget test asserting on the destination pet needs an extra `pump` for the flight to land.

## Code review

- Summary Hero had no `flutter test` coverage (only integration).
  Fixed: added Hero-tag assertion in `lesson_shell_test.dart`.
- Misplaced `// Issue #109` comment in `xp_up_screen_test.dart`.
  Fixed.
- Hero sits inside `FoxCelebration` (possible scale jump at flight start).
  Not fixed: speculative; the integration test shows clean flights.
- StreakSaved pet has `semanticLabel: null` while others are labelled.
  Not fixed: pre-existing from #081, out of scope.
- Fixed 1s pump in the shell test could be flaky.
  Not fixed: fake clock makes it deterministic.
- Missing reduce-motion / non-milestone negative Hero tests, duplicated lookup helper.
  Not fixed: reduce-motion covered by #100 tests; non-milestone already asserts no pet.
- `_isFlying` heuristic is loose and timing-based.
  Not fixed: acceptable for a best-effort motion check.
