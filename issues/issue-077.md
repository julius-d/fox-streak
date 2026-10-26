# Issue 077: `level_up_result_test.dart` confetti assertion flaky/failing on macOS

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
