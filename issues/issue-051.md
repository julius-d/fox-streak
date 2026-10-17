Two integration tests are flaky on macOS, independent of any code change:
`lesson_overflow_menu_test.dart` ("learner skips via the overflow menu...")
and `xp_level_result_test.dart` ("a perfect-score lesson shows the XP
count-up..."). Confirmed during #045: both fail intermittently on
unmodified `main` too (not something #045 introduced), likely a
`pumpAndSettle`/animation-timing race (XP count-up, MCQ shuffle-dependent
text lookups). Worth a dedicated pass to make them deterministic (e.g. an
explicit pump count instead of relying on settle timing) so CI failures on
these two aren't misread as real regressions.
