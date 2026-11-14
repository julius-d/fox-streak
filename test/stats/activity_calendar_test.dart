// Unit tests for the Streak Details screen's pure logic (#084, #128):
// window building, day states, current-streak days, longest run, the
// combined ActivityCalendarData.build (hero/stat numbers), Monday-first
// week grouping, and streak-band segments with open ends at week breaks.

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/stats/activity_calendar.dart';

DailyActivityData entry(
  String day,
  int xp, {
  String source = 'lessonCompleted',
}) => DailyActivityData(day: day, xpEarned: xp, activitySource: source);

DailyActivityData freeze(String day) => entry(day, 0, source: 'streakOnIce');

String oct(int d) => '2026-10-${d.toString().padLeft(2, '0')}';

void main() {
  group('buildWindowDays', () {
    test('spans exactly 6 months, ascending, ending at today', () {
      final days = buildWindowDays(today: DateTime(2026, 10, 11));
      expect(days.first, '2026-04-11');
      expect(days.last, '2026-10-11');
    });

    test('is strictly ascending', () {
      final days = buildWindowDays(today: DateTime(2026, 10, 11));
      for (var i = 1; i < days.length; i++) {
        expect(days[i].compareTo(days[i - 1]), greaterThan(0));
      }
    });

    test('handles a year rollover cleanly', () {
      final days = buildWindowDays(today: DateTime(2027, 2, 3));
      expect(days.first, '2026-08-03');
      expect(days, contains('2026-12-31'));
      expect(days, contains('2027-01-01'));
    });

    test('reaches back to an older first recorded day', () {
      final days = buildWindowDays(
        today: DateTime(2026, 10, 11),
        firstRecordedDay: '2025-01-05',
      );
      expect(days.first, '2025-01-05');
      expect(days.last, '2026-10-11');
    });

    test('a first recorded day inside the 6 months keeps the 6 months', () {
      final days = buildWindowDays(
        today: DateTime(2026, 10, 11),
        firstRecordedDay: '2026-09-01',
      );
      expect(days.first, '2026-04-11');
    });
  });

  group('stateFor', () {
    test('no row is none, a lesson row is practiced, a freeze row is '
        'streakFreeze', () {
      expect(stateFor(null), ActivityDayState.none);
      expect(stateFor(entry('2026-10-01', 0)), ActivityDayState.practiced);
      expect(stateFor(freeze('2026-10-01')), ActivityDayState.streakFreeze);
    });
  });

  group('currentStreakDays', () {
    test('empty when streakCount is 0 or lastActiveDay is null/malformed', () {
      expect(
        currentStreakDays(streakCount: 0, lastActiveDay: '2026-10-11'),
        isEmpty,
      );
      expect(currentStreakDays(streakCount: 3, lastActiveDay: null), isEmpty);
      expect(currentStreakDays(streakCount: 3, lastActiveDay: 'x'), isEmpty);
    });

    test('the exact N consecutive days ending at lastActiveDay, across a '
        'month boundary', () {
      expect(currentStreakDays(streakCount: 3, lastActiveDay: '2026-10-02'), {
        '2026-09-30',
        '2026-10-01',
        '2026-10-02',
      });
    });
  });

  test('currentStreakDays: a bridged freeze day is part of the run but '
      'not counted, so the first day stays in', () {
    // 5 practiced days, a freeze on Oct 6, a lesson on Oct 7: streak 6.
    expect(
      currentStreakDays(
        streakCount: 6,
        lastActiveDay: oct(7),
        freezeDays: {oct(6)},
      ),
      {oct(1), oct(2), oct(3), oct(4), oct(5), oct(6), oct(7)},
    );
    // Right after the launch auto-apply, lastActiveDay is the freeze day.
    expect(
      currentStreakDays(
        streakCount: 2,
        lastActiveDay: oct(6),
        freezeDays: {oct(6)},
      ),
      {oct(4), oct(5), oct(6)},
    );
  });

  group('longestRun', () {
    final window = [oct(1), oct(2), oct(3), oct(4)];

    test('empty when nothing is active', () {
      expect(longestRun(window, {}), isEmpty);
    });

    test('finds the longest of several runs, separated by gaps', () {
      expect(longestRun(window, {oct(1), oct(3), oct(4)}), {oct(3), oct(4)});
    });

    test('a tie between two equal-length runs prefers the most recent', () {
      expect(longestRun(window, {oct(1), oct(4)}), {oct(4)});
    });

    test('handles a multi-year run', () {
      final days = buildWindowDays(
        today: DateTime(2026, 10, 11),
        firstRecordedDay: '2023-10-11',
      );
      expect(longestRun(days, days.toSet()), hasLength(days.length));
    });
  });

  group('ActivityCalendarData.build', () {
    final today = DateTime(2026, 10, 11);

    ActivityCalendarData build({
      int streakCount = 0,
      String? lastActiveDay,
      List<DailyActivityData> entries = const [],
      int freezes = 0,
    }) => ActivityCalendarData.build(
      today: today,
      streakCount: streakCount,
      lastActiveDay: lastActiveDay,
      entries: entries,
      streakFreezesAvailable: freezes,
    );

    test('every window day is represented, oldest first, today last and '
        'marked as today', () {
      final data = build();
      expect(data.days.first.day, buildWindowDays(today: today).first);
      expect(data.days.last.day, oct(11));
      expect(data.days.last.isToday, isTrue);
      expect(data.days.where((d) => d.isToday), hasLength(1));
    });

    test('the window reaches back to the first recorded day when older '
        'than 6 months', () {
      final data = build(entries: [entry('2025-03-01', 10)]);
      expect(data.days.first.day, '2025-03-01');
      expect(data.days.first.state, ActivityDayState.practiced);
    });

    test('entries after today are ignored', () {
      final data = build(entries: [entry(oct(12), 10)]);
      expect(data.days.last.day, oct(11));
      expect(data.practiceDays, 0);
    });

    test('cells carry state and XP; freeze days are streakFreeze', () {
      final data = build(entries: [entry(oct(9), 40), freeze(oct(10))]);
      final byDay = {for (final d in data.days) d.day: d};
      expect(byDay[oct(9)]!.state, ActivityDayState.practiced);
      expect(byDay[oct(9)]!.xpEarned, 40);
      expect(byDay[oct(10)]!.state, ActivityDayState.streakFreeze);
      expect(byDay[oct(10)]!.isStreakOnIce, isTrue);
      expect(byDay[oct(11)]!.state, ActivityDayState.none);
      expect(byDay[oct(11)]!.hasActivity, isFalse);
    });

    test('practice days count all-time practiced days, freeze days '
        'excluded', () {
      final data = build(
        entries: [
          entry('2025-01-01', 10),
          entry(oct(9), 10),
          freeze(oct(10)),
          entry(oct(11), 10),
        ],
      );
      expect(data.practiceDays, 3);
    });

    test('longest streak is all-time and counts freeze days', () {
      final data = build(
        streakCount: 1,
        lastActiveDay: oct(11),
        entries: [
          entry('2025-01-01', 10),
          freeze('2025-01-02'),
          entry('2025-01-03', 10),
          entry(oct(11), 10),
        ],
      );
      expect(data.longestStreak, 3);
      expect(data.showLongestStreakBand, isTrue);
      expect(data.days.where((d) => d.isLongestStreak).map((d) => d.day), [
        '2025-01-01',
        '2025-01-02',
        '2025-01-03',
      ]);
    });

    test('longest streak is never shown smaller than the current streak, '
        'e.g. a streak predating the recorded history', () {
      final data = build(
        streakCount: 10,
        lastActiveDay: oct(11),
        entries: [entry(oct(10), 10), entry(oct(11), 10)],
      );
      expect(data.longestStreak, 10);
      expect(data.showLongestStreakBand, isFalse);
      expect(data.days.where((d) => d.isLongestStreak), isEmpty);
    });

    test('when the current streak is the record (incl. a tie), only the '
        'current band is shown', () {
      final data = build(
        streakCount: 2,
        lastActiveDay: oct(11),
        entries: [
          entry(oct(1), 10),
          entry(oct(2), 10),
          entry(oct(10), 10),
          entry(oct(11), 10),
        ],
      );
      expect(data.longestStreak, 2);
      expect(data.showLongestStreakBand, isFalse);
      expect(data.days.where((d) => d.isCurrentStreak).map((d) => d.day), [
        oct(10),
        oct(11),
      ]);
    });

    test('a freeze inside the current run keeps the whole run in the '
        'current band, with no extra longest band on it', () {
      final data = build(
        streakCount: 6,
        lastActiveDay: oct(11),
        entries: [
          for (var d = 5; d <= 9; d++) entry(oct(d), 10),
          freeze(oct(10)),
          entry(oct(11), 10),
        ],
      );
      expect(data.days.where((d) => d.isCurrentStreak).map((d) => d.day), [
        for (var d = 5; d <= 11; d++) oct(d),
      ]);
      expect(data.showLongestStreakBand, isFalse);
      expect(data.days.where((d) => d.isLongestStreak), isEmpty);
      // Freeze days count toward the longest streak.
      expect(data.longestStreak, 7);
    });

    test('practicedToday reflects only a practiced today cell', () {
      expect(build().practicedToday, isFalse);
      expect(build(entries: [entry(oct(11), 10)]).practicedToday, isTrue);
    });

    test('carries streakFreezesAvailable through unchanged', () {
      expect(build(freezes: 3).streakFreezesAvailable, 3);
    });
  });

  group('groupIntoWeeks', () {
    test('Monday-first: Monday on row 0, Sunday on row 6, padded with '
        'nulls before the first and after the last day', () {
      // 2026-10-07 is a Wednesday, 2026-10-13 a Tuesday.
      final days = [for (var d = 7; d <= 13; d++) ActivityDay(day: oct(d))];
      final weeks = groupIntoWeeks(days);
      expect(weeks, hasLength(2));
      expect(weeks[0][0], isNull);
      expect(weeks[0][1], isNull);
      expect(weeks[0][2]!.day, oct(7));
      expect(weeks[0][6]!.day, oct(11)); // Sunday at the bottom.
      expect(weeks[1][0]!.day, oct(12)); // Monday at the top.
      expect(weeks[1][1]!.day, oct(13));
      expect(weeks[1].sublist(2), everyElement(isNull));
    });

    test('is empty for no days', () {
      expect(groupIntoWeeks(const []), isEmpty);
    });
  });

  group('computeStreakBandSegments', () {
    ActivityDay d(String day, {bool current = false, bool longest = false}) =>
        ActivityDay(
          day: day,
          isCurrentStreak: current,
          isLongestStreak: longest,
        );

    test('a run crossing Sunday -> Monday is open at the bottom of the '
        'first column and at the top of the next, closed at its real '
        'start and end', () {
      // Mon 2026-10-05 .. Wed 2026-10-14; streak Fri 09 .. Tue 13.
      final days = [
        for (var i = 5; i <= 14; i++) d(oct(i), current: i >= 9 && i <= 13),
      ];
      final segments = computeStreakBandSegments(groupIntoWeeks(days));
      expect(segments, hasLength(2));
      final first = segments[0];
      expect(first.column, 0);
      expect(first.startRow, 4);
      expect(first.endRow, 6);
      expect(first.firstDay, oct(9));
      expect(first.openTop, isFalse);
      expect(first.openBottom, isTrue);
      expect(first.daysAfter, 2);
      final second = segments[1];
      expect(second.column, 1);
      expect(second.startRow, 0);
      expect(second.endRow, 1);
      expect(second.firstDay, oct(12));
      expect(second.openTop, isTrue);
      expect(second.openBottom, isFalse);
      expect(second.daysAfter, 0);
    });

    test('a run filling a whole middle column is open at both ends', () {
      // Sun 2026-10-04 .. Mon 2026-10-12, all current.
      final days = [for (var i = 4; i <= 12; i++) d(oct(i), current: true)];
      final segments = computeStreakBandSegments(groupIntoWeeks(days));
      expect(segments, hasLength(3));
      expect(segments[1].openTop, isTrue);
      expect(segments[1].openBottom, isTrue);
      expect(segments[1].length, 7);
      expect(segments.map((s) => s.daysAfter), [8, 1, 0]);
    });

    test('a run ending on a Sunday, with the next Monday not banded, '
        'stays closed', () {
      final days = [
        d(oct(10), current: true),
        d(oct(11), current: true),
        d(oct(12)),
      ];
      final segment = computeStreakBandSegments(groupIntoWeeks(days)).single;
      expect(segment.openBottom, isFalse);
      expect(segment.openTop, isFalse);
    });

    test('a day in both runs takes the current kind', () {
      final days = [
        d(oct(5), longest: true),
        d(oct(6), longest: true),
        d(oct(7), longest: true, current: true),
        d(oct(8), current: true),
      ];
      final segments = computeStreakBandSegments(groupIntoWeeks(days));
      expect(segments, hasLength(2));
      expect(segments[0].kind, StreakBandKind.longest);
      expect(segments[0].endRow, 1);
      expect(segments[1].kind, StreakBandKind.current);
      expect(segments[1].startRow, 2);
      expect(segments[1].endRow, 3);
    });

    test('no banded days, no segments', () {
      final days = [d(oct(5)), d(oct(6))];
      expect(computeStreakBandSegments(groupIntoWeeks(days)), isEmpty);
    });
  });
}
