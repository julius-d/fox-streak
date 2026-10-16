// Flow 1 — Library CRUD (issue #016, builds on #002/#003/#004).
//
// Drives the real app end-to-end: create a set, add one item of each type,
// rename, duplicate, delete with confirm; invalid inputs (empty title,
// future date, bad phone) are blocked rather than silently accepted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'create a set, add one item of each type (invalid inputs blocked), '
    'rename, duplicate, and delete with confirm',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 14, 9));

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      final l10n = AppLocalizationsEn();

      // --- Create: empty title is blocked ---
      await tester.tap(find.byKey(const Key('newSetFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);
      expect(find.byKey(const Key('titleField')), findsOneWidget);
      expect(find.text(l10n.errorRequired), findsWidgets);

      // --- Create: valid title + creator succeeds ---
      await tester.enterText(find.byKey(const Key('titleField')), 'Birthdays');
      await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);
      expect(listTileWithText('Birthdays'), findsOneWidget);

      // --- Open the new set, add one item of each type ---
      await tester.tap(listTileWithText('Birthdays'));
      await settle(tester);

      // Choice (default type): prompt + answer.
      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      expect(listTileWithText('Hund'), findsOneWidget);

      // FreeText.
      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('itemTypeField')));
      await settle(tester);
      await tester.tap(find.text(l10n.typeFreeText).last);
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('itemPromptField')),
        'Capital of France',
      );
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'Paris');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      expect(listTileWithText('Capital of France'), findsOneWidget);

      // Phone: a bad number is blocked (cancel out of it), then a fresh
      // add with the corrected number saves. Two separate dialogs rather
      // than fixing in place, so the invalid-input-blocked check doesn't
      // depend on how the live grouping formatter behaves after a second
      // full-text replacement in the same field.
      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('itemTypeField')));
      await settle(tester);
      await tester.tap(find.text(l10n.typePhone).last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Mama');
      await tester.enterText(find.byKey(const Key('itemAnswerField')), '12');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      expect(find.text(l10n.errorInvalidPhone), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await settle(tester);

      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('itemTypeField')));
      await settle(tester);
      await tester.tap(find.text(l10n.typePhone).last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Mama');
      await tester.enterText(
        find.byKey(const Key('itemAnswerField')),
        '01711234567',
      );
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      expect(listTileWithText('Mama'), findsOneWidget);

      // Date: a future date is blocked (cancel out of it), then a fresh
      // add with a valid birthday saves — same reasoning as phone above.
      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('itemTypeField')));
      await settle(tester);
      await tester.tap(find.text(l10n.typeDate).last);
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('itemPromptField')),
        'Omas Geburtstag',
      );
      await tester.enterText(find.byKey(const Key('itemDayField')), '01');
      await tester.enterText(find.byKey(const Key('itemMonthField')), '01');
      await tester.enterText(find.byKey(const Key('itemYearField')), '2099');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      expect(find.text(l10n.errorInvalidDate), findsOneWidget);
      await tester.tap(find.text(l10n.cancel));
      await settle(tester);

      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('itemTypeField')));
      await settle(tester);
      await tester.tap(find.text(l10n.typeDate).last);
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('itemPromptField')),
        'Omas Geburtstag',
      );
      await tester.enterText(find.byKey(const Key('itemDayField')), '01');
      await tester.enterText(find.byKey(const Key('itemMonthField')), '01');
      await tester.enterText(find.byKey(const Key('itemYearField')), '1950');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      expect(listTileWithText('Omas Geburtstag'), findsOneWidget);

      // Back to the library: rename, duplicate, delete-with-confirm.
      await tester.pageBack();
      await settle(tester);

      Finder setMenuFor(String title) => find.descendant(
        of: listTileWithText(title),
        matching: find.byType(PopupMenuButton<String>),
      );

      await tester.tap(setMenuFor('Birthdays'));
      await settle(tester);
      await tester.tap(find.text(l10n.rename));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('titleField')),
        'Family Birthdays',
      );
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);
      expect(listTileWithText('Family Birthdays'), findsOneWidget);
      expect(listTileWithText('Birthdays'), findsNothing);

      await tester.tap(setMenuFor('Family Birthdays'));
      await settle(tester);
      await tester.tap(find.text(l10n.duplicate));
      await settle(tester);
      expect(listTileWithText('Family Birthdays (copy)'), findsOneWidget);

      // Delete the duplicate: cancel is a no-op, confirm removes it.
      await tester.tap(setMenuFor('Family Birthdays (copy)'));
      await settle(tester);
      await tester.tap(find.text(l10n.delete));
      await settle(tester);
      await tester.tap(find.byKey(const Key('cancelDeleteSetButton')));
      await settle(tester);
      expect(listTileWithText('Family Birthdays (copy)'), findsOneWidget);

      await tester.tap(setMenuFor('Family Birthdays (copy)'));
      await settle(tester);
      await tester.tap(find.text(l10n.delete));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmDeleteSetButton')));
      await settle(tester);
      expect(listTileWithText('Family Birthdays (copy)'), findsNothing);
      expect(listTileWithText('Family Birthdays'), findsOneWidget);
    },
  );
}
