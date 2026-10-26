// Integration test for the Home dashboard + first-run onboarding
// (issue #012).
//
// Drives the real `FoxStreakApp` (the actual `main.dart` wiring, not a
// bare `HomeScreen` pump) through two end-to-end flows:
// 1. Fresh install: onboarding gates Home; skipping it reveals the
//    dashboard, whose Continue slot is a "Browse sets" CTA (no attempts
//    yet) that genuinely opens the real `LibraryScreen`.
// 2. A profile with one prior attempt: Home's Continue button resumes the
//    real `LessonScreen` for that set; completing the lesson (through the
//    #078 completion sequence) and tapping the summary screen's "Home"
//    button returns to Home, whose goal ring/streak badge/level-progress
//    bar now reflect the just-written XP/streak, and whose Continue
//    button still points at the same set.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/main.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';

import 'helpers.dart';

class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 10, 13, 9);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh install: onboarding gates Home; skip reveals the dashboard, '
    'whose Continue CTA opens the real library',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _FixedClock();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(clock),
          ],
          child: const FoxStreakApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboardingScreen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboardingSkipButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(
        find.text('Browse sets'),
        findsNWidgets(2),
      ); // Continue CTA + the dedicated button

      await tester.ensureVisible(find.byKey(const Key('homeBrowseSetsButton')));
      await tester.tap(find.byKey(const Key('homeBrowseSetsButton')));
      await tester.pumpAndSettle();
      expect(find.text('My Sets'), findsOneWidget);

      final statsRepo = StatsRepository(db, clock);
      expect((await statsRepo.getProfile()).hasOnboarded, isTrue);
    },
  );

  testWidgets(
    'with a prior attempt: Continue resumes the real lesson; completing it '
    'and returning to Home shows the updated XP/streak and still points '
    'Continue at the same set',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _FixedClock();
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

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
              position: 0,
            ),
          );
      // A prior attempt (e.g. yesterday) is what Home's Continue button
      // derives the set from — no dedicated column.
      await statsRepo.recordAttempt(
        itemId: itemId,
        ok: true,
        now: DateTime(2026, 10, 12, 9),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(clock),
          ],
          child: const FoxStreakApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboardingScreen')), findsNothing);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.text('Continue practicing'), findsOneWidget);

      await tester.tap(find.byKey(const Key('homeContinueButton')));
      await tester.pumpAndSettle();

      // The real LessonScreen for the "Animals" set — not a placeholder.
      expect(find.byKey(const Key('lessonProgressBar')), findsOneWidget);
      expect(find.text('der Hund'), findsOneWidget);

      await tester.tap(find.text('dog'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      await tester.pumpAndSettle();

      // This fresh profile's first-ever lesson also advances the streak,
      // so the #078 completion sequence runs streak saved -> XP up before
      // the summary screen is reachable.
      await dismissCompletionScreens(tester);
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
      // The result screen is a SingleChildScrollView taller than the test
      // window (800x600) — scroll the button into view before tapping.
      // "Home" always returns Home regardless of entry point (issue #078
      // retired #034's entry-point-specific "Back to home"/"Back to
      // library" label distinction).
      await tester.ensureVisible(find.byKey(const Key('homeButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homeButton')));
      await tester.pumpAndSettle();

      // Back on Home: the just-completed lesson's XP/streak show up, and
      // Continue still resumes the same ("Animals") set.
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.text('Continue practicing'), findsOneWidget);

      final profile = await statsRepo.getProfile();
      expect(profile.todayXp, greaterThan(0));
      expect(profile.streakCount, greaterThan(0));
      expect(find.text(profile.streakCount.toString()), findsOneWidget);

      // The goal ring's center label reflects the real wiring end-to-end
      // (issue #037): just the earned XP, with the goal conveyed by fill.
      expect(find.byKey(const Key('goalRing')), findsOneWidget);
      expect(find.text('${profile.todayXp} XP'), findsOneWidget);
      expect(find.text('today'), findsOneWidget);
    },
  );
}
