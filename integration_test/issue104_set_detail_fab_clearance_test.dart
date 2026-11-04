// Issue #104 — Set Detail screen's stacked-FAB/system-inset list clearance.
//
// `ListView.builder` pairs with two stacked FABs ("Add item" + "Start
// lesson"); without reserved bottom space, the last row's trailing
// action(s) end up scrolled directly underneath them, which — being on
// top in paint order — actually receive a tap aimed at that location
// instead of the row's button. Seeds enough items to overflow the
// default (800x600, see `macos/Runner/Base.lproj/MainMenu.xib`) desktop
// window, scrolls the list to its end, and taps the last item's delete
// button: if a FAB still covers it, the tap lands on the FAB instead
// (opening the item editor, or pushing `LessonScreen`) rather than this
// confirm dialog.
//
// Kept as its own file — see `issue104_library_fab_clearance_test.dart`'s
// header for why this isn't bundled with the other two #104 specs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/sets_repository.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Set Detail: scrolled to the end, the last item\'s delete button opens '
    'its confirm dialog instead of hitting a stacked FAB',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));

      final setsRepo = SetsRepository(db, clock);
      final setId = await setsRepo.createSet(
        title: 'Big Set',
        createdBy: 'Tester',
      );
      for (var i = 1; i <= 20; i++) {
        final label = i.toString().padLeft(2, '0');
        await setsRepo.addItem(
          setId: setId,
          type: 'freeText',
          prompt: 'Item $label',
          answer: 'Answer $label',
        );
      }

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);
      await openSetDetail(tester, 'Big Set');

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await settle(tester);
      expect(listTileWithText('Item 20'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: listTileWithText('Item 20'),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await settle(tester);

      // Hitting "Add item" or "Start lesson" instead would open the item
      // editor or push `LessonScreen` rather than this confirm dialog.
      expect(find.byKey(const Key('confirmDeleteItemButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmDeleteItemButton')));
      await settle(tester);

      // `ListView.builder` only mounts visible rows, so after scrolling to
      // the end only the (new) last row — not the first — is guaranteed
      // to still be built here.
      expect(listTileWithText('Item 20'), findsNothing);
      expect(listTileWithText('Item 19'), findsOneWidget);
    },
  );
}
