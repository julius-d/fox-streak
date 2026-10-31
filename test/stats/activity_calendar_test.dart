// Unit tests for the #084 Streak Details calendar's pure logic: window
// building, color buckets, current-streak days, longest-run-in-window, and
// the combined ActivityCalendarData.build.

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/stats/activity_calendar.dart';

DailyActivityData entry(String day, int xp) => DailyActivityData(
  day: day,
  xpEarned: xp,
  activitySource: 'lessonCompleted',
);

void main() {
  group('buildWindowDays', () {
    test('spans exactly ~6 months, ascending, ending at today', () {
      final days = buildWindowDays(today: DateTime(2026, 10, 31));
      // April only has 30 days; DateTime(2026, 4, 31) normalizes forward to
      // May 1st — an accepted "~6 months" wobble, not exact calendar math.
      expect(days.first, '2026-05-01');
      expect(days.last, '2026-10-31');
      expect(days, hasLength(days.toSet().length)); // no duplicates
      expect(
        days,
        everyElement(
          predicate<String>((d) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)),
        ),
      );
    });

    test('is strictly ascending', () {
      final days = buildWindowDays(today: DateTime(2026, 10, 31));
      for (var i = 1; i < days.length; i++) {
        expect(days[i].compareTo(days[i - 1]), greaterThan(0));
      }
    });

    test('handles a year rollover cleanly', () {
      final days = buildWindowDays(today: DateTime(2026, 1, 15));
      expect(days.first, '2025-07-15');
      expect(days.last, '2026-01-15');
    });
  });

  group('bucketFor', () {
    test('no row -> none, regardless of goal', () {
      expect(
        bucketFor(hasActivity: false, xpEarned: 0, dailyGoalXp: 100),
        ActivityLevel.none,
      );
    });

    test('a row with xpEarned 0 is the lowest non-empty bucket, not none '
        '(the future streakOnIce case)', () {
      expect(
        bucketFor(hasActivity: true, xpEarned: 0, dailyGoalXp: 100),
        ActivityLevel.low,
      );
    });

    test('>0-<50% of goal is low', () {
      expect(
        bucketFor(hasActivity: true, xpEarned: 49, dailyGoalXp: 100),
        ActivityLevel.low,
      );
    });

    test('50-99% of goal is medium', () {
      expect(
        bucketFor(hasActivity: true, xpEarned: 50, dailyGoalXp: 100),
        ActivityLevel.medium,
      );
      expect(
        bucketFor(hasActivity: true, xpEarned: 99, dailyGoalXp: 100),
        ActivityLevel.medium,
      );
    });

    test('>=100% of goal is high', () {
      expect(
        bucketFor(hasActivity: true, xpEarned: 100, dailyGoalXp: 100),
        ActivityLevel.high,
      );
      expect(
        bucketFor(hasActivity: true, xpEarned: 500, dailyGoalXp: 100),
        ActivityLevel.high,
      );
    });

    test('dailyGoalXp <= 0: any earned xp is high, zero is low', () {
      expect(
        bucketFor(hasActivity: true, xpEarned: 10, dailyGoalXp: 0),
        ActivityLevel.high,
      );
      expect(
        bucketFor(hasActivity: true, xpEarned: 0, dailyGoalXp: 0),
        ActivityLevel.low,
      );
    });
  });

  group('currentStreakDays', () {
    test('empty when streakCount is 0', () {
      expect(
        currentStreakDays(streakCount: 0, lastActiveDay: '2026-10-11'),
        isEmpty,
      );
    });

    test('empty when lastActiveDay is null', () {
      expect(currentStreakDays(streakCount: 3, lastActiveDay: null), isEmpty);
    });

    test('empty for a malformed lastActiveDay', () {
      expect(
        currentStreakDays(streakCount: 3, lastActiveDay: 'not-a-date'),
        isEmpty,
      );
    });

    test('the exact N consecutive days ending at lastActiveDay', () {
      final days = currentStreakDays(
        streakCount: 3,
        lastActiveDay: '2026-10-11',
      );
      expect(days, {'2026-10-09', '2026-10-10', '2026-10-11'});
    });

    test('a single-day streak is just lastActiveDay itself', () {
      expect(currentStreakDays(streakCount: 1, lastActiveDay: '2026-10-11'), {
        '2026-10-11',
      });
    });

    test('crosses a month boundary correctly', () {
      final days = currentStreakDays(
        streakCount: 3,
        lastActiveDay: '2026-11-01',
      );
      expect(days, {'2026-10-30', '2026-10-31', '2026-11-01'});
    });
  });

  group('longestRunInWindow', () {
    final window = buildWindowDays(today: DateTime(2026, 10, 10));

    test('empty when nothing is active', () {
      expect(longestRunInWindow(window, {}), isEmpty);
    });

    test('a single active day is a run of length 1', () {
      final run = longestRunInWindow(window, {'2026-10-10'});
      expect(run, {'2026-10-10'});
    });

    test('finds the longest of several runs, separated by gaps', () {
      final active = {
        '2026-10-01',
        '2026-10-02',
        // gap
        '2026-10-05',
        '2026-10-06',
        '2026-10-07',
        '2026-10-08',
        // gap
        '2026-10-10',
      };
      final run = longestRunInWindow(window, active);
      expect(run, {'2026-10-05', '2026-10-06', '2026-10-07', '2026-10-08'});
    });

    test('a tie between two equal-length runs prefers the most recent', () {
      final active = {
        '2026-10-01',
        '2026-10-02',
        // gap
        '2026-10-09',
        '2026-10-10',
      };
      final run = longestRunInWindow(window, active);
      expect(run, {'2026-10-09', '2026-10-10'});
    });
  });

  group('ActivityCalendarData.build', () {
    final today = DateTime(2026, 10, 11);

    test('every window day is represented, oldest first, today last', () {
      final data = ActivityCalendarData.build(
        today: today,
        streakCount: 0,
        lastActiveDay: null,
        dailyGoalXp: 100,
        entries: const [],
      );
      expect(data.days.first.day, buildWindowDays(today: today).first);
      expect(data.days.last.day, '2026-10-11');
      expect(data.days, hasLength(buildWindowDays(today: today).length));
    });

    test('days without a daily_activity row render level.none and no '
        'highlight', () {
      final data = ActivityCalendarData.build(
        today: today,
        streakCount: 0,
        lastActiveDay: null,
        dailyGoalXp: 100,
        entries: const [],
      );
      for (final d in data.days) {
        expect(d.hasActivity, isFalse);
        expect(d.level, ActivityLevel.none);
        expect(d.isCurrentStreak, isFalse);
        expect(d.isLongestStreak, isFalse);
      }
    });

    test('the current streak run is highlighted with isCurrentStreak', () {
      final data = ActivityCalendarData.build(
        today: today,
        streakCount: 3,
        lastActiveDay: '2026-10-11',
        dailyGoalXp: 100,
        entries: [
          entry('2026-10-09', 10),
          entry('2026-10-10', 10),
          entry('2026-10-11', 10),
        ],
      );
      final highlighted = data.days
          .where((d) => d.isCurrentStreak)
          .map((d) => d.day);
      expect(highlighted, {'2026-10-09', '2026-10-10', '2026-10-11'});
      expect(data.currentStreakCount, 3);
    });

    test('longest-in-window is highlighted separately when it differs from '
        'the current streak', () {
      final data = ActivityCalendarData.build(
        today: today,
        streakCount: 1,
        lastActiveDay: '2026-10-11',
        dailyGoalXp: 100,
        entries: [
          entry('2026-09-01', 10),
          entry('2026-09-02', 10),
          entry('2026-09-03', 10),
          entry('2026-10-11', 10),
        ],
      );
      expect(data.longestDiffersFromCurrent, isTrue);
      expect(data.longestStreakInWindow, 3);
      final longestDays = data.days
          .where((d) => d.isLongestStreak)
          .map((d) => d.day);
      expect(longestDays, {'2026-09-01', '2026-09-02', '2026-09-03'});
      // The current-streak day is highlighted too, but not double-tagged
      // as the longest run.
      final current = data.days.where((d) => d.day == '2026-10-11').single;
      expect(current.isCurrentStreak, isTrue);
      expect(current.isLongestStreak, isFalse);
    });

    test('when the longest run in window IS the current streak, only the '
        'current-streak highlight is set (no duplicate longest highlight)', () {
      final data = ActivityCalendarData.build(
        today: today,
        streakCount: 3,
        lastActiveDay: '2026-10-11',
        dailyGoalXp: 100,
        entries: [
          entry('2026-10-09', 10),
          entry('2026-10-10', 10),
          entry('2026-10-11', 10),
        ],
      );
      expect(data.longestDiffersFromCurrent, isFalse);
      expect(data.days.where((d) => d.isLongestStreak), isEmpty);
    });

    test(
      'a row with xpEarned 0 still renders as hasActivity/low, not none',
      () {
        final data = ActivityCalendarData.build(
          today: today,
          streakCount: 0,
          lastActiveDay: null,
          dailyGoalXp: 100,
          entries: [entry('2026-10-11', 0)],
        );
        final day = data.days.last;
        expect(day.hasActivity, isTrue);
        expect(day.level, ActivityLevel.low);
      },
    );
  });
}
