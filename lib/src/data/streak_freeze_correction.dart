// One-time streak correction for the v18 migration (issue #132).
//
// Since #132 a day saved by a streak freeze counts toward `streak_count`.
// Under #087's old rule a freeze kept the number unchanged, so a streak that
// already bridged a freeze day is one day short per freeze. The migration
// adds those recorded freeze days back once; days before `daily_activity`
// was recorded (#084) carry no freeze rows and are left as they are.

import 'clock.dart';

/// [streakCount] counted the old way (practiced days only, ending at
/// [lastActiveDay]) plus every [freezeDays] day bridged inside that run.
///
/// Walks back from [lastActiveDay]: a freeze day extends the run without
/// using up one of the [streakCount] practiced days, so the result is the
/// run's full length, freeze days included.
int streakCountIncludingFreezeDays({
  required int streakCount,
  required String? lastActiveDay,
  required Set<String> freezeDays,
}) {
  if (streakCount <= 0 || lastActiveDay == null) return streakCount;
  final DateTime? anchor = parseDayString(lastActiveDay);
  if (anchor == null) return streakCount;
  var length = 0;
  var remaining = streakCount;
  var cursor = anchor;
  while (remaining > 0) {
    length++;
    if (!freezeDays.contains(toLocalDayString(cursor))) remaining--;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return length;
}
