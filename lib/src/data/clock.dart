// Clock abstraction.
//
// All "now" access in the data layer goes through [Clock] so tests can
// inject a fake and [#011] streak logic can reuse the day helpers.
//
// The clock always returns *local* time ([DateTime.now]).
abstract class Clock {
  DateTime now();

  /// Current local calendar day as `YYYY-MM-DD`.
  String todayDayString() => toLocalDayString(now());
}

/// Production clock returning [DateTime.now].
class SystemClock extends Clock {
  @override
  DateTime now() => DateTime.now();
}

/// Formats [dt] as a local `YYYY-MM-DD` day string.
String toLocalDayString(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses a strict `YYYY-MM-DD` day string into a local midnight [DateTime].
///
/// Returns `null` when the string is not a valid calendar date
/// (e.g. `2021-02-30` or `not-a-date`).
DateTime? parseDayString(String s) {
  if (!_dayPattern.hasMatch(s)) return null;
  try {
    final parts = s.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    final dt = DateTime(y, m, d);
    // DateTime normalises overflows (e.g. Feb 30 -> Mar 2); reject those.
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  } on FormatException {
    return null;
  }
}

final RegExp _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
