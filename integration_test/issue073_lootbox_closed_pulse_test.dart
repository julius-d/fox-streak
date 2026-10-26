// Issue #073 — Lootbox starts closed, with a tap-hint pulse.
//
// Regression coverage: `LootboxScreen` used to start its opening Lottie at
// value `0.0`, which — contrary to the original bug report's assumption —
// isn't a closed frame either; `kLootboxOpenAnimationAsset` has no closed
// frame at either end of its range. It opens briefly at `0.0`, swings shut
// by ~frame 10, holds shut through ~frame 54, then cracks open with a
// sparkle burst through its last frame (`1.0`). So the box looked already
// open the instant it appeared. Drives the real app to its first same-day
// lootbox trigger — the same flow `issue059_mascot_lootbox_test.dart`
// drives — and asserts the box is genuinely closed (open-Lottie controller
// at `0.2`, inside the closed hold) right as the screen appears, then that
// tapping it plays forward to `1.0` and reveals the reward.
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lottie/lottie.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

import 'helpers.dart';

final List<PetEntry> _fixtureCatalog = [
  petEntryForId('emoji_u1f980_lottie'), // crab
];

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
/// single item correctly, settling right after CONTINUE — leaving the
/// caller to decide what's showing next: the #078 completion sequence's
/// loot box (if this completion won one) is automatic now, no longer
/// something a "Back to home" tap inserts.
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

/// Taps through a non-trigger completion's streak/XP screens (no loot box)
/// to land back on Home.
Future<void> _skipToHome(WidgetTester tester) async {
  expect(find.byKey(const Key('lootboxScreen')), findsNothing);
  await dismissCompletionScreens(tester);
  await tester.tap(find.byKey(const Key('homeButton')));
  await settle(tester);
  expect(find.byKey(const Key('homeScreen')), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the lootbox renders genuinely closed the instant it appears (not '
    'already open), then opens on tap and reveals the reward (issue #073)',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertSingleItemSet(db);
      // Home's Continue button derives its set from the latest `attempts`
      // row — seed one so Home resumes "Animals" straight away.
      await statsRepo.recordAttempt(
        itemId: seed.itemId,
        ok: true,
        now: DateTime(2026, 10, 16, 9),
      );

      await pumpFoxStreakApp(
        tester,
        db: db,
        clock: clock,
        petCatalogLoader: () async => _fixtureCatalog,
      );
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // 1st completion of the day: no lootbox yet.
      await _completeOneLessonFromHome(tester);
      await _skipToHome(tester);

      // 2nd completion of the day: triggers the lootbox automatically.
      await _completeOneLessonFromHome(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
      expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);

      // Closed the instant it appears: the open-Lottie's own controller is
      // at `0.2` (inside the asset's genuinely-closed held frame range),
      // not `0.0` (which is already open) — the #073 regression this
      // covers.
      final AnimationController openController =
          tester.widget<LottieBuilder>(find.byType(LottieBuilder)).controller!
              as AnimationController;
      expect(openController.value, 0.2);

      // Tapping plays forward to `1.0` and reveals the reward.
      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await settle(tester);

      expect(openController.value, 1.0);
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
