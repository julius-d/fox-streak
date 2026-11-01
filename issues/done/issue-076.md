# Issue 076: `xp_level_result_test.dart` can't find the "+25 XP" count-up text

Status: done | Priority: P3 | Type: tech-debt | Completed-at: 2026-11-01

## Context

Found while implementing #068 (mascot -> pet rename), unrelated to it —
this file was untouched by #068's changes and fails identically on `main`.

`integration_test/xp_level_result_test.dart`'s perfect-score test expects
`find.text('+25 XP')` after the result screen settles, but on a macOS
desktop integration run it finds 0 matching widgets. Likely a timing issue
with `_XpCountUp`'s `TweenAnimationBuilder` (the count-up animation) not
having reached/settled on its final text by the time the assertion runs,
rather than a real product bug — needs investigation to confirm and then
either a longer `pumpAndSettle`/explicit wait or a fix to whatever's
actually wrong.

## Summary

Confirmed: not a product bug. Reproduced by re-running the spec in a loop
(roughly 1 in 10-20 runs); the `xpUpScreen`/`xpEarnedLabel` keys were
already present when the failure hit, but the text wasn't yet `+25 XP` —
`pumpAndSettle()` had reported the UI settled a frame or two before
`_XpCountUp`'s 600ms `TweenAnimationBuilder` actually reached its final
value. Same class of real-time-vs-fake-clock race `pumpUntilFound` was
introduced for in #077's confetti-state check.

Fix: moved #077's `pumpUntilFound` helper out of `level_up_result_test.dart`
and into the shared `integration_test/helpers.dart` (both specs now import
it from there instead of `level_up_result_test.dart` keeping its own
copy), and used it in `xp_level_result_test.dart` to force extra frames
until the exact `+25 XP` text appears, right before asserting on it. No
product code changed. Ran the fixed spec dozens of times locally (across
a debug-instrumented variant and the final version) with no failures
(previously observed to fail roughly 1 in 10-20 runs); also re-ran
`level_up_result_test.dart` to confirm the helper's relocation didn't
change its behavior.

## Code review

Reviewed via subagent (general-purpose, focused prompt): the moved
`pumpUntilFound` is byte-for-byte unchanged and has no import/visibility
conflicts; the fix correctly forces extra frames past `pumpAndSettle()`'s
premature "settled" read. No findings — not fixed, none needed.
Minor style nit: the race is now explained in three places (file header +
two inline comments) in `xp_level_result_test.dart` — left as-is, not
worth trimming for a one-paragraph duplication.
