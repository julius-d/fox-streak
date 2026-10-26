// Issue #078 — Lesson completion split into sequential screens (loot box
// -> streak saved -> XP up -> summary).
//
// Covers what `level_up_result_test.dart`/`xp_level_result_test.dart`/
// `streak_result_test.dart` don't: the sequencing itself (which screen
// shows first, that an earlier screen is actually gone once its own
// Continue is tapped) and the summary screen's own behavior (4-vs-3
// buttons depending on missed items, Redo whole set vs. Redo missed items
// actually restarting the right item set, and Home/Set overview landing
// in the right place regardless of which entry point launched the
// lesson).
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
    'that order, landing on a perfect-score 3-button summary',
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

      // Summary last — perfect score, so only 3 buttons (no Redo missed
      // items) and Redo whole set is the primary one.
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
      expect(find.byKey(const Key('xpUpScreen')), findsNothing);
      expect(find.text('2 of 2 correct (100%)'), findsOneWidget);
      expect(find.byKey(const Key('homeButton')), findsOneWidget);
      expect(find.byKey(const Key('setOverviewButton')), findsOneWidget);
      expect(find.byKey(const Key('redoWholeSetButton')), findsOneWidget);
      expect(find.byKey(const Key('redoMissedItemsButton')), findsNothing);
      expect(_isPrimaryButton(tester, 'redoWholeSetButton'), isTrue);
      expect(_isPrimaryButton(tester, 'homeButton'), isFalse);
    },
  );

  testWidgets(
    "the day's 2nd lesson completion shows the loot box then XP up (no "
    'streak screen, already advanced today), landing on a 4-button summary '
    'whose Redo missed items restarts with only the wrong item',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 20, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final seed = await _insertTwoItemSet(db);
      // Home's Continue button derives its set from the latest `attempts`
      // row — seed one so Home resumes "Animals" straight away.
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
      await tester.tap(find.byKey(const Key('homeContinueButton')));
      await settle(tester);
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
      await tester.tap(find.byKey(const Key('homeContinueButton')));
      await settle(tester);
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

      // Summary: one wrong -> 4 buttons, Redo missed items is primary.
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
      expect(find.text('1 of 2 correct (50%)'), findsOneWidget);
      expect(find.byKey(const Key('redoMissedItemsButton')), findsOneWidget);
      expect(_isPrimaryButton(tester, 'redoMissedItemsButton'), isTrue);
      expect(_isPrimaryButton(tester, 'redoWholeSetButton'), isFalse);

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

  testWidgets(
    'Home and Set overview both land correctly regardless of entry point '
    "(Library row's play icon, which skips SetDetailScreen — #042)",
    (tester) async {
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

      // Set overview — pops straight to Home, then pushes SetDetailScreen
      // for "Animals", bypassing Library entirely (not just visually).
      await tester.ensureVisible(find.byKey(const Key('setOverviewButton')));
      await tester.tap(find.byKey(const Key('setOverviewButton')));
      await settle(tester);
      expect(find.byKey(const Key('startLessonFab')), findsOneWidget);
      expect(find.byKey(const Key('homeScreen')), findsNothing);

      await tester.pageBack();
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);

      // Home — same set, a different entry point this time (Home's own
      // Continue button, now resuming "Animals" from the attempts just
      // written), via the summary's Home button.
      await tester.tap(find.byKey(const Key('homeContinueButton')));
      await settle(tester);
      await _answerCurrentItem(tester);
      await _answerCurrentItem(tester);
      await dismissCompletionScreens(tester);
      await tester.ensureVisible(find.byKey(const Key('homeButton')));
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
    },
  );
}
