// Issue #087 — Streak on ice.
//
// Drives the real app end-to-end for the two user-visible flows the issue
// adds: (1) the app-launch auto-apply that bridges exactly one missed day
// by spending a banked streak freeze, surfacing a one-time banner on Home
// and a decremented freeze count on Streak Details; (2) winning the
// wheel-of-fortune's rare streak-on-ice segment, which banks a freeze
// instead of coins.
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';

import 'helpers.dart';

/// Forces every weighted draw to its last valid bucket — the wheel's own
/// table always ends on the rare streak-on-ice segment (issue #087) — and
/// the lootbox's coin-flip to the pet branch, which is irrelevant to these
/// assertions.
class _StreakOnIceRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => max - 1;

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
/// single item correctly, settling right after CONTINUE.
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'app launch auto-applies a banked streak freeze when exactly one day '
    'was missed: Home shows the one-time banner, the streak is preserved '
    '(not reset), and Streak Details reflects the consumed freeze',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final today = DateTime(2026, 10, 20, 9);
      final clock = FakeClock(today);
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final twoDaysAgo = toLocalDayString(DateTime(2026, 10, 18));
      await statsRepo.setStreak(streakCount: 5, lastActiveDay: twoDaysAgo);
      await statsRepo.addStreakFreezes(1);

      await pumpFoxStreakApp(tester, db: db, clock: clock);

      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(
        find.byKey(const Key('streakFreezeAppliedBanner')),
        findsOneWidget,
      );
      expect(
        find.text('Your streak was saved with a streak freeze! ❄️'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('streakBadgeButton')));
      await settle(tester);
      expect(find.text('Current streak: 5 days'), findsOneWidget);
      expect(find.text('No streak freezes available'), findsOneWidget);
      expect(find.text('Streak freeze used'), findsOneWidget);

      final profile = await statsRepo.getProfile();
      expect(profile.streakFreezesAvailable, 0);
      expect(profile.streakCount, 5);
      expect(profile.lastActiveDay, toLocalDayString(DateTime(2026, 10, 19)));
    },
  );

  testWidgets("the day's 3rd lesson completion can land the wheel on its rare "
      'streak-on-ice segment, banking a freeze instead of coins, visible on '
      'Streak Details', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 20, 9));
    final statsRepo = StatsRepository(db, clock);
    await statsRepo.setOnboarded();

    final seed = await _insertSingleItemSet(db);
    await statsRepo.recordAttempt(
      itemId: seed.itemId,
      ok: true,
      now: DateTime(2026, 10, 19, 9),
    );

    await pumpFoxStreakApp(
      tester,
      db: db,
      clock: clock,
      petCatalogLoader: () async => [],
      petRandom: () => _StreakOnIceRandom(),
    );

    for (var completion = 1; completion <= 2; completion++) {
      await _completeOneLessonFromHome(tester);
      await dismissCompletionScreens(tester);
      await tester.tap(find.byKey(const Key('homeButton')));
      await settle(tester);
    }

    // 3rd completion: the wheel's own trigger.
    await _completeOneLessonFromHome(tester);
    expect(find.byKey(const Key('wheelScreen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('wheelSpinButton')));
    await settle(tester);
    expect(find.text('You won a streak freeze! ❄️'), findsOneWidget);
    expect((await statsRepo.getProfile()).streakFreezesAvailable, 1);

    await tester.tap(find.byKey(const Key('wheelContinueButton')));
    await settle(tester);
    expect(find.byKey(const Key('wheelScreen')), findsNothing);

    await dismissCompletionScreens(tester);
    await tester.tap(find.byKey(const Key('homeButton')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('streakBadgeButton')));
    await settle(tester);
    expect(find.text('1 streak freeze available'), findsOneWidget);
  });
}
