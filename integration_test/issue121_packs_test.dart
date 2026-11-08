// Packs in the Library (issue #121).
//
// Drives the real app: with one pack the Library is a plain list; creating a
// set into an inline-created second pack introduces collapsible sections;
// a set can be moved between own packs; packs can be renamed and deleted
// (with the set count in the confirmation).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

Future<void> _createSet(
  WidgetTester tester,
  String title, {
  String? newPackTitle,
}) async {
  await openNewSetEditor(tester);
  await tester.enterText(find.byKey(const Key('titleField')), title);
  await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
  if (newPackTitle != null) {
    await tester.tap(find.byKey(const Key('packPicker')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('packPickerNewPackOption')).last);
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('newPackTitleField')),
      newPackTitle,
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('createPackButton')));
    await tester.tap(find.byKey(const Key('createPackButton')));
    await settle(tester);
  }
  await tester.ensureVisible(find.byKey(const Key('saveSetButton')));
  await tester.tap(find.byKey(const Key('saveSetButton')));
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'one pack is a plain list; a second pack adds collapsible sections; '
    'sets move between own packs; packs can be renamed and deleted',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 14, 9));

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      // --- One pack: plain list, no section header ---
      await _createSet(tester, 'Alpha');
      expect(listTileWithText('Alpha'), findsOneWidget);
      expect(find.text('My sets'), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // --- Second pack created inline while adding a set ---
      await _createSet(tester, 'Beta', newPackTitle: 'Trip');
      expect(find.text('My sets'), findsOneWidget);
      expect(find.text('Trip'), findsOneWidget);
      expect(listTileWithText('Alpha'), findsOneWidget);
      expect(listTileWithText('Beta'), findsOneWidget);

      // --- Collapse / expand a section ---
      final tripPack = (await db.select(db.packs).get()).firstWhere(
        (p) => p.title == 'Trip',
      );
      await tester.tap(find.byKey(Key('packHeader-${tripPack.id}')));
      await settle(tester);
      expect(listTileWithText('Beta'), findsNothing);
      expect(listTileWithText('Alpha'), findsOneWidget);
      await tester.tap(find.byKey(Key('packHeader-${tripPack.id}')));
      await settle(tester);
      expect(listTileWithText('Beta'), findsOneWidget);

      // --- Move Alpha into Trip ---
      await tester.tap(setMenuButton('Alpha'));
      await settle(tester);
      await tester.tap(find.text('Move to pack…'));
      await settle(tester);
      await tester.tap(find.byKey(Key('moveTarget-${tripPack.id}')));
      await settle(tester);
      final alpha = (await db.select(db.questionSets).get()).firstWhere(
        (s) => s.title == 'Alpha',
      );
      expect(alpha.packId, tripPack.id);
      // "My sets" is now empty: hint + Add set action.
      expect(find.byKey(const Key('packEmptyHint')), findsOneWidget);

      // --- Rename Trip, then delete it with confirmation ---
      await tester.tap(find.byKey(const Key('managePacksButton')));
      await settle(tester);
      await tester.tap(find.byKey(Key('packMenu-${tripPack.id}')));
      await settle(tester);
      await tester.tap(find.text('Rename pack'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const Key('renamePackField')),
        'Holidays',
      );
      await tester.tap(find.byKey(const Key('confirmRenamePackButton')));
      await settle(tester);
      expect(find.text('Holidays'), findsOneWidget);

      await tester.tap(find.byKey(Key('packMenu-${tripPack.id}')));
      await settle(tester);
      await tester.tap(find.text('Delete pack'));
      await settle(tester);
      expect(find.textContaining('its 2 sets'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmDeletePackButton')));
      await settle(tester);

      await tester.pageBack();
      await settle(tester);
      expect(listTileWithText('Alpha'), findsNothing);
      expect(listTileWithText('Beta'), findsNothing);
      expect(await db.select(db.questionSets).get(), isEmpty);
    },
  );
}
