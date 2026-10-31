// Widget tests for StreakDetailsScreen (issue #084): headline counts,
// calendar + legend presence, and that they reflect real repository state.
//
// NOTE on pumping: bounded `settle()` instead of `pumpAndSettle()` — same
// drift `watch()`-under-fake-async caveat as `test/home/home_screen_test.dart`
// (this screen watches `profileProvider` transitively via
// `activityCalendarProvider`).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/stats/streak_details_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import '../data/test_helpers.dart';

Future<void> settle(WidgetTester tester, {int cap = 50}) async {
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('UI did not settle after $cap frames');
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<AppDatabase> pumpStreakDetails(
  WidgetTester tester,
  FakeClock clock, {
  Future<void> Function(StatsRepository stats)? seed,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  if (seed != null) {
    await seed(StatsRepository(db, clock));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StreakDetailsScreen(),
      ),
    ),
  );
  await settle(tester);
  return db;
}

void main() {
  testWidgets('shows the app bar title, headlines, calendar, and legend', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    await pumpStreakDetails(tester, clock);

    expect(find.text('Streak history'), findsOneWidget);
    expect(find.byKey(const Key('currentStreakHeadline')), findsOneWidget);
    expect(find.byKey(const Key('longestStreakHeadline')), findsOneWidget);
    expect(find.byKey(const Key('activityCalendar')), findsOneWidget);
    expect(find.byKey(const Key('activityCalendarLegend')), findsOneWidget);
    expect(find.text('No activity'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Goal reached'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('with no activity yet, both headlines read zero', (tester) async {
    final clock = FakeClock(kTestToday);
    await pumpStreakDetails(tester, clock);

    expect(find.text('No current streak'), findsOneWidget);
    expect(find.text('No activity in the last 6 months'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the current-streak headline reflects profile.streakCount', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    await pumpStreakDetails(
      tester,
      clock,
      seed: (stats) async {
        await stats.setStreak(
          streakCount: 4,
          lastActiveDay: clock.todayDayString(),
        );
      },
    );

    expect(find.text('Current streak: 4 days'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'the longest-in-window headline reflects recorded daily_activity rows',
    (tester) async {
      final clock = FakeClock(kTestToday);
      await pumpStreakDetails(
        tester,
        clock,
        seed: (stats) async {
          for (final day in ['2026-10-01', '2026-10-02', '2026-10-03']) {
            await stats.recordDailyActivity(
              day: day,
              xpDelta: 10,
              source: DailyActivitySource.lessonCompleted,
            );
          }
        },
      );

      expect(find.text('Longest in the last 6 months: 3 days'), findsOneWidget);
      await unmount(tester);
    },
  );
}
