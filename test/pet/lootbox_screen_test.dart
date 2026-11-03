// Widget tests for `LootboxScreen`'s `openStallTimeout` fallback (issue
// #098).
//
// Before #098, `PopScope(canPop: false)` (#082) had no escape if the
// opening Lottie never reached `AnimationStatus.completed` — Continue only
// renders once `_phase` reaches `revealed`, and that normally only happens
// via the Lottie's own completion. These tests drive that stall path
// directly via `openStallTimeout: Duration.zero` (a seam `LootboxScreen`
// exposes for exactly this, since a real composition failing to decode
// isn't reproducible from a bundled, always-valid test asset) rather than
// via the real animation's own (several-hundred-millisecond-plus) duration,
// which an integration test already covers end-to-end
// (`issue062_lootbox_animation_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/pet/lootbox_reward.dart';
import 'package:fox_streak_app/src/pet/lootbox_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

final _l10n = AppLocalizationsEn();

Widget _harness(
  LootboxReward reward, {
  Duration openStallTimeout = const Duration(seconds: 5),
}) {
  return MaterialApp(
    theme: FoxStreakTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: LootboxScreen(
      reward: reward,
      l10n: _l10n,
      openStallTimeout: openStallTimeout,
    ),
  );
}

void main() {
  testWidgets('blocks back navigation from the start (PopScope canPop: '
      'false, issue #082)', (tester) async {
    await tester.pumpWidget(_harness(const CoinsReward(30)));
    await tester.pump();

    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });

  testWidgets(
    'forces the reveal once openStallTimeout elapses without the opening '
    'animation completing on its own (#098)',
    (tester) async {
      await tester.pumpWidget(
        _harness(const CoinsReward(30), openStallTimeout: Duration.zero),
      );
      await tester.pump();
      expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);

      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      // 1ms, not 0: long enough for the zero-duration stall timer to fire,
      // nowhere near long enough for the real (several-hundred-ms-plus)
      // opening animation to reach `completed` on its own — so this proves
      // the stall path forced the reveal, not a coincidentally-fast real
      // completion.
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byKey(const Key('lootboxContinueButton')), findsOneWidget);
      expect(find.text(_l10n.lootboxCoinsRevealedTitle(30)), findsOneWidget);
      // Still blocks back nav after the forced reveal — the fallback must
      // not weaken #082's invariant.
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    },
  );

  testWidgets(
    'Continue pops the screen after a stalled open forces the reveal',
    (tester) async {
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
                      builder: (_) => LootboxScreen(
                        reward: const CoinsReward(30),
                        l10n: _l10n,
                        openStallTimeout: Duration.zero,
                      ),
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

      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const Key('lootboxContinueButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('lootboxContinueButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'a normal open (no stall) reaches revealed via the real animation, '
    'never via the stall fallback',
    (tester) async {
      await tester.pumpWidget(_harness(const CoinsReward(30)));
      await tester.pump();

      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await tester.pump();
      expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lootboxContinueButton')), findsOneWidget);
      expect(find.text(_l10n.lootboxCoinsRevealedTitle(30)), findsOneWidget);
    },
  );

  // No widget test for #099's fix (the `_phase == opening` guard added to
  // `_handleCompositionLoaded` in lootbox_screen.dart): that guard only
  // matters when `_handleOpenStalled` forces `revealed` *before* the real
  // composition finishes decoding, i.e. with `_openRequested` still true.
  // Confirmed (scratch-tested, not committed) that this harness's bundled
  // test asset finishes decoding during `pumpWidget` itself, before any
  // tap can run — so `_compositionLoaded` is always already `true` by the
  // time `_open()` runs, `_openRequested` is never set, and that branch is
  // unreachable from a widget test here. Same kind of gap this file's own
  // header comment already documents for the sibling "composition never
  // decodes" case.
}
