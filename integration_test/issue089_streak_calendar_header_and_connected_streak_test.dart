// Integration test for the #089 Streak Details calendar polish: weekday/
// month header labels and the connected (not per-cell) streak highlight.
//
// Drives the real `FoxStreakApp` from Home, same entry point as #084's
// `issue084_streak_details_test.dart`, with a real current streak whose
// days (Fri/Sat 2026-10-09/10, Sun/Mon 2026-10-11/12) deliberately cross a
// week-column boundary, so the merged-shape + connector rendering is
// exercised against real `daily_activity` rows, not just a hand-built
// `ActivityCalendarData` in a widget test.

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
  DateTime now() => DateTime(2026, 10, 12, 9);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the real Streak Details calendar shows weekday/month header labels '
    'and renders a boundary-crossing streak as merged shapes with a '
    'connector',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _FixedClock();
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      // A 4-day current streak (Fri/Sat/Sun/Mon) that crosses a
      // week-column boundary between Sat 2026-10-10 and Sun 2026-10-11.
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

      await tester.tap(find.byKey(const Key('streakBadgeButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('streakDetailsScreen')), findsOneWidget);

      // Weekday header: narrow English letters on Mon/Wed/Fri only.
      expect(find.text('M'), findsWidgets);
      expect(find.text('W'), findsWidgets);
      expect(find.text('F'), findsWidgets);

      // Month header: the ~6-month window ending October 2026 includes an
      // "Oct" label.
      expect(find.text('Oct'), findsOneWidget);

      // The Fri/Sat segment and the Sun/Mon segment are each one merged
      // shape (keyed by their first day), not 4 separate per-cell borders.
      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-09')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-10')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-11')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-12')),
        findsNothing,
      );

      // A connector (one notch per boundary cell) bridges the two
      // segments across the week-column boundary.
      final connector = find.byWidgetPredicate(
        (widget) =>
            widget.key?.toString().contains('activityCalendarConnector') ??
            false,
      );
      expect(connector, findsNWidgets(2));
    },
  );
}
