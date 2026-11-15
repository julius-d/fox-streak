// Integration test for the #089 Streak Details calendar polish (weekday/
// month header labels, connected streak highlight), updated for #128's
// Monday-first weeks and open-ended streak bands.
//
// Drives the real `FoxStreakApp` from Home, same entry point as #084's
// `issue084_streak_details_test.dart`, with a real current streak whose
// days (Fri/Sat/Sun 2026-10-09..11, Mon 2026-10-12) deliberately cross a
// week-column boundary, so the band rendering is exercised against real
// `daily_activity` rows, not just a hand-built `ActivityCalendarData` in a
// widget test.

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
import 'package:fox_streak_app/src/stats/activity_calendar_view.dart';

import 'helpers.dart';

class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 9);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the real Streak Details calendar shows weekday/month header labels '
    'and renders a boundary-crossing streak as one band per week column, '
    'open at the week break',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _FixedClock();
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      // A 4-day current streak (Fri/Sat/Sun/Mon) that crosses the
      // Monday-first week-column boundary between Sun 2026-10-11 and Mon
      // 2026-10-12.
      await statsRepo.setStreak(streakCount: 4, lastActiveDay: '2026-10-12');
      for (final day in [
        '2026-10-09',
        '2026-10-10',
        '2026-10-11',
        '2026-10-12',
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
            integrationTestSilentSound,
          ],
          child: const FoxStreakApp(),
        ),
      );
      await tester.pumpAndSettle();

      await openStreakDetails(tester);
      expect(find.byKey(const Key('streakDetailsScreen')), findsOneWidget);

      // Weekday header: narrow English letters on Mon/Wed/Fri only.
      expect(find.text('M'), findsWidgets);
      expect(find.text('W'), findsWidgets);
      expect(find.text('F'), findsWidgets);

      // Month header: the ~6-month window ending October 2026 includes an
      // "Oct" label.
      expect(find.text('Oct'), findsOneWidget);

      // The Fri..Sun segment and the Mon segment are each one band (keyed
      // by their first day), not 4 separate per-cell borders.
      StreakBandPainter band(String firstDay) =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(Key('activityCalendarBand-$firstDay')),
                  )
                  .painter!
              as StreakBandPainter;
      expect(band('2026-10-09').openBottom, isTrue);
      expect(band('2026-10-09').openTop, isFalse);
      expect(band('2026-10-12').openTop, isTrue);
      expect(band('2026-10-12').openBottom, isFalse);
      for (final day in ['2026-10-10', '2026-10-11']) {
        expect(find.byKey(Key('activityCalendarBand-$day')), findsNothing);
      }
    },
  );
}
