// Home's greeting text (issue #012, night bucket #060), extended by #061
// with two layers on top of the plain time-of-day greeting:
//
// 1. Fixed-date holiday greetings (non-movable calendar dates) always win
//    on their date.
// 2. A funny/playful rotation, picked deterministically per local calendar
//    day (not per rebuild) when no holiday matches.
//
// Precedence: holiday > funny rotation > plain time-of-day. Holiday/funny
// copy is deliberately generic (no `displayName` personalization) — only
// the plain time-of-day greeting uses the name.

import 'dart:math';

import '../../l10n/app_localizations.dart';

/// Builds Home's greeting for `now`, applying holiday > funny-rotation >
/// plain time-of-day precedence. Takes the injected [Clock]'s `now()`
/// result rather than reading `DateTime.now()` directly, so it stays
/// deterministic and testable.
String greetingText(AppLocalizations l10n, DateTime now, String? displayName) {
  return _holidayGreeting(l10n, now) ??
      _funnyGreeting(l10n, now) ??
      _timeOfDayGreeting(l10n, now, displayName);
}

/// Generic (no display name) or named time-of-day greeting.
String _timeOfDayGreeting(
  AppLocalizations l10n,
  DateTime now,
  String? displayName,
) {
  final String? name = displayName?.trim();
  final bool hasName = name != null && name.isNotEmpty;
  if (now.hour < 5) {
    return hasName ? l10n.homeGreetingNightNamed(name) : l10n.homeGreetingNight;
  }
  if (now.hour < 12) {
    return hasName
        ? l10n.homeGreetingMorningNamed(name)
        : l10n.homeGreetingMorning;
  }
  if (now.hour < 18) {
    return hasName
        ? l10n.homeGreetingAfternoonNamed(name)
        : l10n.homeGreetingAfternoon;
  }
  return hasName
      ? l10n.homeGreetingEveningNamed(name)
      : l10n.homeGreetingEvening;
}

/// Fixed-date holiday table: (month, day) -> arb getter. Deliberately
/// movable-holiday free (Easter, Thanksgiving, ...) to avoid a date-math
/// dependency (see issue #061's "Out of scope").
final Map<(int, int), String Function(AppLocalizations)> _holidays = {
  (1, 1): (l10n) => l10n.homeGreetingNewYear,
  (4, 1): (l10n) => l10n.homeGreetingAprilFools,
  (10, 31): (l10n) => l10n.homeGreetingHalloween,
  (12, 24): (l10n) => l10n.homeGreetingChristmasEve,
  (12, 25): (l10n) => l10n.homeGreetingChristmasDay,
};

/// The holiday override for `now`'s calendar date, or `null` on an
/// ordinary day. Matches regardless of hour.
String? _holidayGreeting(AppLocalizations l10n, DateTime now) {
  final greeting = _holidays[(now.month, now.day)];
  return greeting?.call(l10n);
}

/// The pool of playful rotation variants, in table order (index 0 first).
final List<String Function(AppLocalizations)> _funnyPool = [
  (l10n) => l10n.homeGreetingFunny1,
  (l10n) => l10n.homeGreetingFunny2,
  (l10n) => l10n.homeGreetingFunny3,
  (l10n) => l10n.homeGreetingFunny4,
  (l10n) => l10n.homeGreetingFunny5,
  (l10n) => l10n.homeGreetingFunny6,
  (l10n) => l10n.homeGreetingFunny7,
  (l10n) => l10n.homeGreetingFunny8,
];

/// Roughly 1 in this many non-holiday days shows a funny variant instead
/// of the plain time-of-day greeting (not load-bearing, tuned here).
const int _funnyRotationOdds = 5;

/// The funny rotation's pick for `now`'s local calendar day, or `null`
/// when that day isn't selected (falls back to the plain greeting).
/// Deterministic per day: seeded from `now`'s local date components (same
/// [toLocalDayString] convention as streak/#059), not per rebuild — so the
/// pick doesn't change every time Home rebuilds within the same day.
String? _funnyGreeting(AppLocalizations l10n, DateTime now) {
  final rng = Random(_daySeed(now));
  final bool selected = rng.nextInt(_funnyRotationOdds) == 0;
  if (!selected) return null;
  final int index = rng.nextInt(_funnyPool.length);
  return _funnyPool[index](l10n);
}

/// A deterministic integer seed for `now`'s local calendar day, stable
/// across runs (unlike `String.hashCode`, which Dart does not guarantee
/// stable across VM/web/isolate boundaries).
int _daySeed(DateTime now) => now.year * 10000 + now.month * 100 + now.day;
