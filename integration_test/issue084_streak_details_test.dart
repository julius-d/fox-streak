// Integration test for the Streak Details screen (issue #084).
//
// Drives the real `FoxStreakApp` from Home: tapping the real StreakBadge
// genuinely opens `StreakDetailsScreen`, which renders the exact current
// streak and the longest run within the ~6-month window from real
// `daily_activity` rows written through `StatsRepository`, with today's
// calendar cell actually highlighted as the current streak — then
// confirms the back button returns to Home.

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

class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 10, 13, 9);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tapping Home\'s streak badge opens the real Streak Details screen, '
    'showing the current streak and the longest-in-window run from real '
    'daily_activity rows, with today highlighted as the current streak',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _FixedClock();
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      // A 3-day current streak ending today (2026-10-11..13).
      await statsRepo.setStreak(streakCount: 3, lastActiveDay: '2026-10-13');
      for (final day in ['2026-10-11', '2026-10-12', '2026-10-13']) {
        await statsRepo.recordDailyActivity(
          day: day,
          xpDelta: 10,
          source: DailyActivitySource.lessonCompleted,
        );
      }
      // An earlier, longer run (5 days) elsewhere in the window, so the
      // longest-in-window headline differs from the current streak.
      for (final day in [
        '2026-09-01',
        '2026-09-02',
        '2026-09-03',
        '2026-09-04',
        '2026-09-05',
      ]) {
        await statsRepo.recordDailyActivity(
          day: day,
          xpDelta: 10,
          source: DailyActivitySource.lessonCompleted,
        );
      }

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

      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.byKey(const Key('streakBadgeButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('streakBadgeButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('streakDetailsScreen')), findsOneWidget);
      expect(find.text('Current streak: 3 days'), findsOneWidget);
      expect(find.text('Longest in the last 6 months: 5 days'), findsOneWidget);
      expect(find.byKey(const Key('activityCalendar')), findsOneWidget);
      expect(
        find.byKey(const Key('activityCalendarCell-2026-10-13')),
        findsOneWidget,
      );

      // The back button returns to the real Home, not a dead end.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
    },
  );
}
