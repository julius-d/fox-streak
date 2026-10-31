// Widget tests for `StreakSavedScreen`'s confetti burst (issue #083).
//
// Covers the one thing an integration test driving the whole `LessonScreen`
// can't easily isolate: that the burst plays exactly once per screen
// instance, surviving a stray ancestor rebuild without replaying — same
// guarantee `XpUpScreen`'s `_LevelUpEffects` makes for its own level-up
// burst (see that file's doc).

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/lesson/streak_saved_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

final _l10n = AppLocalizationsEn();

/// Wraps [child] so a tap on 'rebuild' forces a real ancestor rebuild
/// (via `setState`) without changing [child]'s identity — the scenario
/// `_StreakConfettiEffects`'s doc guards against.
class _RebuildHarness extends StatefulWidget {
  final Widget child;
  const _RebuildHarness({required this.child});

  @override
  State<_RebuildHarness> createState() => _RebuildHarnessState();
}

class _RebuildHarnessState extends State<_RebuildHarness> {
  int _rebuildCount = 0;

  @override
  Widget build(BuildContext context) {
    // A Stack (not a Column/Expanded) so the rebuild trigger doesn't
    // disturb [child]'s own full-screen `Scaffold` sizing.
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          child: TextButton(
            onPressed: () => setState(() => _rebuildCount++),
            child: Text('rebuild $_rebuildCount'),
          ),
        ),
      ],
    );
  }
}

Widget _harness(int streakCount) {
  return MaterialApp(
    theme: FoxStreakTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _RebuildHarness(
      child: StreakSavedScreen(streakCount: streakCount, l10n: _l10n),
    ),
  );
}

void main() {
  testWidgets('shows a confetti burst, already playing on first mount', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(3));
    await tester.pump();

    final confetti = tester.widget<ConfettiWidget>(
      find.byKey(const Key('streakSavedConfetti')),
    );
    expect(confetti.confettiController.state, ConfettiControllerState.playing);
  });

  testWidgets('never replays the confetti burst on a stray ancestor rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(3));
    await tester.pump();

    final controllerBefore = tester
        .widget<ConfettiWidget>(find.byKey(const Key('streakSavedConfetti')))
        .confettiController;

    // An ancestor rebuild (not a fresh mount of StreakSavedScreen).
    await tester.tap(find.byType(TextButton));
    await tester.pump();

    final controllerAfter = tester
        .widget<ConfettiWidget>(find.byKey(const Key('streakSavedConfetti')))
        .confettiController;

    // Same controller instance -> `initState`/`play()` never reran.
    expect(identical(controllerBefore, controllerAfter), isTrue);
    expect(controllerAfter.state, ConfettiControllerState.playing);
  });
}
