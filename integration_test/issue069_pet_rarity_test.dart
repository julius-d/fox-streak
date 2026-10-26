// Issue #069 — Rarity levels for pets.
//
// Drives the real app end-to-end: a profile with one prior attempt
// completes that set's lesson enough times to trigger #067's repeating
// lootbox twice (the 2nd and 5th completions), winning the same
// Uncommon-tier pet (crab) both times via a forced, fully deterministic
// weighted draw. Covers the UI surfaces this issue actually changed:
//
// - The unopened lootbox's reward-agnostic tap prompt (no more "new
//   mascot").
// - The revealed title naming the won pet's rarity ("You got an Uncommon
//   pet!"), not "new".
// - The collection screen's rarity label under both an owned (fox,
//   Common) and the newly-won (crab, Uncommon) tile.
// - The "×2" owned-count badge once crab has been won twice.
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

import 'helpers.dart';

// Fox (Common) + crab (Uncommon) only, so the weighted draw's total weight
// is fixed at 55 + 30 = 85 for every trigger.
final List<PetEntry> _fixtureCatalog = [
  PetCatalog.defaultEntry,
  petEntryForId('emoji_u1f980_lottie'), // crab
];

/// Forces #065's coin-flip to the pet branch (`nextBool()` always `false`)
/// and [drawPet]'s weighted draw to always land on crab: a tier-select
/// draw of 55 lands exactly on the uncommon tier (fox's common tier claims
/// draws 0..54 of the 85 total weight), and a within-tier draw of 0 picks
/// crab (the tier's only pet). Deterministic across every trigger, since
/// the fixture catalog's weight distribution never changes.
class _AlwaysCrabRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => max > 1 ? 55 : 0;

  @override
  double nextDouble() => 0;
}

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
    'the lootbox tap prompt + revealed title are reward/rarity-worded, '
    'and the collection screen shows rarity labels + an owned-count badge '
    '(issue #069)',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 3, 15, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertSingleItemSet(db);
      await statsRepo.recordAttempt(
        itemId: seed.itemId,
        ok: true,
        now: DateTime(2026, 3, 14, 9),
      );

      await pumpFoxStreakApp(
        tester,
        db: db,
        clock: clock,
        petCatalogLoader: () async => _fixtureCatalog,
        petRandom: () => _AlwaysCrabRandom(),
      );
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // 1st completion: no lootbox yet.
      await _completeOneLessonFromHome(tester);
      await _skipToHome(tester);

      // 2nd completion: triggers the lootbox automatically. Unopened, the
      // prompt (an a11y label on the tap target, not visible text) is
      // reward-agnostic (no "new mascot").
      await _completeOneLessonFromHome(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tap to reveal your reward!'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await settle(tester);

      // Revealed: the title names the won pet's rarity, not "new".
      expect(find.text('You got an Uncommon pet!'), findsOneWidget);
      expect(
        find.byKey(const Key('foxPet-emoji_u1f980_lottie')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('lootboxContinueButton')));
      await settle(tester);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // 3rd and 4th completions: issue #067's cadence skips these.
      await _completeOneLessonFromHome(tester);
      await _skipToHome(tester);
      await _completeOneLessonFromHome(tester);
      await _skipToHome(tester);

      // 5th completion: retriggers, winning crab a 2nd time.
      await _completeOneLessonFromHome(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('lootboxContinueButton')));
      await settle(tester);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // The collection screen shows both tiles' rarity labels, plus a
      // "×2" badge on crab now that it's been won twice.
      await tester.tap(find.byKey(const Key('homePetButton')));
      await settle(tester);
      expect(find.byKey(const Key('petCollectionScreen')), findsOneWidget);

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('petRarityLabel-$kDefaultPetId')),
            )
            .data,
        'Common',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('petRarityLabel-emoji_u1f980_lottie')),
            )
            .data,
        'Uncommon',
      );
      expect(
        find.byKey(const Key('petOwnedCount-emoji_u1f980_lottie')),
        findsOneWidget,
      );
      expect(find.text('×2'), findsOneWidget);
      expect(
        find.byKey(const Key('petOwnedCount-$kDefaultPetId')),
        findsNothing,
      );
    },
  );
}
