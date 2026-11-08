// Issue #078 — Lesson completion split into sequential screens (loot box
// -> streak saved -> XP up -> summary).
//
// Covers what `level_up_result_test.dart`/`xp_level_result_test.dart`/
// `streak_result_test.dart` don't: the sequencing itself (which screen
// shows first, that an earlier screen is actually gone once its own
// Continue is tapped) and the summary screen's own behavior (2-vs-1
// buttons depending on missed items — trimmed by #114 to Redo missed items
// + Home, or just Home on a perfect score — Redo missed items actually
// restarting the right item set, and Home landing in the right place
// regardless of which entry point launched the lesson).
//
// Loot box's trigger (the day's 2nd completion, then every 3rd after —
// #067) and the streak's `isNewDay` flag (only true on a day's *first*
// completion) can never both be true for the same completion — a 2nd
// same-day completion is by definition not that day's first. So the full
// four-screen sequence is never exercised in one run; the two tests below
// cover the two combinations that *can* happen (streak+XP, loot box+XP),
// each also proving the earlier screen is gone before the next appears.

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import 'helpers.dart';

// Non-empty so a loot-box trigger always has a pet to draw from regardless
// of #065's 50/50 coin-flip outcome (an empty catalog leaves a pet-branch
// draw with nothing to pick, so no reward — and no loot box — at all).
final List<PetEntry> _fixtureCatalog = [
  petEntryForId('emoji_u1f980_lottie'), // crab
  petEntryForId('emoji_u1f989_lottie'), // owl
];

Future<({int setId, int dogId, int catId})> _insertTwoItemSet(
  AppDatabase db,
) async {
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
  final dogId = await db
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
  final catId = await db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: 'choice',
          prompt: 'die Katze',
          answer: 'cat',
          choices: const Value('["dog","mouse","bird"]'),
          position: 1,
        ),
      );
  return (setId: setId, dogId: dogId, catId: catId);
}

/// Answers whichever of `dog`/`cat` is currently shown. [wrong] answers it
/// incorrectly instead (taps the other known option) to produce a missed
/// item, then drives CHECK -> feedback -> CONTINUE either way.
Future<void> _answerCurrentItem(
  WidgetTester tester, {
  bool wrong = false,
}) async {
  final showingDog = find.text('der Hund').evaluate().isNotEmpty;
  final tapText = wrong
      ? (showingDog ? 'cat' : 'dog')
      : (showingDog ? 'dog' : 'cat');
  await tester.tap(find.text(tapText));
  await tester.pump();
  await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
  await settle(tester);
  await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
  await settle(tester);
}

