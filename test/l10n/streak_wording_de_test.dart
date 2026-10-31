// DE wording for the streak concept uses "Streak", not "Serie" (issue
// #083). Pure-logic check, direct `AppLocalizationsDe` instantiation per
// `lib/l10n/README.md` (no widget tree needed).

import 'package:flutter_test/flutter_test.dart';

import 'package:fox_streak_app/l10n/app_localizations_de.dart';

void main() {
  final l10n = AppLocalizationsDe();

  test('lessonStreakResultText says "Streak", hyphenated like the EN form', () {
    expect(l10n.lessonStreakResultText(5), '5-Tage-Streak!');
  });

  test('lessonStreakSavedHeading says "Streak gesichert!"', () {
    expect(l10n.lessonStreakSavedHeading, 'Streak gesichert!');
  });

  test('onboardingSlide1Body says "deinen Streak", not "deine Serie"', () {
    expect(
      l10n.onboardingSlide1Body,
      'Übe jeden Tag ein bisschen und lass deinen Streak wachsen.',
    );
  });
}
