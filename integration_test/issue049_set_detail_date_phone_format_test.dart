// Issue #049 — Set detail screen shows raw unformatted date/phone answers.
//
// Drives the real app end-to-end: a `date` item's subtitle on
// `SetDetailScreen` must show the locale-formatted value (not the raw
// stored ISO `YYYY-MM-DD`), and a `phone` item's subtitle must show the
// grouped digits (not the raw unformatted digit string) — matching what
// the item editor and lesson exercise cards already show elsewhere.
//
// Runs under the device's real system locale (English in CI/dev, same as
// every other flow spec in this suite) rather than forcing German:
// `tester.binding.platformDispatcher.localeTestValue` only affects
// in-process widget tests, not the separate native app process this
// device-mode `integration_test` harness launches — confirmed by a debug
// probe where the override had no effect on the real app's rendered
// locale. The German `DD.MM.YYYY` branch of `formatDateForDisplay` is
// already covered by the `locale:` override in
// `test/library/set_detail_screen_test.dart` (a real widget test, where
// the override does apply).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations_en.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'set detail subtitle shows a locale-formatted date and grouped phone '
    'digits, never the raw stored value',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));
      final l10n = AppLocalizationsEn();

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      await openNewSetEditor(tester);
      await tester.enterText(find.byKey(const Key('titleField')), 'Family');
      await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);
      await openSetDetail(tester, 'Family');

      // --- Date item ---
      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('itemTypeField')));
      await settle(tester);
      await tester.tap(find.text(l10n.typeDate).last);
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('itemPromptField')),
        "Mama's birthday",
      );
      await tester.enterText(find.byKey(const Key('itemMonthField')), '05');
      await tester.enterText(find.byKey(const Key('itemDayField')), '14');
      await tester.enterText(find.byKey(const Key('itemYearField')), '1985');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);

      expect(listTileWithText("Mama's birthday"), findsOneWidget);
      expect(find.textContaining('05/14/1985'), findsOneWidget);
      expect(find.textContaining('1985-05-14'), findsNothing);

      // --- Phone item ---
      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('itemTypeField')));
      await settle(tester);
      await tester.tap(find.text(l10n.typePhone).last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Oma');
      await tester.enterText(
        find.byKey(const Key('itemAnswerField')),
        '01711234567',
      );
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);

      expect(listTileWithText('Oma'), findsOneWidget);
      expect(find.textContaining('017 112 345 67'), findsOneWidget);
      expect(find.textContaining('01711234567'), findsNothing);
    },
  );
}
