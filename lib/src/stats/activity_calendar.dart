// Pure windowing/bucket/streak-run logic for the #084 Streak Details
// calendar.
//
// [ActivityCalendarData.build] is the one entry point the screen/widget
// consumes; the day-window, color-bucket and streak-run math underneath are
// kept pure (no widget imports, clock-independent given an explicit `today`)
// so they're directly unit-testable — same spirit as #011's
// `StreakService.computeNext`.

import '../data/clock.dart';
import '../data/database.dart' show DailyActivityData;

/// How many months back the calendar window looks from today.
const int kActivityCalendarWindowMonths = 6;

/// Color-bucket tier for a single day's cell, driving which
/// `FoxSemanticColors.flame` alpha the #084 calendar paints it with.
enum ActivityLevel { none, low, medium, high }

/// Rendering input for one calendar cell.
class ActivityDay {
  final String day;
  final int xpEarned;
  final bool hasActivity;
  final ActivityLevel level;
  final bool isCurrentStreak;
  final bool isLongestStreak;

  const ActivityDay({
    required this.day,
    required this.xpEarned,
    required this.hasActivity,
    required this.level,
    required this.isCurrentStreak,
    required this.isLongestStreak,
  });
}

/// The full calendar: one [ActivityDay] per day in the window
/// (oldest-first, today last), plus the two streak headline numbers.
class ActivityCalendarData {
  final List<ActivityDay> days;
  final int currentStreakCount;
  final int longestStreakInWindow;

  /// Whether the longest-in-window run is a different set of days than the
  /// (visible portion of the) current streak — when `false`, the two
  /// highlights would be identical, so the screen shows one headline
  /// instead of highlighting the same days twice.
  final bool longestDiffersFromCurrent;

  const ActivityCalendarData({
    required this.days,
    required this.currentStreakCount,
    required this.longestStreakInWindow,
    required this.longestDiffersFromCurrent,
  });

  factory ActivityCalendarData.build({
    required DateTime today,
    required int streakCount,
    required String? lastActiveDay,
    required int dailyGoalXp,
    required List<DailyActivityData> entries,
  }) {
    final windowDays = buildWindowDays(today: today);
    final windowDaySet = windowDays.toSet();
    final byDay = {for (final e in entries) e.day: e};

    final currentSet = currentStreakDays(
      streakCount: streakCount,
      lastActiveDay: lastActiveDay,
    );
    final activeDaysInWindow = windowDays
        .where((d) => byDay.containsKey(d))
        .toSet();
    final longestSet = longestRunInWindow(windowDays, activeDaysInWindow);
    final currentVisible = currentSet.intersection(windowDaySet);
    final longestDiffers = !_setEquals(longestSet, currentVisible);

    final days = windowDays.map((d) {
      final entry = byDay[d];
      final hasActivity = entry != null;
      final xp = entry?.xpEarned ?? 0;
      return ActivityDay(
        day: d,
        xpEarned: xp,
        hasActivity: hasActivity,
        level: bucketFor(
          hasActivity: hasActivity,
          xpEarned: xp,
          dailyGoalXp: dailyGoalXp,
        ),
        isCurrentStreak: currentSet.contains(d),
        isLongestStreak: longestDiffers && longestSet.contains(d),
      );
    }).toList();

    return ActivityCalendarData(
      days: days,
      currentStreakCount: streakCount,
      longestStreakInWindow: longestSet.length,
      longestDiffersFromCurrent: longestDiffers,
    );
  }
}

/// Every local day from [months] months before [today] up to and including
/// [today], ascending (oldest first) — the calendar's fixed ~6-month
/// window. Calendar-field subtraction (not `Duration`), matching
/// `StreakService.computeNext`'s own day math, so month/year rollovers and
/// DST don't produce an off-by-one day.
List<String> buildWindowDays({
  required DateTime today,
  int months = kActivityCalendarWindowMonths,
}) {
  final start = DateTime(today.year, today.month - months, today.day);
  final end = DateTime(today.year, today.month, today.day);
  final days = <String>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    days.add(toLocalDayString(cursor));
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return days;
}

/// The color bucket for a day with [hasActivity] (a `daily_activity` row
/// exists) earning [xpEarned] against [dailyGoalXp].
///
/// A day without a row is [ActivityLevel.none]. A day *with* a row —
/// including a future `streakOnIce` day at `xpEarned: 0` — always renders
/// as at least [ActivityLevel.low], never [ActivityLevel.none]. Exact
/// thresholds (`>=100%` / `50-99%` / below) are a UI-polish detail, not a
/// contract.
ActivityLevel bucketFor({
  required bool hasActivity,
  required int xpEarned,
  required int dailyGoalXp,
}) {
  if (!hasActivity) return ActivityLevel.none;
  if (dailyGoalXp <= 0) {
    return xpEarned > 0 ? ActivityLevel.high : ActivityLevel.low;
  }
  final ratio = xpEarned / dailyGoalXp;
  if (ratio >= 1.0) return ActivityLevel.high;
  if (ratio >= 0.5) return ActivityLevel.medium;
  return ActivityLevel.low;
}

/// The exact [streakCount] consecutive local days ending at
/// [lastActiveDay], going backwards — the current streak's run, per
/// `profile.streakCount`/`lastActiveDay` (#011). Empty when there's no
/// streak yet. May extend before the calendar's window on a streak longer
/// than ~6 months (accepted v1 edge case, see issue #084) — callers that
/// render a fixed window intersect this against their own day set.
Set<String> currentStreakDays({
  required int streakCount,
  required String? lastActiveDay,
}) {
  if (streakCount <= 0 || lastActiveDay == null) return {};
  final anchor = parseDayString(lastActiveDay);
  if (anchor == null) return {};
  final days = <String>{};
  var cursor = anchor;
  for (var i = 0; i < streakCount; i++) {
    days.add(toLocalDayString(cursor));
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return days;
}

/// The longest run of consecutive days in [windowDaysAscending] that are
/// members of [activeDays] — derived purely from the visible window, not a
/// stored lifetime max (issue #084). Ties prefer the most recent run.
Set<String> longestRunInWindow(
  List<String> windowDaysAscending,
  Set<String> activeDays,
) {
  List<String> best = const [];
  List<String> current = [];
  for (final day in windowDaysAscending) {
    if (activeDays.contains(day)) {
      current = [...current, day];
      if (current.length >= best.length) best = current;
    } else {
      current = [];
    }
  }
  return best.toSet();
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
