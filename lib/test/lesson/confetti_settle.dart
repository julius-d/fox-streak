// Shared confetti-aware settle helper (issue #083), used by both
// `test/lesson/lesson_shell_test.dart` and `integration_test/helpers.dart`'s
// `settle()` — a single source of truth so the two don't drift (they
// previously duplicated this logic and had already diverged on whether a
// genuine non-confetti timeout actually fails the test).
//
// `StreakSavedScreen`'s unconditional confetti burst (and `XpUpScreen`'s
// level-up burst, issue #053) drives its particle physics off real
// wall-clock time rather than this binding's fake clock, so waiting for
// `WidgetTester.hasScheduledFrame` to go quiet — what a plain
// `pumpAndSettle()`/bounded settle loop does — spins until it times out.
// Once a confetti burst is confirmed playing, the screen underneath it has
// already rendered, which is all a settle helper promises.

import 'package:confetti/confetti.dart';
// This file lives under `lib/` (not `test/`) solely so it's importable via
// a `package:` URI from both `test/` and `integration_test/` — see
// `lib/test/lesson/helpers/placeholder_exercise_card.dart` for the same
// pattern. It's still test-only code, hence the otherwise-unwanted
// dev_dependency reference.
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';

/// Pumps in 100ms steps until the UI reports no more scheduled frames for 3
/// consecutive pumps (absorbing a one-beat-late stream notification — see
/// `integration_test/helpers.dart`'s own doc for that), or until a
/// [ConfettiWidget] is confirmed still playing.
///
/// The confetti check only starts after [confettiGraceMillis] (default
/// 500ms, matching the confetti burst's own configured duration) so a
/// confetti screen's own push transition — not driven by confetti — has
/// time to finish before any early return.
///
/// Known trade-off: a longer grace period would also let a fake-clock-driven
/// tween shown *alongside* a completion-sequence confetti screen (e.g.
/// `XpUpScreen`'s 900ms `FoxLevelProgressBar` level-up animation) finish
/// before this returns — but empirically, raising it enough to cover that
/// (1200ms) made at least one real integration test ~9x slower without any
/// test actually asserting on that bar's mid-tween position today. Left at
/// 500ms; revisit [confettiGraceMillis] at the call site if a test ever
/// needs to assert on that bar right after a level-up.
Future<void> confettiAwareSettle(
  WidgetTester tester, {
  int cap = 150,
  int confettiGraceMillis = 500,
}) async {
  var cleanStreak = 0;
  final confettiGraceIterations = confettiGraceMillis ~/ 100;
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (i >= confettiGraceIterations && _confettiStillPlaying(tester)) return;
    if (tester.binding.hasScheduledFrame) {
      cleanStreak = 0;
    } else {
      cleanStreak++;
      if (cleanStreak >= 3) return;
    }
  }
  fail('UI did not settle after $cap frames');
}

bool _confettiStillPlaying(WidgetTester tester) {
  return tester
      .widgetList<ConfettiWidget>(find.byType(ConfettiWidget))
      .any(
        (w) => w.confettiController.state == ConfettiControllerState.playing,
      );
}
