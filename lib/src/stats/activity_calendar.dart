// Pure windowing/stats/streak-run logic for the Streak Details screen
// (#084, reworked by #128).
//
// [ActivityCalendarData.build] is the one entry point the screen/widget
// consumes; the day-window, day-state, streak-run and week-grid math
// underneath are kept pure (no widget imports, clock-independent given an
// explicit `today`) so they're directly unit-testable — same spirit as
// #011's `StreakService.computeNext`.

import '../data/clock.dart';
import '../data/database.dart' show DailyActivityData;
import '../data/stats_repository.dart' show DailyActivitySource;

/// The calendar always reaches at least this many months back from today
/// (#128) — further back when the first recorded day is older.
const int kActivityCalendarMinWindowMonths = 6;

/// What one calendar cell shows (#128: no XP intensity shades anymore —
/// the XP amount lives in the day popup instead).
enum ActivityDayState {
  /// An ordinary lesson-completion `daily_activity` row.
  practiced,

  /// A row written by #087's streak-freeze auto-apply (`source:
  /// streakOnIce`).
  streakFreeze,

  /// No `daily_activity` row for that day.
  none,
}

/// Rendering input for one calendar cell.
class ActivityDay {
  final String day;
  final int xpEarned;
  final ActivityDayState state;
  final bool isToday;
  final bool isCurrentStreak;
  final bool isLongestStreak;

  const ActivityDay({
    required this.day,
    this.xpEarned = 0,
    this.state = ActivityDayState.none,
    this.isToday = false,
    this.isCurrentStreak = false,
    this.isLongestStreak = false,
  });

  /// Whether a `daily_activity` row exists for this day (practiced or
  /// saved by a streak freeze).
  bool get hasActivity => state != ActivityDayState.none;

  /// Whether this day was saved by a #087 streak freeze.
  bool get isStreakOnIce => state == ActivityDayState.streakFreeze;
}

/// Everything the Streak Details screen shows: one [ActivityDay] per day
/// in the window (oldest-first, today last) plus the hero/stat numbers.
class ActivityCalendarData {
  final List<ActivityDay> days;

  /// `profile.streakCount`: the current streak, freeze days included (#132).
  final int currentStreakCount;

  /// All-time longest streak (freeze days count), never below
  /// [currentStreakCount] — "all-time" meaning everything recorded since
  /// #084 started writing `daily_activity`.
  final int longestStreak;

  /// All-time number of days actually practiced — freeze days excluded.
  final int practiceDays;

  /// Whether the longest-streak band is drawn — only when the record is a
  /// different (strictly longer, non-overlapping) run than the current
  /// streak.
  final bool showLongestStreakBand;

  /// The profile's current `streakFreezesAvailable` balance (#087).
  final int streakFreezesAvailable;

  const ActivityCalendarData({
    required this.days,
    required this.currentStreakCount,
    required this.longestStreak,
    required this.practiceDays,
    required this.showLongestStreakBand,
    this.streakFreezesAvailable = 0,
  });

  /// Whether today's cell is a practiced day — drives the hero's line and
  /// the today pulse.
  bool get practicedToday =>
      days.isNotEmpty && days.last.state == ActivityDayState.practiced;

