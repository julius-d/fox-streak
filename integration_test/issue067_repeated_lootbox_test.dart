// Issue #067 — Multiple lootboxes per day.
//
// Drives the real app end-to-end through 5 same-day lesson completions,
// proving the repeating 2, 5, 8, ... cadence (not just the original
// twice-a-day trigger from #059) actually reaches `LootboxScreen` through
// the full provider/navigation stack, not just `MascotService` in
// isolation (already covered by `test/stats/mascot_service_test.dart`).
//
// Reuses #059's fixture catalog/forced-mascot-branch setup (see
// `issue059_mascot_lootbox_test.dart`'s header for why) so every trigger
// deterministically wins a mascot. Unlike that single-trigger flow, this
// one drives *two* triggers (the 2nd and 5th completion) in the same run,
// so the pool pick itself is also forced deterministic and distinct per
// trigger — a genuinely random pick could draw the same already-owned
// mascot twice, which `OwnedMascots`' primary-key upsert would silently
// collapse into a `count` bump rather than a 3rd distinct owned row,
// flakily failing the `hasLength(3)` assertion below.
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/mascot_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/mascot/mascot_catalog.dart';

import 'helpers.dart';

final List<MascotEntry> _fixtureCatalog = [
  mascotEntryForId('emoji_u1f980_lottie'), // crab
  mascotEntryForId('emoji_u1f989_lottie'), // owl
  mascotEntryForId('emoji_u1f996_lottie'), // sauropod
];

/// Forces #065's coin-flip to the mascot branch (`nextBool()` always
/// `false`) and the pool pick to a fixed [index] — the
/// `mascotRandomProvider` factory is only ever invoked once per lootbox
/// trigger (see `MascotService.recordLessonCompletion`'s early return for
/// non-trigger completions), so passing a different `index` per trigger
/// forces distinct, predictable mascot picks across triggers.
class _FixedMascotRandom implements Random {
  _FixedMascotRandom(this.index);

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

/// Resumes the (only) set via Home's Continue button, completes its single
/// item correctly, and taps "Back to home" — landing either on
/// `LootboxScreen` (a trigger completion) or straight back on `HomeScreen`.
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
  await tester.tap(find.byKey(const Key('backToLibraryButton')));
  await settle(tester);
}

/// Opens and dismisses the lootbox currently on screen, landing back on
/// Home.
Future<void> _openAndDismissLootbox(WidgetTester tester) async {
  expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
  await tester.tap(find.byKey(const Key('lootboxOpenButton')));
  await settle(tester);
  await tester.tap(find.byKey(const Key('lootboxContinueButton')));
  await settle(tester);
  expect(find.byKey(const Key('lootboxScreen')), findsNothing);
  expect(find.byKey(const Key('homeScreen')), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completions 3 and 4 of the day skip the lootbox, but the 5th '
      'retriggers it, winning another mascot (issue #067)', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 17, 9));
    final statsRepo = StatsRepository(db, clock);
    final mascotRepo = MascotRepository(db, clock);
    await statsRepo.setOnboarded();

    final seed = await _insertSingleItemSet(db);
    await statsRepo.recordAttempt(
      itemId: seed.itemId,
      ok: true,
      now: DateTime(2026, 10, 16, 9),
    );

    var mascotPickCount = 0;
    await pumpFoxStreakApp(
      tester,
      db: db,
      clock: clock,
      mascotCatalogLoader: () async => _fixtureCatalog,
      mascotRandom: () => _FixedMascotRandom(mascotPickCount++),
    );
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    // 1st completion: no lootbox yet.
    await _completeOneLessonFromHome(tester);
    expect(find.byKey(const Key('lootboxScreen')), findsNothing);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    // 2nd completion: the original #059 trigger still fires.
    await _completeOneLessonFromHome(tester);
    await _openAndDismissLootbox(tester);
    final ownedAfterSecond = await mascotRepo.getOwnedMascotIds();
    expect(ownedAfterSecond, hasLength(2));

    // 3rd and 4th completions: no retrigger (issue #067's next one is
    // the 5th).
    await _completeOneLessonFromHome(tester);
    expect(find.byKey(const Key('lootboxScreen')), findsNothing);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    await _completeOneLessonFromHome(tester);
    expect(find.byKey(const Key('lootboxScreen')), findsNothing);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    // 5th completion: issue #067's repeating cadence retriggers the
    // lootbox, independently reward-rolled, winning a 3rd mascot.
    await _completeOneLessonFromHome(tester);
    await _openAndDismissLootbox(tester);
    final ownedAfterFifth = await mascotRepo.getOwnedMascotIds();
    expect(ownedAfterFifth, hasLength(3));

    expect((await statsRepo.getProfile()).lessonsCompletedToday, 5);
  });
}
