// Issue #085 — Wheel of fortune.
//
// Drives the real app end-to-end through 3 same-day lesson completions,
// proving the wheel's `newCount % 3 == 0` cadence actually reaches
// `WheelScreen` through the full provider/navigation stack (not just
// `PetService` in isolation, already covered by
// `test/stats/pet_service_test.dart`), that it never coincides with the
// lootbox's own 2/5/8/... trigger, and that the coins it awards land on
// `coinsTotal` (shown on Home's coin badge, issue #080).
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

import 'helpers.dart';

final List<PetEntry> _fixtureCatalog = [
  petEntryForId('emoji_u1f980_lottie'), // crab
  petEntryForId('emoji_u1f989_lottie'), // owl
];

/// Fully deterministic "random": forces the lootbox's coin-flip to the pet
/// branch and every pool/weighted-table index pick to `0` — the wheel's
/// own draw then always lands on `kWheelCoinAmounts.first` (10 coins,
/// weight 100, covering draws 0..99).
class _FixedRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;
}

Future<({int setId, int itemId})> _insertSingleItemSet(AppDatabase db) async {
  final setId = await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          packId: 1,
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

/// Starts the (only) set via Home's Browse sets and completes its
/// single item correctly, settling right after CONTINUE.
Future<void> _completeOneLessonFromHome(WidgetTester tester) async {
  await startLessonFromHome(tester);
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
    "the day's 3rd lesson completion shows the wheel of fortune (not the "
    'lootbox) and its spin awards coins visible on Home, never coinciding '
    "with the 2nd completion's own lootbox trigger",
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 20, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertSingleItemSet(db);
      // A prior attempt makes this a returning learner (Home itself no longer
      // resumes sets, #124).
      await statsRepo.recordAttempt(
        itemId: seed.itemId,
        ok: true,
        now: DateTime(2026, 10, 19, 9),
      );

      await pumpFoxStreakApp(
        tester,
        db: db,
        clock: clock,
        petCatalogLoader: () async => _fixtureCatalog,
        petRandom: () => _FixedRandom(),
      );
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.byKey(const Key('coinBadge')), findsNothing);

      // 1st completion: fresh profile's first-ever lesson, advances the
      // streak — no lootbox, no wheel yet.
      await _completeOneLessonFromHome(tester);
      expect(find.byKey(const Key('streakSavedScreen')), findsOneWidget);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.byKey(const Key('wheelScreen')), findsNothing);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);

      // 2nd completion: the lootbox's own trigger (issue #059/#067) —
      // same day, so no streak screen, and no wheel either.
      await _completeOneLessonFromHome(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
      expect(find.byKey(const Key('wheelScreen')), findsNothing);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // 3rd completion: the wheel's own trigger — no lootbox this time,
      // the two cadences never overlap.
      await _completeOneLessonFromHome(tester);
      expect(find.byKey(const Key('wheelScreen')), findsOneWidget);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.byKey(const Key('wheelContinueButton')), findsNothing);

      // Tap to spin; the fixed random above forces a 10-coin win,
      // already persisted to `coinsTotal` before the spin even started.
      expect((await statsRepo.getProfile()).coinsTotal, 10);
      await tester.tap(find.byKey(const Key('wheelSpinButton')));
      await settle(tester);

      expect(find.byKey(const Key('wheelContinueButton')), findsOneWidget);
      expect(find.text('You won 10 coins!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('wheelContinueButton')));
      await settle(tester);
      expect(find.byKey(const Key('wheelScreen')), findsNothing);

      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);

      // The wheel's coins are visible on Home's coin badge.
      expect(find.byKey(const Key('coinBadge')), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    },
  );
}
