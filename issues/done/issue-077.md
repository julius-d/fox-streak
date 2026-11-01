# Issue 077: `level_up_result_test.dart` confetti assertion flaky/failing on macOS

Status: done | Priority: P3 | Type: tech-debt | Completed-at: 2026-11-01

## Context

Found while implementing #068 (mascot -> pet rename), unrelated to it —
this file was untouched by #068's changes and fails identically on `main`.

`integration_test/level_up_result_test.dart`'s level-boundary test expects
the `ConfettiController` to be in `ConfettiControllerState.playing` right
after the level-up result screen appears, but on a macOS desktop
integration run it's already `stopped` by the time the assertion runs.
Likely a timing race between `_LevelUpEffectsState.initState`'s
`controller.play()` call and the test's `pump`/`pumpAndSettle` sequence
(a short-lived confetti burst can finish before the assertion checks it)
rather than a real product bug — needs investigation to confirm and then
either a different assertion point or a fix to whatever's actually wrong.

## Summary

Confirmed: not a product bug. The `confetti` package's `ConfettiWidget`
only flips its controller to `stopped` once the particle system reports
"finished" — driven by real `DateTime.now()` deltas, not the test clock.
The old test pumped a fixed ~1.5s settle loop *before* asserting
`state == playing`, racing that real-time particle simulation; on a slow
run the burst can finish first.

Fix: added a `pumpUntilFound` helper and check `state == playing`
immediately once the XP-up screen mounts, *before* the long settle loop
that lets the other (finite) animations finish. Ran the level-boundary
test 5x in a row locally with no failures (previously observed to fail
intermittently). No product code changed.

## Code review

Reviewed via subagent (general-purpose, focused prompt): no findings.
Confirmed `xpUpScreen`/`levelUpConfetti`/the controller's `play()` call
all land in the same build/frame, so the reorder can't race-introduce a
new flakiness — n/a, not fixed.
`pumpUntilFound` silently no-ops on timeout instead of throwing; flagged
as a minor reusability footgun — not fixed, the one call site always
follows it with an `expect` that fails clearly, and the doc comment
calls this out.
