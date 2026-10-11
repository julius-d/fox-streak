// Locale-aware display formatting for ISO date answers (issue #004).
//
// The editor stores dates as strict ISO `YYYY-MM-DD` (see `validation.dart`
// `isValidDateAnswer`) but shows them locale-aware: DE `TT.MM.JJJJ`
// (`14.05.1985`), EN `MM/DD/YYYY` (`05/14/1985`). Owned by #004, reused by
// #009 for grading feedback — keep this pure (no widgets, no Riverpod) so
// both surfaces share one implementation.

import 'package:flutter/widgets.dart';

import '../data/clock.dart';

/// Formats an ISO `YYYY-MM-DD` day string for display in [locale].
///
/// - German (`de`): `DD.MM.YYYY` (e.g. `14.05.1985`).
/// - Anything else: `MM/DD/YYYY` (e.g. `05/14/1985`).
///
/// Returns [isoDay] trimmed and unchanged when it is not a valid calendar
/// date, so callers can safely pass through unchecked input.
String formatDateForDisplay(String isoDay, Locale locale) {
  final trimmed = isoDay.trim();
  final parsed = parseDayString(trimmed);
  if (parsed == null) return trimmed;
  final dd = parsed.day.toString().padLeft(2, '0');
  final mm = parsed.month.toString().padLeft(2, '0');
  final yyyy = parsed.year.toString().padLeft(4, '0');
  if (locale.languageCode == 'de') {
    return '$dd.$mm.$yyyy';
  }
  return '$mm/$dd/$yyyy';
}
