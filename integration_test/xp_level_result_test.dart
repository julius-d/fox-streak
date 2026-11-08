// Integration test for XP + level display on the XP-up completion screen
// (issue #010; moved from the combined lesson result screen onto its own
// dedicated `XpUpScreen` by issue #078).
//
// Drives the real `LessonScreen` with the real `MultipleChoiceCard` (no
// test card builder) through a perfect-score lesson, proving the XP
// count-up, perfect-score bonus callout, and level-progress bar genuinely
// render with the right numbers — and that the underlying `xp_total`/
// `today_xp` columns were actually written exactly once.
//
// The `+25 XP` assertion below is checked via `helpers.dart`'s shared
// `pumpUntilFound` rather than trusting the preceding `pumpAndSettle()`
// alone (issue #076): on a macOS desktop integration run,
// `pumpAndSettle()` can occasionally report settled a frame or two before
// `_XpCountUp`'s 600ms `TweenAnimationBuilder` has actually reached its
// final value — confirmed by re-running this spec dozens of times, where
// the `xpUpScreen`/`xpEarnedLabel` keys were already present but the text
// was still mid-count-up. Not a product bug (the same real-time-vs-fake
// clock class of race `pumpUntilFound` was introduced for in issue #077's
// confetti-state check) — forcing a few extra frames here is enough.

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

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a perfect-score lesson shows the XP count-up, perfect bonus callout, '
    'and level-progress bar, and writes xp_total/today_xp exactly once',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 13, 9));
      final statsRepo = StatsRepository(db, clock);

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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(clock),
            integrationTestSilentSound,
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

      // Answer both items correctly, in whatever order they were shuffled.
      // Keyed by prompt (unique) rather than answer: with exactly 2 items
      // in the set, each question's sole distractor is the *other* item's
      // answer, so both answer texts are simultaneously visible on every
      // question screen — scanning for "whichever known answer is visible"
      // would often tap the wrong (distractor) one.
      final remainingPromptToAnswer = {
        for (final item in itemsByAnswer.values) item.prompt: item.answer,
      };
      for (var i = 0; i < 2; i++) {
        final shownPrompt = remainingPromptToAnswer.keys.firstWhere(
          (p) => find.text(p).evaluate().isNotEmpty,
        );
        final correctAnswer = remainingPromptToAnswer.remove(shownPrompt)!;
        await tester.tap(find.text(correctAnswer));
        await tester.pump();
        await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
        if (i == 1) {
          // The final CONTINUE completes the lesson, mounting the
          // confetti-bearing `StreakSavedScreen` (#083): its
          // `ConfettiController` drives particle physics off real
          // wall-clock time rather than this binding's fake clock, so
          // `pumpAndSettle()` would spin until it times out. A bounded
          // pump loop is enough to settle the screen's own (ordinary,
          // finite) animations.
          for (var j = 0; j < 15; j++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        } else {
          await tester.pumpAndSettle();
        }
      }

      // This fresh profile's first-ever lesson also advances the streak,
      // so the streak-saved screen appears before XP up (no level-up here,
      // so no XP-up confetti — plain pumpAndSettle() doesn't need to race
      // a real-time particle simulation once the streak screen's own
      // confetti is dismissed). See the `pumpUntilFound` call below for
      // the other, unrelated real-time race this spec still has to guard.
      await tester.tap(find.byKey(const Key('streakSavedContinueButton')));
      await tester.pumpAndSettle();

      // XP up screen: 100% score -> 10+10 per-item XP + 5 perfect bonus.
      expect(find.byKey(const Key('xpUpScreen')), findsOneWidget);
      expect(find.byKey(const Key('xpEarnedLabel')), findsOneWidget);
      // See file doc (issue #076) for why this waits via `pumpUntilFound`
      // instead of trusting `pumpAndSettle()` alone.
      await pumpUntilFound(tester, find.text('+25 XP'));
      expect(find.text('+25 XP'), findsOneWidget);
      expect(find.byKey(const Key('xpBonusCallout')), findsOneWidget);
      expect(find.text('+5 Perfect!'), findsOneWidget);
      expect(find.byKey(const Key('levelProgressBar')), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('25 / 100 XP to next level'), findsOneWidget);

      // The write actually landed exactly once (no double-apply).
      final profile = await statsRepo.getProfile();
      expect(profile.xpTotal, 25);
      expect(profile.todayXp, 25);
    },
  );
}
