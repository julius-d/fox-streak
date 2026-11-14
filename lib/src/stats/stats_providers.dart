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

/// The Streak Details screen's data (#084, #128): the live profile's
/// streak fields combined with every recorded `daily_activity` row (the
/// all-time stats and the scrollable history both need all of them),
/// re-derived whenever [profileProvider] emits.
final activityCalendarProvider =
    FutureProvider.autoDispose<ActivityCalendarData>((ref) async {
      final statsRepo = ref.watch(statsRepositoryProvider);
      final now = ref.watch(systemClockProvider).now();
      // Started concurrently (not sequentially awaited) — the profile read
      // and the daily_activity query are independent.
      final profileFuture = ref.watch(profileProvider.future);
      final entriesFuture = statsRepo.getAllDailyActivity();
      final profile = await profileFuture;
      final entries = await entriesFuture;
      return ActivityCalendarData.build(
        today: now,
        streakCount: profile.streakCount,
        lastActiveDay: profile.lastActiveDay,
        entries: entries,
        streakFreezesAvailable: profile.streakFreezesAvailable,
      );
    });
