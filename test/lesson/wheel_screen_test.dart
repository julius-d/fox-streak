// Widget tests for `WheelScreen` (issue #085).
//
// Covers what an integration test driving the whole `LessonScreen` can't
// easily isolate: that the spin — however it's stopped — always lands on
// the already-decided coin amount, and that the screen blocks back nav
// from the start (unlike the lootbox/streak-saved/XP-up screens, #082).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/lesson/wheel_screen.dart';
import 'package:fox_streak_app/src/pet/lootbox_reward.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

final _l10n = AppLocalizationsEn();

Widget _harness(int coinAmount) {
  return MaterialApp(
    theme: FoxStreakTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: WheelScreen(coinAmount: coinAmount, l10n: _l10n),
  );
}

/// The wheel's current rotation, in turns — the same `Animation<double>`
/// `WheelScreen` passes to its rotating `AnimatedBuilder`, read back via
/// its public `Animation` API rather than any private state.
double _currentRotationTurns(WidgetTester tester) {
  // Scoped to `wheelDial`'s own subtree: `FoxCelebration` (wrapped around
  // the dial once stopped) adds its own `AnimatedBuilder` *outside* this
  // key, so this finder stays unambiguous either way.
  final animatedBuilder = tester.widget<AnimatedBuilder>(
    find.descendant(
      of: find.byKey(const Key('wheelDial')),
      matching: find.byType(AnimatedBuilder),
    ),
  );
  return (animatedBuilder.listenable as Animation<double>).value;
}

void main() {
  group('wheelTargetRotationTurns', () {
    test('every amount lands on a distinct fractional turn, invariant to '
        'extraFullTurns', () {
      final fractions = kWheelCoinAmounts
          .map(
            (amount) => wheelTargetRotationTurns(amount, extraFullTurns: 0) % 1,
          )
          .toSet();
      expect(fractions, hasLength(kWheelCoinAmounts.length));

      for (final amount in kWheelCoinAmounts) {
        expect(
          wheelTargetRotationTurns(amount, extraFullTurns: 4) % 1,
          closeTo(
            wheelTargetRotationTurns(amount, extraFullTurns: 0) % 1,
            1e-9,
          ),
        );
      }
    });

    test('adds exactly extraFullTurns whole turns on top of the landing '
        'fraction', () {
      final withoutExtra = wheelTargetRotationTurns(30, extraFullTurns: 0);
      final withExtra = wheelTargetRotationTurns(30, extraFullTurns: 7);
      expect(withExtra - withoutExtra, closeTo(7, 1e-9));
    });
  });

  testWidgets('starts idle, tappable, with no Continue button yet', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(30));
    await tester.pump();

    expect(find.text(_l10n.wheelHeading), findsOneWidget);
    expect(find.byKey(const Key('wheelSpinButton')), findsOneWidget);
    expect(find.byKey(const Key('wheelContinueButton')), findsNothing);
  });

  testWidgets('blocks back navigation from the start (PopScope canPop: '
      'false)', (tester) async {
    await tester.pumpWidget(_harness(30));
    await tester.pump();

    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });

  testWidgets('a manual second tap stops the spin early, landing on the '
      'already-decided segment', (tester) async {
    await tester.pumpWidget(_harness(50));
    await tester.pump();

    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('wheelSpinButton'))); // early stop
    await tester.pumpAndSettle();

    expect(
      _currentRotationTurns(tester),
      closeTo(wheelTargetRotationTurns(50), 1e-9),
    );
    expect(find.text(_l10n.wheelWonText(50)), findsOneWidget);
    expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
  });

  testWidgets('letting the automatic timeout stop the spin lands on the same '
      'segment a manual stop would', (tester) async {
    await tester.pumpWidget(_harness(50));
    await tester.pump();

    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await tester.pumpAndSettle(); // never tapped again — auto-stop fires

    expect(
      _currentRotationTurns(tester),
      closeTo(wheelTargetRotationTurns(50), 1e-9),
    );
    expect(find.text(_l10n.wheelWonText(50)), findsOneWidget);
    expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
  });

  testWidgets(
    'a second tap during the wind-down (the stopping phase) is ignored — '
    "it doesn't restart the wind-down (regression guard)",
    (tester) async {
      await tester.pumpWidget(_harness(50));
      await tester.pump();

      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('wheelSpinButton'))); // 1st stop
      await tester.pump();

      // Partway through the 500ms wind-down: not stopped yet.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('wheelContinueButton')), findsNothing);

      // A tap landing here must be a no-op. Before the `stopping` phase
      // guard, `_phase` stayed `spinning` until the controller actually
      // completed, so this tap would have called `_stopSpin()` again,
      // restarting a fresh 500ms wind-down from "now" instead of letting
      // the original one (already 300ms in) finish on schedule.
      await tester.tap(find.byKey(const Key('wheelSpinButton')));

      // 50ms past the *original* wind-down's deadline (300 + 250 = 550ms
      // since the 1st stop tap) — already stopped only if the extra tap
      // above was genuinely ignored, not a restart.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
    },
  );

  testWidgets('Continue pops the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => WheelScreen(coinAmount: 20, l10n: _l10n),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wheelContinueButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wheelScreen')), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
