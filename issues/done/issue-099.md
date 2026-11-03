# Issue 099: LootboxScreen can restart the open animation in the background after a forced (stalled) reveal

Status: done | Priority: P3 | Type: tech-debt | Refined-at: 2026-11-01 | Completed-at: 2026-11-03

## Context

Found during code review of issue #079 (unrelated `BoundedLoopController`
extraction — this is pre-existing `lootbox_screen.dart` behavior the
review's diff happened to surface, not something #079 introduced or
touched).

`_open()` sets `_openRequested = true` if the real composition hasn't
decoded yet, and starts `_openStallTimer` (issue #098, default 5s). If
decode takes longer than `openStallTimeout`, `_handleOpenStalled` forces
`_phase = revealed` — but doesn't clear `_openRequested`. When the real
composition eventually finishes loading, `_handleCompositionLoaded` still
sees `_openRequested == true` and unconditionally calls
`_animationController.forward()`, even though `_phase` is already
`revealed`.

`_handleAnimationStatus`'s own `_phase != revealed` guard (added for
#098's "double-handling" case) means this doesn't re-trigger `setState`
or break the revealed UI — the `_LootboxAnimation`/Lottie widget using
this controller is no longer even in the tree by then (the `revealed`
branch replaces it), so nothing visibly replays. The only effect is a
wasted animation cycle ticking in the background. Low severity, but worth
closing since #098's own summary claimed this exact late-completion race
was "traced and confirmed safe."

Separately (same area, not worth its own issue): `openStallTimeout`'s 5s
default is justified only by a code comment ("safely above the real
composition's own duration") with no code-level check that it actually
exceeds `kLootboxOpenAnimationAsset`'s real duration — worth keeping in
mind if that asset is ever swapped for a longer one.

## Goal

Decide whether the wasted background replay is worth guarding against
(e.g. `_handleCompositionLoaded` skipping `forward()` once
`_phase != closed`, or clearing `_openRequested` in `_handleOpenStalled`)
and apply it if so.

## Out of scope

The `openStallTimeout` default's robustness against a future, longer
opening asset — not a correctness bug today, just a note for whoever
changes that asset.

## Summary

Fixed in `_handleCompositionLoaded` (`lib/src/pet/lootbox_screen.dart`):
only calls `_animationController.forward()` when `_openRequested` is true
*and* `_phase == opening`, so a late composition load after
`_handleOpenStalled` already forced `revealed` is a no-op.

No widget test added for this exact guard: the bundled test asset's
`Lottie` composition finishes decoding during `pumpWidget` itself, before
any tap can run, so `_openRequested` never becomes `true` in a widget test
— confirmed via a throwaway scratch test, same kind of gap already
documented in `lootbox_screen_test.dart`'s own header comment for the
sibling "composition never decodes" case. `flutter analyze`, `dart
format`, and `flutter test` (781 tests) are all green.

## Code review

Production code changed with no automated test exercising the new guard, conflicting with the "always add tests" rule.
Not fixed: verified the branch is genuinely unreachable in this widget-test harness (synchronous test-asset decode); the test file documents why, mirroring an existing precedent for the sibling untestable branch.
