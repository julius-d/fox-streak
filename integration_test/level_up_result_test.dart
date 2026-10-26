// Integration test for the level-up celebration on the XP-up completion
// screen (issue #053; moved from the combined lesson result screen onto
// its own dedicated `XpUpScreen` by issue #078).
//
// Drives the real `LessonScreen` with the real `MultipleChoiceCard` (no
// test card builder) through a lesson that crosses a level boundary,
// proving the "Level Up!" callout, the animated level-progress bar, and the
// confetti burst genuinely render — and a counterpart lesson that doesn't
// cross a boundary shows none of them (regression guard). Sound playback is
// stubbed via a fake `FoxSoundPlayer` override so this never touches a real
// platform audio channel.
//
// Deliberately avoids `tester.pumpAndSettle()` once the XP-up screen is
// showing: the `confetti` package's `ConfettiController` keeps scheduling
// animation frames (it restarts its internal `AnimationController` on every
// completed cycle until its particle system reports "finished", which
// depends on real wall-clock deltas the test clock never advances) —
// `pumpAndSettle()` would spin for a very long time waiting for a frame
// count that never reaches zero. A bounded `pump()` loop is used instead,
// long enough to settle the (ordinary, finite) count-up/celebration/bar
// animations without waiting on confetti. The streak-saved screen that
// precedes it (this is each test's fresh profile's first-ever lesson, so
// it always advances the streak) has no such unbounded animation, so it's
// safe to settle normally.

import 'package:confetti/confetti.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';
import 'package:fox_streak_app/test/data/test_helpers.dart';

/// Records calls instead of touching a real platform audio channel.
class FakeSoundPlayer implements FoxSoundPlayer {
  int playLevelUpCallCount = 0;
  int playCorrectCallCount = 0;

  @override
  Future<void> playLevelUp() async {
    playLevelUpCallCount++;
  }

  @override
  Future<void> playCorrect() async {
    playCorrectCallCount++;
  }
}

Future<Map<String, Item>> insertAnimalItems(AppDatabase db, int setId) async {
  final itemsByAnswer = <String, Item>{};
  for (final (prompt, answer, position) in [
    ('der Hund', 'dog', 0),
    ('die Katze', 'cat', 1),
  ]) {
    final id = await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            setId: setId,
            type: 'choice',
            prompt: prompt,
            answer: answer,
            position: position,
          ),
        );
    itemsByAnswer[answer] = Item(
      id: id,
      setId: setId,
      type: 'choice',
      prompt: prompt,
      answer: answer,
      position: position,
    );
  }
  return itemsByAnswer;
}

Future<void> answerAllCorrectly(
  WidgetTester tester,
  Map<String, Item> itemsByAnswer,
) async {
  // Keyed by prompt (unique) rather than answer: with exactly 2 items in
  // the set, each question's sole distractor is the *other* item's answer,
  // so both answer texts are simultaneously visible on every question
  // screen — scanning for "whichever known answer is visible" would often
  // tap the wrong (distractor) one. The prompt never collides this way, so
  // using it to look up the one known-correct answer is unambiguous.
  final remainingPromptToAnswer = {
    for (final item in itemsByAnswer.values) item.prompt: item.answer,
  };
  final total = remainingPromptToAnswer.length;
  for (var i = 0; i < total; i++) {
    final shownPrompt = remainingPromptToAnswer.keys.firstWhere(
      (p) => find.text(p).evaluate().isNotEmpty,
    );
    final correctAnswer = remainingPromptToAnswer.remove(shownPrompt)!;
    await tester.tap(find.text(correctAnswer));
    await tester.pump();
    await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
    await tester.pumpAndSettle();
    if (i < total - 1) {
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a lesson that crosses a level boundary shows the "Level Up!" callout, '
    'the animated level-progress bar, and a confetti burst, and plays the '
    'chime through the overridable sound seam',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 13, 9));
      final statsRepo = StatsRepository(db, clock);
      final fakeSoundPlayer = FakeSoundPlayer();

      // Pre-seed xpTotal just below the level-2 threshold (100): the
      // lesson's 25 XP (10 + 10 correct + 5 perfect bonus) crosses it.
      await statsRepo.addXp(80, now: clock.now());

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
      final itemsByAnswer = await insertAnimalItems(db, setId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(clock),
            foxSoundPlayerProvider.overrideWithValue(fakeSoundPlayer),
          ],
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LessonScreen(
              setId: setId,
              items: itemsByAnswer.values.toList(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await answerAllCorrectly(tester, itemsByAnswer);

      // The final CONTINUE completes the lesson. This fresh profile's
      // first-ever lesson also advances the streak, so the streak-saved
      // screen appears first — no confetti there, safe to settle normally.
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('streakSavedContinueButton')));

      // XP up mounts next (confetti starts playing) — see file doc for why
      // this uses a bounded pump loop instead of pumpAndSettle().
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byKey(const Key('xpUpScreen')), findsOneWidget);
      expect(find.byKey(const Key('levelUpCallout')), findsOneWidget);
      expect(find.text('Level Up! Level 2'), findsOneWidget);
      expect(find.byKey(const Key('levelUpProgressAnimation')), findsOneWidget);

      final confettiWidget = tester.widget<ConfettiWidget>(
        find.byKey(const Key('levelUpConfetti')),
      );
      expect(
        confettiWidget.confettiController.state,
        ConfettiControllerState.playing,
      );
      expect(fakeSoundPlayer.playLevelUpCallCount, 1);

      final profile = await statsRepo.getProfile();
      expect(profile.xpTotal, 105);
    },
  );

  testWidgets('a lesson that does not cross a level boundary shows none of the '
      'level-up callout/animated bar/confetti, and never plays the chime '
      '(regression guard)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 13, 9));
    final statsRepo = StatsRepository(db, clock);
    final fakeSoundPlayer = FakeSoundPlayer();

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
    final itemsByAnswer = await insertAnimalItems(db, setId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(clock),
          foxSoundPlayerProvider.overrideWithValue(fakeSoundPlayer),
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LessonScreen(
            setId: setId,
            items: itemsByAnswer.values.toList(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await answerAllCorrectly(tester, itemsByAnswer);

    // No level-up here, so there's no confetti to worry about: a plain
    // pumpAndSettle() is safe throughout, same as the other result-screen
    // specs. This fresh profile's first-ever lesson still advances the
    // streak, so the streak-saved screen appears before XP up.
    await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('streakSavedContinueButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('xpUpScreen')), findsOneWidget);
    expect(find.byKey(const Key('levelUpCallout')), findsNothing);
    expect(find.byKey(const Key('levelUpProgressAnimation')), findsNothing);
    expect(find.byKey(const Key('levelUpConfetti')), findsNothing);
    expect(fakeSoundPlayer.playLevelUpCallCount, 0);

    final profile = await statsRepo.getProfile();
    expect(profile.xpTotal, 25); // well under the level-2 threshold (100)
  });
}
