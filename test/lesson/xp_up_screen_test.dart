// Widget tests for `XpUpScreen`'s back-nav blocking (issue #082).
//
// `XpUpScreen`'s XP count-up/level-up/confetti content is already exercised
// end-to-end by `integration_test/level_up_result_test.dart` and
// `integration_test/xp_level_result_test.dart`; this file covers only what
// those can't easily isolate: that system back/swipe is blocked from the
// first frame, mirroring `WheelScreen`'s own `PopScope` test
// (`test/lesson/wheel_screen_test.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/l10n/app_localizations_en.dart';
import 'package:fox_streak_app/src/lesson/xp_up_screen.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

final _l10n = AppLocalizationsEn();

/// No-op fake (issue #054's seam): a leveled-up harness's `_LevelUpEffects`
/// would otherwise fall through to the real `audioplayers`-backed player
/// and hit a real platform channel.
class _FakeSoundPlayer implements FoxSoundPlayer {
  @override
  Future<void> playLevelUp() async {}

  @override
  Future<void> playCorrect() async {}
}

Widget _harness({
  bool isMilestone = false,
  int xpTotal = 110,
  int? xpTotalBefore = 100,
}) {
  return ProviderScope(
    overrides: [foxSoundPlayerProvider.overrideWithValue(_FakeSoundPlayer())],
    child: MaterialApp(
      theme: FoxStreakTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: XpUpScreen(
        xpEarned: 10,
        bonus: 0,
        xpTotal: xpTotal,
        xpTotalBefore: xpTotalBefore,
        isMilestone: isMilestone,
        pet: PetCatalog.defaultEntry,
        l10n: _l10n,
      ),
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

  testWidgets('shows the equipped pet on a milestone streak (issue #081)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(isMilestone: true));
    await tester.pump();

    expect(
      find.byKey(Key('foxPet-${PetCatalog.defaultEntry.id}')),
      findsOneWidget,
    );
  });

  testWidgets('shows no pet on a non-milestone streak', (tester) async {
    await tester.pumpWidget(_harness(isMilestone: false));
    await tester.pump();

    expect(
      find.byKey(Key('foxPet-${PetCatalog.defaultEntry.id}')),
      findsNothing,
    );
  });

  testWidgets(
    'shows the equipped pet on a milestone streak that also leveled up — '
    'pet presence is independent of leveledUp',
    (tester) async {
      await tester.pumpWidget(
        _harness(isMilestone: true, xpTotal: 100, xpTotalBefore: 0),
      );
      await tester.pump();

      expect(find.byKey(const Key('levelUpCallout')), findsOneWidget);
      expect(
        find.byKey(Key('foxPet-${PetCatalog.defaultEntry.id}')),
        findsOneWidget,
      );
    },
  );
}
