// Riverpod wiring for profile stats reads (issue #012).
//
// Thin wrappers over `StatsRepository` (#002) — Home watches these; no
// direct DB use in widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import 'activity_calendar.dart';

/// Live profile row (defaults until the first write), for Home's greeting,
/// streak badge, level-progress bar, and goal ring.
final profileProvider = StreamProvider<ProfileStat>((ref) {
  return ref.watch(statsRepositoryProvider).watchProfile();
});

/// The most recently practiced set's id, or `null` if none exists yet
/// (#012's Home "Continue" button). Not a stream (no cheap single-row
/// watch over a derived `attempts` ⋈ `items` query); callers invalidate
/// this provider after navigating back from a lesson/library trip.
final lastPracticedSetIdProvider = FutureProvider.autoDispose<int?>((ref) {
  return ref.watch(statsRepositoryProvider).getLastPracticedSetId();
});

/// The #084 Streak Details screen's calendar data: the live profile's
/// streak/goal fields combined with the `daily_activity` rows covering the
/// ~6-month window, re-derived whenever [profileProvider] emits.
final activityCalendarProvider =
    FutureProvider.autoDispose<ActivityCalendarData>((ref) async {
      final statsRepo = ref.watch(statsRepositoryProvider);
      final now = ref.watch(systemClockProvider).now();
      final windowDays = buildWindowDays(today: now);
      // Started concurrently (not sequentially awaited) — the profile read
      // and the daily_activity range query are independent.
      final profileFuture = ref.watch(profileProvider.future);
      final entriesFuture = statsRepo.getDailyActivityRange(
        fromDay: windowDays.first,
        toDay: windowDays.last,
      );
      final profile = await profileFuture;
      final entries = await entriesFuture;
      return ActivityCalendarData.build(
        today: now,
        streakCount: profile.streakCount,
        lastActiveDay: profile.lastActiveDay,
        dailyGoalXp: profile.dailyGoalXp,
        entries: entries,
      );
    });