  factory ActivityCalendarData.build({
    required DateTime today,
    required int streakCount,
    required String? lastActiveDay,
    required List<DailyActivityData> entries,
    int streakFreezesAvailable = 0,
  }) {
    final todayString = toLocalDayString(today);
    final pastEntries = entries.where((e) => e.day.compareTo(todayString) <= 0);
    final byDay = {for (final e in pastEntries) e.day: e};
    final windowDays = buildWindowDays(
      today: today,
      firstRecordedDay: byDay.isEmpty ? null : byDay.keys.reduce(_minDay),
    );

    final currentSet = currentStreakDays(
      streakCount: streakCount,
      lastActiveDay: lastActiveDay,
    );
    final longestSet = longestRun(windowDays, byDay.keys.toSet());
    // A different run only: longer than the current one *and* not
    // overlapping it (an overlap means it is the current run itself).
    final showLongestBand =
        longestSet.length > currentSet.length &&
        longestSet.intersection(currentSet).isEmpty;

    final days = windowDays.map((d) {
      final entry = byDay[d];
      return ActivityDay(
        day: d,
        xpEarned: entry?.xpEarned ?? 0,
        state: stateFor(entry),
        isToday: d == todayString,
        isCurrentStreak: currentSet.contains(d),
        isLongestStreak: showLongestBand && longestSet.contains(d),
      );
    }).toList();

    return ActivityCalendarData(
      days: days,
      currentStreakCount: streakCount,
      longestStreak: longestSet.length > currentSet.length
          ? longestSet.length
          : currentSet.length,
      practiceDays: days
          .where((d) => d.state == ActivityDayState.practiced)
          .length,
      showLongestStreakBand: showLongestBand,
      streakFreezesAvailable: streakFreezesAvailable,
    );
  }
}

String _minDay(String a, String b) => a.compareTo(b) <= 0 ? a : b;

/// Every local day from the window start up to and including [today],
/// ascending (oldest first). The window starts [months] months before
/// [today], or at [firstRecordedDay] when that is older (#128), so the
/// whole recorded history stays reachable. Calendar-field subtraction (not
/// `Duration`), matching `StreakService.computeNext`'s own day math, so
/// month/year rollovers and DST don't produce an off-by-one day.
List<String> buildWindowDays({
  required DateTime today,
  String? firstRecordedDay,
  int months = kActivityCalendarMinWindowMonths,
}) {
  var start = DateTime(today.year, today.month - months, today.day);
  final DateTime? first = firstRecordedDay == null
      ? null
      : parseDayString(firstRecordedDay);
  if (first != null && first.isBefore(start)) start = first;
  final end = DateTime(today.year, today.month, today.day);
  final days = <String>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    days.add(toLocalDayString(cursor));
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return days;
}

/// The cell state for a day's `daily_activity` [entry] (`null` = no row).
ActivityDayState stateFor(DailyActivityData? entry) {
  if (entry == null) return ActivityDayState.none;
  return entry.activitySource == DailyActivitySource.streakOnIce.name
      ? ActivityDayState.streakFreeze
      : ActivityDayState.practiced;
}

/// The current streak's run of consecutive local days ending at
/// [lastActiveDay], going backwards, per `profile.streakCount`/
/// `lastActiveDay` (#011): exactly [streakCount] days — a #087 freeze day
/// counts toward the streak (#132), so the band and the number always
/// agree. Empty when there's no streak yet. May extend before the
/// calendar's window when the streak predates #084's `daily_activity`
/// recording — callers that render the window intersect this against their
/// own day set.
Set<String> currentStreakDays({
  required int streakCount,
  required String? lastActiveDay,
}) {
  if (streakCount <= 0 || lastActiveDay == null) return {};
  final anchor = parseDayString(lastActiveDay);
  if (anchor == null) return {};
  return {
    for (var i = 0; i < streakCount; i++)
      toLocalDayString(DateTime(anchor.year, anchor.month, anchor.day - i)),
  };
}

/// The longest run of consecutive days in [daysAscending] that are members
/// of [activeDays] (practiced or frozen — freeze days count toward a
/// streak). Ties prefer the most recent run.
Set<String> longestRun(List<String> daysAscending, Set<String> activeDays) {
  var bestStart = 0;
  var bestLength = 0;
  var runStart = 0;
  for (var i = 0; i < daysAscending.length; i++) {
    if (!activeDays.contains(daysAscending[i])) {
      runStart = i + 1;
      continue;
    }
    final runLength = i - runStart + 1;
    if (runLength >= bestLength) {
      bestStart = runStart;
      bestLength = runLength;
    }
  }
  return daysAscending.sublist(bestStart, bestStart + bestLength).toSet();
}

