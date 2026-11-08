// Integration test for the Home dashboard + first-run onboarding
// (issue #012).
//
// Drives the real `FoxStreakApp` (the actual `main.dart` wiring, not a
// bare `HomeScreen` pump) through two end-to-end flows:
// 1. Fresh install: onboarding gates Home; skipping it reveals the
//    dashboard, whose single "Browse sets" CTA genuinely opens the real
//    `LibraryScreen` (issue #124 removed the Continue shortcut).
// 2. A profile with one prior attempt: a lesson is started from the
//    library; completing the lesson (through the
//    #078 completion sequence) and tapping the summary screen's "Home"
//    button returns to Home, whose goal ring/streak badge/level-progress
//    bar now reflect the just-written XP/streak.

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
    'whose Browse sets CTA opens the real library',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _FixedClock();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(clock),
            integrationTestSilentSound,
          ],
          child: const FoxStreakApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboardingScreen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboardingSkipButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.text('Browse sets'), findsOneWidget);
      expect(find.byKey(const Key('homeContinueButton')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('homeBrowseSetsButton')));
      await tester.tap(find.byKey(const Key('homeBrowseSetsButton')));
      await tester.pumpAndSettle();
      expect(find.text('My Sets'), findsOneWidget);

      final statsRepo = StatsRepository(db, clock);
      expect((await statsRepo.getProfile()).hasOnboarded, isTrue);
    },
  );

  testWidgets(
    'with a prior attempt: a lesson started via Browse sets can be completed; '
    'returning to Home shows the updated XP/streak and no Continue button',
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
              position: 0,
            ),
          );
      // A prior attempt (e.g. yesterday), so this is a returning learner.
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
            integrationTestSilentSound,
          ],
          child: const FoxStreakApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboardingScreen')), findsNothing);
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.byKey(const Key('homeContinueButton')), findsNothing);
      expect(find.text('Browse sets'), findsOneWidget);

      await startLessonFromHome(tester);

      // The real LessonScreen for the "Animals" set — not a placeholder.
      expect(find.byKey(const Key('lessonProgressBar')), findsOneWidget);
      expect(find.text('der Hund'), findsOneWidget);

      await tester.tap(find.text('dog'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      await settle(tester);

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

      // Back on Home: the just-completed lesson's XP/streak show up.
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.byKey(const Key('homeContinueButton')), findsNothing);

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
