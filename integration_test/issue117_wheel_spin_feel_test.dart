// Issue #117 — richer wheel-of-fortune spin.
//
// Runs the real `WheelScreen` in a real app shell on-device: the idle
// invitation is visible and bounded, a second tap stops the spin early
// without ever leaving the screen stuck, the winning slice is highlighted
// after landing, and Continue still pops the screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/lesson/wheel_painter.dart';
import 'package:fox_streak_app/src/lesson/wheel_screen.dart';
import 'package:fox_streak_app/src/pet/lootbox_reward.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

Widget _app(WheelReward reward, {ThemeData? theme}) => ProviderScope(
  child: MaterialApp(
    theme: theme ?? FoxStreakTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const Key('openWheel'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    WheelScreen(reward: reward, l10n: AppLocalizationsEn()),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

WheelPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byKey(const Key('wheelDial')),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as WheelPainter;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final (name, theme) in <(String, ThemeData)>[
    ('light', FoxStreakTheme.light()),
    ('dark', FoxStreakTheme.dark()),
  ]) {
    testWidgets('wheel spins, stops early, highlights the win ($name)', (
      tester,
    ) async {
      const reward = WheelCoinsReward(75);
      await tester.pumpWidget(_app(reward, theme: theme));
      await tester.tap(find.byKey(const Key('openWheel')));
      await tester.pumpAndSettle();

      // Idle: tap prompt visible, nothing highlighted, loop is bounded.
      expect(find.byKey(const Key('wheelSpinButton')), findsOneWidget);
      expect(_painter(tester).winningIndex, isNull);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.tap(find.byKey(const Key('wheelSpinButton'))); // stop early
      await tester.pump(const Duration(milliseconds: 200));
      // Extra taps while winding down are ignored.
      await tester.tap(
        find.byKey(const Key('wheelSpinButton')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(_painter(tester).winningIndex, kWheelSegments.indexOf(reward));
      expect(find.text(AppLocalizationsEn().wheelWonText(75)), findsOneWidget);

      await tester.tap(find.byKey(const Key('wheelContinueButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wheelScreen')), findsNothing);
    });
  }
}
