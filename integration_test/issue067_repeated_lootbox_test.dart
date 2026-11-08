// Issue #067 — Multiple lootboxes per day.
//
// Drives the real app end-to-end through 5 same-day lesson completions,
// proving the repeating 2, 5, 8, ... cadence (not just the original
// twice-a-day trigger from #059) actually reaches `LootboxScreen` through
// the full provider/navigation stack, not just `PetService` in
// isolation (already covered by `test/stats/pet_service_test.dart`).
//
// Reuses #059's fixture catalog/forced-pet-branch setup (see
// `issue059_pet_lootbox_test.dart`'s header for why) so every trigger
// deterministically wins a pet. Unlike that single-trigger flow, this
// one drives *two* triggers (the 2nd and 5th completion) in the same run,
// so the pool pick itself is also forced deterministic and distinct per
// trigger — a genuinely random pick could draw the same already-owned
// pet twice, which `OwnedPets`' primary-key upsert would silently
// collapse into a `count` bump rather than a 3rd distinct owned row,
// flakily failing the `hasLength(3)` assertion below.
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
/// `false`) and the pool pick to a fixed [index] — letting the caller
/// hand a different `index` per lootbox trigger forces distinct,
/// predictable pet picks across triggers.
///
/// The `petRandomProvider` factory itself is no longer invoked only on
/// lootbox triggers since #085: the day's 3rd completion also calls it
/// once for the wheel's own (otherwise-irrelevant to this flow) coin
/// draw. `main()` below accounts for this by advancing its own pick
/// index only when a lootbox pick is actually consumed, not on every
/// factory call.
class _FixedPetRandom implements Random {
  _FixedPetRandom(this.index);

  final int index;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => index % max;

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
/// single item correctly, settling right after CONTINUE — leaving the
/// caller to decide what's showing next: the #078 completion sequence's
/// loot box (if this completion won one) is automatic now, no longer
/// something a "Back to home" tap inserts.
Future<void> _completeOneLessonFromHome(WidgetTester tester) async {
  await startLessonFromHome(tester);
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

/// Opens and dismisses the lootbox currently on screen, then taps through
/// the always-present XP up screen, landing back on Home.
Future<void> _openAndDismissLootbox(WidgetTester tester) async {
  expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
  await tester.tap(find.byKey(const Key('lootboxOpenButton')));
  await settle(tester);
  await tester.tap(find.byKey(const Key('lootboxContinueButton')));
  await settle(tester);
  expect(find.byKey(const Key('lootboxScreen')), findsNothing);
  await dismissCompletionScreens(tester);
  await tester.tap(find.byKey(const Key('homeButton')));
  await settle(tester);
  expect(find.byKey(const Key('homeScreen')), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completions 3 and 4 of the day skip the lootbox, but the 5th '
      'retriggers it, winning another pet (issue #067)', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 17, 9));
    final statsRepo = StatsRepository(db, clock);
    final petRepo = PetRepository(db, clock);
    await statsRepo.setOnboarded();

    final seed = await _insertSingleItemSet(db);
    await statsRepo.recordAttempt(
      itemId: seed.itemId,
      ok: true,
      now: DateTime(2026, 10, 16, 9),
    );

    // Advanced only right after a lootbox pick is actually consumed (see
    // `_FixedPetRandom`'s doc) — the 3rd completion's wheel trigger (#085)
    // also calls this factory in between, but must not shift which index
    // the 5th completion's lootbox pick receives.
    var petPickIndex = 0;
    await pumpFoxStreakApp(
      tester,
      db: db,
      clock: clock,
      petCatalogLoader: () async => _fixtureCatalog,
      petRandom: () => _FixedPetRandom(petPickIndex),
    );
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    // 1st completion: no lootbox yet.
    await _completeOneLessonFromHome(tester);
    await _skipToHome(tester);

    // 2nd completion: the original #059 trigger still fires.
    await _completeOneLessonFromHome(tester);
    await _openAndDismissLootbox(tester);
    petPickIndex++;
    final ownedAfterSecond = await petRepo.getOwnedPetIds();
    expect(ownedAfterSecond, hasLength(2));

    // 3rd and 4th completions: no lootbox retrigger (issue #067's next
    // one is the 5th) — the 3rd's wheel trigger (#085) is dismissed by
    // `_skipToHome`'s own `dismissCompletionScreens` call.
    await _completeOneLessonFromHome(tester);
    await _skipToHome(tester);

    await _completeOneLessonFromHome(tester);
    await _skipToHome(tester);

    // 5th completion: issue #067's repeating cadence retriggers the
    // lootbox, independently reward-rolled, winning a 3rd pet.
    await _completeOneLessonFromHome(tester);
    await _openAndDismissLootbox(tester);
    final ownedAfterFifth = await petRepo.getOwnedPetIds();
    expect(ownedAfterFifth, hasLength(3));

    expect((await statsRepo.getProfile()).lessonsCompletedToday, 5);
  });
}