/// Groups [days] (ascending) into Monday-first week columns of exactly 7
/// cells (#128: Monday top, Sunday bottom, in every locale), padding the
/// first and last (partial) weeks with `null`s so every day lands on its
/// correct weekday row.
List<List<ActivityDay?>> groupIntoWeeks(List<ActivityDay> days) {
  if (days.isEmpty) return [];
  final weeks = <List<ActivityDay?>>[];
  var currentWeek = <ActivityDay?>[];
  // DateTime.weekday: Monday=1..Sunday=7 -> row 0..6.
  final firstRow = parseDayString(days.first.day)!.weekday - 1;
  currentWeek.addAll(List<ActivityDay?>.filled(firstRow, null));
  for (final day in days) {
    currentWeek.add(day);
    if (currentWeek.length == 7) {
      weeks.add(currentWeek);
      currentWeek = <ActivityDay?>[];
    }
  }
  if (currentWeek.isNotEmpty) {
    currentWeek.addAll(List<ActivityDay?>.filled(7 - currentWeek.length, null));
    weeks.add(currentWeek);
  }
  return weeks;
}

/// Which streak a band belongs to.
enum StreakBandKind { current, longest }

/// One piece of a streak band: the contiguous cells `[startRow, endRow]`
/// (inclusive) of week-column [column]. A run crossing a Sunday -> Monday
/// break splits into one segment per column; the end at the break is
/// [openBottom] (first column) / [openTop] (next column) instead of a
/// rounded cap, so the band reads as "continues there" (#128).
class StreakBandSegment {
  final int column;
  final int startRow;
  final int endRow;
  final StreakBandKind kind;
  final bool openTop;
  final bool openBottom;
  final String firstDay;

  /// How many same-kind days come *after* this segment's last day — the
  /// band draws in backwards from the run's end, so this is how far into
  /// that draw-in the segment starts growing.
  final int daysAfter;

  const StreakBandSegment({
    required this.column,
    required this.startRow,
    required this.endRow,
    required this.kind,
    required this.openTop,
    required this.openBottom,
    required this.firstDay,
    required this.daysAfter,
  });

  int get length => endRow - startRow + 1;
}

/// The band kind a day's cell belongs to — current-streak takes precedence
/// over longest (a day in both shows the current color). `null` for an
/// unbanded or padding (`null`) day.
StreakBandKind? bandKindOf(ActivityDay? day) {
  if (day == null) return null;
  if (day.isCurrentStreak) return StreakBandKind.current;
  if (day.isLongestStreak) return StreakBandKind.longest;
  return null;
}

/// One [StreakBandSegment] per maximal run of same-kind banded cells within
/// a single week-column, oldest first.
List<StreakBandSegment> computeStreakBandSegments(
  List<List<ActivityDay?>> weeks,
) {
  final totals = <StreakBandKind, int>{};
  for (final week in weeks) {
    for (final day in week) {
      final kind = bandKindOf(day);
      if (kind != null) totals[kind] = (totals[kind] ?? 0) + 1;
    }
  }
  final seen = <StreakBandKind, int>{};
  final segments = <StreakBandSegment>[];
  for (var col = 0; col < weeks.length; col++) {
    final week = weeks[col];
    var row = 0;
    while (row < week.length) {
      final kind = bandKindOf(week[row]);
      if (kind == null) {
        row++;
        continue;
      }
      var end = row;
      while (end + 1 < week.length && bandKindOf(week[end + 1]) == kind) {
        end++;
      }
      seen[kind] = (seen[kind] ?? 0) + (end - row + 1);
      segments.add(
        StreakBandSegment(
          column: col,
          startRow: row,
          endRow: end,
          kind: kind,
          openTop: row == 0 && col > 0 && bandKindOf(weeks[col - 1][6]) == kind,
          openBottom:
              end == 6 &&
              col + 1 < weeks.length &&
              bandKindOf(weeks[col + 1][0]) == kind,
          firstDay: week[row]!.day,
          daysAfter: totals[kind]! - seen[kind]!,
        ),
      );
      row = end + 1;
    }
  }
  return segments;
}
