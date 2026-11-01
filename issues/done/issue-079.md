# Issue 079: Extract a shared "bounded breath/play, pause, repeat" animation helper

Status: done | Priority: P3 | Type: chore | Refined-at: 2026-10-26 | Completed-at: 2026-11-01

## Goal

`lib/src/widgets/fox_pet.dart`'s `_FoxPetState` (issue #071) and
`lib/src/pet/lootbox_screen.dart`'s `_LootboxScreenState` (issue #073) each
independently implement the same shape: an `AnimationController` that
plays a bounded animation once, then waits out a `Timer`-based pause
before repeating, for as long as the widget stays mounted and
`MediaQuery.disableAnimationsOf(context)` is false. They exist separately
because `fox_pet.dart` plays forward-only (0 -> 1, then re-`forward(from:
0)`) while `lootbox_screen.dart`'s pulse breathes forward-then-reverse
(a "ping-pong"), but the controller/timer/dispose/reduce-motion bookkeeping
around that difference is identical in both.

Flagged during #073's code review: a correctness fix applied to one
(e.g. #073 added a reduce-motion-mid-cycle reset) has no shared location
to live in, so the same class of bug could silently reappear in the
other.

## Why not fixed in #073

This would be a cross-file refactor touching the already-stable, tested
`FoxPet` widget (not just the new lootbox pulse), which is bigger than a
"small and easy fix" — out of scope for a bug-fix issue.

## Suggested shape (not binding — re-evaluate when picking this up)

A small helper, e.g. `BoundedLoopController` or a mixin, owning: the
`AnimationController`, the pause `Timer`, start/stop/reset methods, and
the reduce-motion check — parameterized by "forward-only" vs
"forward-then-reverse" playback. Migrate `FoxPet` and `LootboxScreen`'s
pulse onto it, keeping both widgets' existing tests green.

## Dependencies

None blocking; depends on #071 and #073 both already being merged.

## Summary

Added `lib/src/widgets/bounded_loop_controller.dart`'s `BoundedLoopController`
(`BoundedLoopPlayback.forwardOnly`/`.pingPong`), owning the
`AnimationController` + pause `Timer` + dispose bookkeeping. Migrated
`FoxPet` (forward-only) and `LootboxScreen`'s closed-state pulse
(ping-pong) onto it; both keep their own start/stop/reset call sites
since their lifecycles differ. As a side effect of unifying the "schedule
next cycle" logic, the shared class now re-checks `reduceMotion()` again
right before an already-scheduled pause fires (closing a race `FoxPet`
had but `LootboxScreen` didn't need, since its own `didChangeDependencies`
already reacted immediately) — `fox_pet_test.dart`/`lootbox_screen_test.dart`/
`pet_screens_test.dart`/the #073 integration test all stayed green
unchanged. New `test/widgets/bounded_loop_controller_test.dart` (9 tests)
drives the shared class directly. No UI changed visually, so no
screenshots.

## Code review

Reviewed via subagent (code-review skill, medium effort): both findings
were in pre-existing `lootbox_screen.dart` code this issue's diff never
touched (the #098 stall-timeout/`_openRequested` interaction).
Not fixed here — out of scope for this issue; filed as #099.
