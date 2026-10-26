// Issue #059 — Collectible pets via daily lootbox.
//
// Drives the real app end-to-end: a profile with one prior attempt (so
// Home's Continue button resumes a real set) completes that set's lesson
// twice on the same local day. The 1st completion's "Back to home" returns
// straight to Home (no lootbox yet); the 2nd completion's "Back to home"
// inserts a tap-to-open lootbox first, which reveals a newly-won pet
// (persisted as owned) before Home reappears. Also covers: Home's
// tap-to-collect pet button opens the collection screen showing the
// full catalog (owned tiles tappable, not-yet-owned ones locked), and
// tapping the newly-won pet's tile there equips it.
//
// Uses a fixture catalog (real pet IDs/assets, but no default-fox entry)
// via `petCatalogLoader` instead of the real asset-bundle catalog: #064
// made the draw pick from every catalog entry regardless of ownership, so
// with the real (unseeded) `Random` and the real, default-fox-inclusive
// catalog, this flow's "won a 2nd, distinct pet" assertions would
// occasionally — and flakily — hit the already-owned default fox instead.
// A fixture pool with no default entry guarantees a win is always a
// newly-owned pet, which is what this flow is actually testing.
//
// Also forces #065's 50/50 coin-flip to the pet branch via
// `petRandom`, since this flow specifically asserts on a won *pet* —
// without that, half of all runs would win coins instead and fail.

import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/pet_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

import 'helpers.dart';

final List<PetEntry> _fixtureCatalog = [
  petEntryForId('emoji_u1f980_lottie'), // crab
  petEntryForId('emoji_u1f989_lottie'), // owl
  petEntryForId('emoji_u1f996_lottie'), // sauropod
];

/// Forces #065's coin-flip to the pet branch (`nextBool()` always
/// `false`), while leaving the pet-pool pick itself genuinely random —
/// this flow only cares that *a* pet was won, not which one.
class _ForcedPetRandom implements Random {
  final Random _real = Random();

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => _real.nextInt(max);

  @override
  double nextDouble() => _real.nextDouble();
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
    'before Home reappears, persisting the won pet as owned; the '
    'collection screen then lets it be equipped',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 17, 9));
      final statsRepo = StatsRepository(db, clock);
      final petRepo = PetRepository(db, clock);
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
        petRandom: () => _ForcedPetRandom(),
      );
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(await petRepo.getOwnedPetIds(), [kDefaultPetId]);

      // 1st completion of the day: no lootbox yet.
      await _completeOneLessonFromHome(tester);
      await tester.tap(find.byKey(const Key('backToLibraryButton')));
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(await petRepo.getOwnedPetIds(), [kDefaultPetId]);

      // 2nd completion of the day: triggers the lootbox instead of
      // returning to Home immediately.
      await _completeOneLessonFromHome(tester);
      await tester.tap(find.byKey(const Key('backToLibraryButton')));
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
      expect(find.byKey(const Key('homeScreen')), findsNothing);

      // Unopened: no pet/continue action shown yet.
      expect(find.byKey(const Key('lootboxContinueButton')), findsNothing);
      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await settle(tester);

      // Revealed: the won pet + a single Continue action.
      final ownedAfterReveal = await petRepo.getOwnedPetIds();
      expect(ownedAfterReveal, hasLength(2));
      final String wonId = ownedAfterReveal.firstWhere(
        (id) => id != kDefaultPetId,
      );
      expect(find.byKey(Key('foxPet-$wonId')), findsOneWidget);
      expect(find.byKey(const Key('lootboxContinueButton')), findsOneWidget);

      // Continue pops the lootbox, then the lesson, landing back on Home.
      await tester.tap(find.byKey(const Key('lootboxContinueButton')));
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // Tapping Home's pet opens the collection: the won pet is
      // owned (tappable), at least one other catalog entry is still
      // locked, and tapping the won pet's tile equips it.
      await tester.tap(find.byKey(const Key('homePetButton')));
      await settle(tester);
      expect(find.byKey(const Key('petCollectionScreen')), findsOneWidget);
      expect(find.byKey(const Key('petCollectionGrid')), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);

      await tester.tap(find.byKey(Key('petTile-$wonId')));
      await settle(tester);

      await tester.pageBack();
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect((await statsRepo.getProfile()).equippedPetId, wonId);
    },
  );
}
