// Widget tests for `XpUpScreen`'s back-nav blocking (issue #082).
//
// `XpUpScreen`'s XP count-up/level-up/confetti content is already exercised
// end-to-end by `integration_test/level_up_result_test.dart` and
// `integration_test/xp_level_result_test.dart`; this file covers only what
// those can't easily isolate: that system back/swipe is blocked from the
// first frame, mirroring `WheelScreen`'s own `PopScope` test
// (`test/lesson/wheel_screen_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/lesson/xp_up_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

final _l10n = AppLocalizationsEn();

Widget _harness() {
  return MaterialApp(
    theme: FoxStreakTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: XpUpScreen(
      xpEarned: 10,
      bonus: 0,
      xpTotal: 110,
      xpTotalBefore: 100,
      l10n: _l10n,
    ),
  );
}

void main() {
  testWidgets('blocks back navigation from the start (PopScope canPop: '
      'false, issue #082)', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });
}
