// Issue #059 — Collectible mascots via daily lootbox.
//
// Drives the real app end-to-end: a profile with one prior attempt (so
// Home's Continue button resumes a real set) completes that set's lesson
// twice on the same local day. The 1st completion's "Back to home" returns
// straight to Home (no lootbox yet); the 2nd completion's "Back to home"
// inserts a tap-to-open lootbox first, which reveals a newly-won mascot
// (persisted as owned) before Home reappears. Also covers: Home's
// tap-to-collect mascot button opens the collection screen showing the
// full catalog (owned tiles tappable, not-yet-owned ones locked), and
// tapping the newly-won mascot's tile there equips it.

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/mascot_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/mascot/mascot_catalog.dart';

import 'helpers.dart';

Future<({int setId, int itemId})> _insertSingleItemSet(AppDatabase db) async {
  final setId = await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          title: 'Animals',
          description: const Value(''),
          createdBy: 'test',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  final itemId = await db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: 'choice',
          prompt: 'der Hund',
          answer: 'dog',
          choices: const Value('["cat","mouse","bird"]'),
          position: 0,
        ),
      );
  return (setId: setId, itemId: itemId);
}

/// Resumes the (only) set via Home's Continue button and completes its
/// single item correctly, leaving the result screen's "Back to home"
/// button visible but not yet tapped — the caller decides whether to
/// assert on the lootbox before/after tapping it.
Future<void> _completeOneLessonFromHome(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('homeContinueButton')));
  await settle(tester);
  await tester.tap(find.text('dog'));
  await tester.pump();
  await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
  await settle(tester);
  await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
  await settle(tester);
  expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
  await tester.ensureVisible(find.byKey(const Key('backToLibraryButton')));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the 2nd lesson completion of the day inserts a tap-to-open lootbox '
    'before Home reappears, persisting the won mascot as owned; the '
    'collection screen then lets it be equipped',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));
      final statsRepo = StatsRepository(db, clock);
      final mascotRepo = MascotRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertSingleItemSet(db);
      // Home's Continue button derives its set from the latest `attempts`
      // row — seed one so Home resumes "Animals" straight away.
      await statsRepo.recordAttempt(
        itemId: seed.itemId,
        ok: true,
        now: DateTime(2026, 10, 16, 9),
      );

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(await mascotRepo.getOwnedMascotIds(), [kDefaultMascotId]);

      // 1st completion of the day: no lootbox yet.
      await _completeOneLessonFromHome(tester);
      await tester.tap(find.byKey(const Key('backToLibraryButton')));
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(await mascotRepo.getOwnedMascotIds(), [kDefaultMascotId]);

      // 2nd completion of the day: triggers the lootbox instead of
      // returning to Home immediately.
      await _completeOneLessonFromHome(tester);
      await tester.tap(find.byKey(const Key('backToLibraryButton')));
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
      expect(find.byKey(const Key('homeScreen')), findsNothing);

      // Unopened: no mascot/continue action shown yet.
      expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);
      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await settle(tester);

      // Revealed: the won mascot + a single Continue action.
      final ownedAfterReveal = await mascotRepo.getOwnedMascotIds();
      expect(ownedAfterReveal, hasLength(2));
      final String wonId = ownedAfterReveal.firstWhere(
        (id) => id != kDefaultMascotId,
      );
      expect(find.byKey(Key('foxMascot-$wonId')), findsOneWidget);
      expect(find.byKey(const Key('lootboxContinueButton')), findsOneWidget);

      // Continue pops the lootbox, then the lesson, landing back on Home.
      await tester.tap(find.byKey(const Key('lootboxContinueButton')));
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // Tapping Home's mascot opens the collection: the won mascot is
      // owned (tappable), at least one other catalog entry is still
      // locked, and tapping the won mascot's tile equips it.
      await tester.tap(find.byKey(const Key('homeMascotButton')));
      await settle(tester);
      expect(find.byKey(const Key('mascotCollectionScreen')), findsOneWidget);
      expect(find.byKey(const Key('mascotCollectionGrid')), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);

      await tester.tap(find.byKey(Key('mascotTile-$wonId')));
      await settle(tester);

      await tester.pageBack();
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect((await statsRepo.getProfile()).equippedMascotId, wonId);
    },
  );
}
