// Flow 3 — XP + streak (issue #016, builds on #010/#011).
//
// Fills the gaps #010/#011's own closing integration tests didn't cover:
// the 10/5/0 XP tiers together in one lesson (no perfect bonus), and the
// streak's same-day-replay-never-double-counts vs. new-day-increments
// behavior across several lessons, including `today_xp` reset-vs-accumulate.
// (`xp_level_result_test.dart`/`streak_result_test.dart` already cover the
// perfect-bonus and milestone-pet cases individually — not duplicated
// here.)

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

import 'helpers.dart';

Future<int> _insertChoiceItem(
  AppDatabase db,
  int setId,
  String prompt,
  String answer,
  int position,
) {
  return db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: 'choice',
          prompt: prompt,
          answer: answer,
          choices: const Value('["x","y","z"]'),
          position: position,
        ),
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'XP tiers (10 correct/no-hint, 5 correct/hint, 0 wrong) and the streak '
    'same-day-no-double-count vs. new-day-increment all hold across '
    'several real lessons, with today_xp resetting on the day change',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 14, 9));
      final statsRepo = StatsRepository(db, clock);

      final setId = await db
          .into(db.questionSets)
          .insert(
            QuestionSetsCompanion.insert(
              title: 'XP test',
              description: const Value(''),
              createdBy: 'test',
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      // --- Day 1, lesson 1: two correct, no hint, perfect score. ---
      // 10 + 10 + 5 (perfect bonus) = 25.
      final lesson1Items = [
        Item(
          id: await _insertChoiceItem(db, setId, 'der Hund', 'dog', 0),
          setId: setId,
          type: 'choice',
          prompt: 'der Hund',
          answer: 'dog',
          position: 0,
        ),
        Item(
          id: await _insertChoiceItem(db, setId, 'die Katze', 'cat', 1),
          setId: setId,
          type: 'choice',
          prompt: 'die Katze',
          answer: 'cat',
          position: 1,
        ),
      ];
      await pumpLessonScreen(
        tester,
        db: db,
        clock: clock,
        setId: setId,
        items: lesson1Items,
        petCatalogLoader: () async => const <PetEntry>[],
      );
      for (var i = 0; i < lesson1Items.length; i++) {
        // Items are shuffled by the controller; identify which one is
        // showing by its (unique) prompt, not its answer — the other
        // item's answer can legitimately appear as a same-set distractor
        // on this round, so matching by answer text alone is ambiguous.
        final current = lesson1Items.firstWhere(
          (item) => find.text(item.prompt).evaluate().isNotEmpty,
        );
        await tester.tap(find.text(current.answer));
        await tester.pump();
        await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
        await settle(tester);
        await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
        await settle(tester);
      }
      // This fresh profile's first-ever lesson also advances the streak.
      await dismissCompletionScreens(tester);
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);

      var profile = await statsRepo.getProfile();
      expect(profile.xpTotal, 25);
      expect(profile.todayXp, 25);
      expect(profile.streakCount, 1);
      expect(profile.lastActiveDay, '2026-10-14');

      // --- Day 1, lesson 2 (same day, replayed): hint-correct + wrong. ---
      // 5 (hint) + 0 (wrong) = 5, no bonus (not perfect) -> accumulates XP
      // but must NOT double-count the streak (still day 1).
      final freeTextItemId = await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              setId: setId,
              type: 'freeText',
              prompt: 'Capital of France',
              answer: 'Paris',
              position: 2,
            ),
          );
      final phoneItemId = await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              setId: setId,
              type: 'phone',
              prompt: 'Mama',
              answer: '01711234567',
              position: 3,
            ),
          );
      final lesson2Items = [
        Item(
          id: freeTextItemId,
          setId: setId,
          type: 'freeText',
          prompt: 'Capital of France',
          answer: 'Paris',
          position: 2,
        ),
        Item(
          id: phoneItemId,
          setId: setId,
          type: 'phone',
          prompt: 'Mama',
          answer: '01711234567',
          position: 3,
        ),
      ];
      await pumpLessonScreen(
        tester,
        db: db,
        clock: clock,
        setId: setId,
        items: lesson2Items,
        petCatalogLoader: () async => const <PetEntry>[],
      );
      for (var i = 0; i < lesson2Items.length; i++) {
        if (find
            .byKey(const Key('freeTextAnswerField'))
            .evaluate()
            .isNotEmpty) {
          await tester.tap(find.byKey(const Key('freeTextRevealHintButton')));
          await tester.pump();
          await tester.enterText(
            find.byKey(const Key('freeTextAnswerField')),
            'Paris',
          );
        } else {
          await tester.tap(find.byKey(const Key('dialPadKey9')));
        }
        await tester.pump();
        await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
        await settle(tester);
        await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
        await settle(tester);
      }
      // Same-day replay: no streak screen, just XP up.
      await dismissCompletionScreens(tester);
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);

      profile = await statsRepo.getProfile();
      expect(profile.xpTotal, 30); // 25 + 5
      expect(profile.todayXp, 30); // same-day accumulate
      expect(profile.streakCount, 1); // same-day replay never double-counts
      expect(profile.lastActiveDay, '2026-10-14');

      // --- Day 2: one correct/no-hint item, perfect score again. ---
      // today_xp resets to just this lesson's 15 (10 + 5 bonus); streak +1.
      clock.setNow(DateTime(2026, 10, 15, 9));
      final day2ItemId = await _insertChoiceItem(
        db,
        setId,
        'der Vogel',
        'bird',
        4,
      );
      final lesson3Items = [
        Item(
          id: day2ItemId,
          setId: setId,
          type: 'choice',
          prompt: 'der Vogel',
          answer: 'bird',
          position: 4,
        ),
      ];
      await pumpLessonScreen(
        tester,
        db: db,
        clock: clock,
        setId: setId,
        items: lesson3Items,
        petCatalogLoader: () async => const <PetEntry>[],
      );
      await tester.tap(find.text('bird'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
      await settle(tester);
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      await settle(tester);
      // New day: streak screen reappears before XP up.
      await dismissCompletionScreens(tester);
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);

      profile = await statsRepo.getProfile();
      expect(profile.xpTotal, 45); // 30 + 15
      expect(profile.todayXp, 15); // reset on the day change, then this lesson
      expect(profile.streakCount, 2); // new day increments
      expect(profile.lastActiveDay, '2026-10-15');
    },
  );
}
