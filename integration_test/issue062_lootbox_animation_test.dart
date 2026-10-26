// Issue #062 — Loot box opening animation.
//
// Drives the real app end-to-end to the lootbox screen (same route as
// #059's own flow: complete a seeded single-item set twice on the same
// local day), then exercises the new tap-gated opening animation itself:
// the closed lootbox is tappable and shows no reward yet; tapping it starts
// the animation (no longer tappable, reward still hidden); a re-tap
// mid-animation is a no-op; and the reward + Continue action only appear
// once the animation finishes on its own.

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';

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

Future<void> _completeOneLessonFromHome(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('homeContinueButton')));
  await settle(tester);
  await tester.tap(find.text('dog'));
  await tester.pump();
  await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
  await settle(tester);
  await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the closed lootbox plays its opening animation once tapped, ignores '
    'a re-tap mid-animation, and only reveals the reward once the '
    'animation finishes',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertSingleItemSet(db);
      await statsRepo.recordAttempt(
        itemId: seed.itemId,
        ok: true,
        now: DateTime(2026, 10, 16, 9),
      );

      await pumpFoxStreakApp(tester, db: db, clock: clock);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // 1st completion: no lootbox yet (and the fresh profile's first-ever
      // lesson advances the streak, so the #078 sequence shows that screen
      // before XP up).
      await _completeOneLessonFromHome(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);

      // 2nd completion: the #078 sequence shows the lootbox automatically,
      // right on completion — same day, so no streak screen this time.
      await _completeOneLessonFromHome(tester);
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);

      // Closed: tappable, frozen, no reward/Continue yet.
      expect(find.byKey(const Key('lootboxOpenButton')), findsOneWidget);
      expect(find.byKey(const Key('lootboxAnimation')), findsOneWidget);
      expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);

      // Tap: starts the opening animation. A single pump proves the
      // reveal is gated on the animation, not on the tap itself.
      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await tester.pump();
      expect(find.byKey(const Key('lootboxOpenButton')), findsNothing);
      expect(find.byKey(const Key('lootboxAnimation')), findsOneWidget);
      expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);

      // Re-tap mid-animation: no tap target there anymore, so this is a
      // true no-op rather than restarting or skipping ahead.
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('lootboxAnimation'))),
      );
      await tester.pump();
      expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);

      // Once the animation finishes on its own: revealed + Continue.
      await settle(tester);
      expect(find.byKey(const Key('lootboxAnimation')), findsNothing);
      expect(find.byKey(const Key('lootboxContinueButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('lootboxContinueButton')));
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
    },
  );
}
