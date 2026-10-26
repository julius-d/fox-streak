// Issue #042 — sticky "Start lesson" FAB + direct-start from the Library
// list.
//
// Drives the real app end-to-end: the Library row's play icon skips
// `SetDetailScreen` entirely when the set has items, and both new "start
// lesson" entry points (Library row play icon, `SetDetailScreen`'s "Start
// lesson" FAB) show the empty-set snackbar instead of navigating when the
// set has none.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations_en.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final l10n = AppLocalizationsEn();

  testWidgets(
    'empty-set tap feedback is a snackbar (not navigation) from both entry '
    'points; a set with items plays straight from the Library row, '
    'skipping SetDetailScreen',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 16, 9));

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      await skipOnboardingAndOpenLibrary(tester);

      // --- Create an empty set ---
      await openNewSetEditor(tester);
      await tester.enterText(find.byKey(const Key('titleField')), 'Empty');
      await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);

      // --- Library row play icon on the empty set: snackbar, no nav ---
      await tester.tap(playSetButton('Empty'));
      await settle(tester);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('lessonProgressBar')), findsNothing);
      // Let the snackbar auto-dismiss before the next assertion.
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);

      // --- SetDetailScreen's own "Start lesson" FAB: same behavior ---
      await openSetDetail(tester, 'Empty');
      // Reachable without scrolling, right after opening the screen.
      expect(find.byKey(const Key('startLessonFab')), findsOneWidget);
      await tester.tap(find.byKey(const Key('startLessonFab')));
      await settle(tester);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('lessonProgressBar')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      // --- Create a set with one item ---
      await openNewSetEditor(tester);
      await tester.enterText(find.byKey(const Key('titleField')), 'Animals');
      await tester.enterText(find.byKey(const Key('creatorField')), 'Mama');
      await tester.tap(find.byKey(const Key('saveSetButton')));
      await settle(tester);
      await openSetDetail(tester, 'Animals');
      await tester.tap(find.byKey(const Key('addItemFab')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('itemPromptField')), 'Hund');
      await tester.enterText(find.byKey(const Key('itemAnswerField')), 'dog');
      await tester.tap(find.byKey(const Key('saveItemButton')));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      // --- Library row play icon jumps straight into the lesson ---
      await tester.tap(playSetButton('Animals'));
      await settle(tester);
      expect(find.byKey(const Key('lessonProgressBar')), findsOneWidget);

      // Quit back out: lands on Library directly (detail was skipped).
      await tester.tap(find.byKey(const Key('lessonOverflowMenu')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('quitLessonMenuItem')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmQuitLessonButton')));
      await settle(tester);

      expect(listTileWithText('Animals'), findsOneWidget);
      expect(find.text(l10n.libraryTitle), findsOneWidget);
    },
  );
}