/// Whether the button at [key] renders as a primary (filled) button — a
/// secondary button renders an `OutlinedButton` instead (`fox_buttons.dart`).
bool _isPrimaryButton(WidgetTester tester, String key) {
  return find
      .descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton))
      .evaluate()
      .isNotEmpty;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    "a fresh profile's first-ever lesson shows streak saved then XP up, in "
    'that order, landing on a perfect-score summary with only Home',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 20, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertTwoItemSet(db);
      await pumpLessonScreen(
        tester,
        db: db,
        clock: clock,
        setId: seed.setId,
        items: await db.select(db.items).get(),
        petCatalogLoader: () async => const <PetEntry>[],
      );

      await _answerCurrentItem(tester);
      await _answerCurrentItem(tester);

      // Streak saved first — no loot box (not yet triggered) or XP up yet.
      expect(find.byKey(const Key('streakSavedScreen')), findsOneWidget);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.byKey(const Key('xpUpScreen')), findsNothing);
      expect(find.text('2-day streak!'), findsNothing); // sanity: not day 2

      await tester.tap(find.byKey(const Key('streakSavedContinueButton')));
      await settle(tester);

      // XP up next — streak saved is gone now.
      expect(find.byKey(const Key('xpUpScreen')), findsOneWidget);
      expect(find.byKey(const Key('streakSavedScreen')), findsNothing);

      await tester.tap(find.byKey(const Key('xpUpContinueButton')));
      await settle(tester);

      // Summary last — perfect score, so only a primary Home button (#114).
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
      expect(find.byKey(const Key('xpUpScreen')), findsNothing);
      expect(find.text('2 of 2 correct (100%)'), findsOneWidget);
      expect(find.byKey(const Key('homeButton')), findsOneWidget);
      expect(find.byKey(const Key('redoMissedItemsButton')), findsNothing);
      expect(find.byKey(const Key('setOverviewButton')), findsNothing);
      expect(find.byKey(const Key('redoWholeSetButton')), findsNothing);
      expect(_isPrimaryButton(tester, 'homeButton'), isTrue);
    },
  );

  testWidgets(
    "the day's 2nd lesson completion shows the loot box then XP up (no "
    'streak screen, already advanced today), landing on a 2-button summary '
    'whose Redo missed items restarts with only the wrong item',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 20, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertTwoItemSet(db);
      // A prior attempt makes this a returning learner (Home itself no longer
      // resumes sets, #124).
      await statsRepo.recordAttempt(
        itemId: seed.dogId,
        ok: true,
        now: DateTime(2026, 10, 19, 9),
      );

      await pumpFoxStreakApp(
        tester,
        db: db,
        clock: clock,
        petCatalogLoader: () async => _fixtureCatalog,
      );
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // 1st completion of the day (perfect score): advances the streak,
      // no loot box yet.
      await startLessonFromHome(tester);
      await _answerCurrentItem(tester);
      await _answerCurrentItem(tester);
      expect(find.byKey(const Key('streakSavedScreen')), findsOneWidget);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // 2nd completion of the day (one wrong this time): triggers the loot
      // box automatically, same day so no streak screen this time.
      await startLessonFromHome(tester);
      await _answerCurrentItem(tester);
      await _answerCurrentItem(tester, wrong: true);

      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
      expect(find.byKey(const Key('streakSavedScreen')), findsNothing);
      expect(find.byKey(const Key('xpUpScreen')), findsNothing);

      await tester.tap(find.byKey(const Key('lootboxOpenButton')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('lootboxContinueButton')));
      await settle(tester);

      // XP up next — loot box is gone, no streak screen this time.
      expect(find.byKey(const Key('xpUpScreen')), findsOneWidget);
      expect(find.byKey(const Key('lootboxScreen')), findsNothing);
      expect(find.byKey(const Key('streakSavedScreen')), findsNothing);

      await tester.tap(find.byKey(const Key('xpUpContinueButton')));
      await settle(tester);

      // Summary: one wrong -> Redo missed items (primary) above Home
      // (secondary); the removed buttons are gone (#114).
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
      expect(find.text('1 of 2 correct (50%)'), findsOneWidget);
      expect(find.byKey(const Key('redoMissedItemsButton')), findsOneWidget);
      expect(_isPrimaryButton(tester, 'redoMissedItemsButton'), isTrue);
      expect(_isPrimaryButton(tester, 'homeButton'), isFalse);
      expect(find.byKey(const Key('setOverviewButton')), findsNothing);
      expect(find.byKey(const Key('redoWholeSetButton')), findsNothing);

      // Redo missed items restarts with only the one wrong item.
      await tester.ensureVisible(
        find.byKey(const Key('redoMissedItemsButton')),
      );
      await tester.tap(find.byKey(const Key('redoMissedItemsButton')));
      await settle(tester);
      await _answerCurrentItem(tester);
      await dismissCompletionScreens(tester);
      expect(find.text('1 / 1'), findsOneWidget);
    },
  );

  testWidgets('Home lands correctly regardless of entry point '
      "(Library row's play icon, which skips SetDetailScreen — #042)", (
    tester,
  ) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 20, 9));
    await _insertTwoItemSet(db);

    await pumpFoxStreakApp(
      tester,
      db: db,
      clock: clock,
      petCatalogLoader: () async => const <PetEntry>[],
    );
    await skipOnboardingAndOpenLibrary(tester);

    await tester.tap(playSetButton('Animals'));
    await settle(tester);
    expect(find.byKey(const Key('lessonProgressBar')), findsOneWidget);

    await _answerCurrentItem(tester);
    await _answerCurrentItem(tester);
    await dismissCompletionScreens(tester);
    expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);

    // Home — pops straight to Home, bypassing Library entirely.
    await tester.ensureVisible(find.byKey(const Key('homeButton')));
    await tester.tap(find.byKey(const Key('homeButton')));
    await settle(tester);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);

    // Home — same set, a different entry point this time (started via
    // Home's Browse sets, now with attempts already written), via the
    // summary's Home button.
    await startLessonFromHome(tester);
    await _answerCurrentItem(tester);
    await _answerCurrentItem(tester);
    await dismissCompletionScreens(tester);
    await tester.ensureVisible(find.byKey(const Key('homeButton')));
    await tester.tap(find.byKey(const Key('homeButton')));
    await settle(tester);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);
  });

  testWidgets('completing a lesson never flashes the summary screen or its pet '
      'before the streak-saved screen covers it (issue #083 regression)', (
    tester,
  ) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 20, 9));
    final statsRepo = StatsRepository(db, clock);
    await statsRepo.setOnboarded();

    final seed = await _insertTwoItemSet(db);
    await pumpLessonScreen(
      tester,
      db: db,
      clock: clock,
      setId: seed.setId,
      items: await db.select(db.items).get(),
      petCatalogLoader: () async => const <PetEntry>[],
    );

    await _answerCurrentItem(tester);

    // Answer the last item, then drive its own CONTINUE with a single,
    // unsettled pump — exactly the frame where `state.isDone` first
    // turns true, before the completion sequence's first push lands.
    final showingDog = find.text('der Hund').evaluate().isNotEmpty;
    await tester.tap(find.text(showingDog ? 'dog' : 'cat'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
    await settle(tester);
    await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
    await tester.pump();

    // No flash of the summary screen (or its pet) before the
    // streak-saved screen is pushed on top.
    expect(find.byKey(const Key('lessonResultScreen')), findsNothing);
    expect(find.byType(FoxPet), findsNothing);

    // The streak-saved screen still arrives right after.
    await settle(tester);
    expect(find.byKey(const Key('streakSavedScreen')), findsOneWidget);
  });

  testWidgets(
    "the day's 2nd lesson completion (loot-box-first) never flashes the "
    'summary screen or its pet before the loot box covers it (issue #083 '
    'regression)',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 20, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertTwoItemSet(db);
      await statsRepo.recordAttempt(
        itemId: seed.dogId,
        ok: true,
        now: DateTime(2026, 10, 19, 9),
      );

      await pumpFoxStreakApp(
        tester,
        db: db,
        clock: clock,
        petCatalogLoader: () async => _fixtureCatalog,
      );

      // 1st completion of the day: advances the streak, no loot box yet.
      await startLessonFromHome(tester);
      await _answerCurrentItem(tester);
      await _answerCurrentItem(tester);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);

      // 2nd completion of the day: triggers the loot box automatically,
      // no streak screen this time (already advanced today).
      await startLessonFromHome(tester);
      await _answerCurrentItem(tester);

      // Answer the last item, then drive its own CONTINUE with a single,
      // unsettled pump — exactly the frame where `state.isDone` first
      // turns true, before the completion sequence's first push lands.
      final showingDog = find.text('der Hund').evaluate().isNotEmpty;
      await tester.tap(find.text(showingDog ? 'dog' : 'cat'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
      await settle(tester);
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      await tester.pump();

      // No flash of the summary screen (or its pet) before the loot box
      // is pushed on top.
      expect(find.byKey(const Key('lessonResultScreen')), findsNothing);
      expect(find.byType(FoxPet), findsNothing);

      // The loot box still arrives right after.
      await settle(tester);
      expect(find.byKey(const Key('lootboxScreen')), findsOneWidget);
    },
  );
}
