// Streak day-algorithm + the sole writer wiring for streak_count/
// last_active_day (issue #011).
//
// [StreakService.computeNext] is the pure day algorithm (unit-tested
// directly, no DB); [StreakService.recordActivity] is the only thing that
// ever calls [StatsRepository.setStreak].

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clock.dart';
import '../data/providers.dart';
import '../data/stats_repository.dart';

/// Streak values (today's `streak_count`) that count as a milestone, i.e.
/// the `on-fire` mascot moment. Fixed v1 set, no shop/freeze.
const Set<int> kStreakMilestones = {3, 7, 14, 30, 50, 100};

/// Sole writer of `streak_count`/`last_active_day`
/// (via [StatsRepository.setStreak]).
class StreakService {
  final StatsRepository _statsRepo;
  final Clock _clock;

  StreakService(this._statsRepo, [Clock? clock])
    : _clock = clock ?? SystemClock();

  /// Whether [streakCount] is a milestone value (`on-fire` moment).
  static bool isMilestone(int streakCount) =>
      kStreakMilestones.contains(streakCount);

  /// Pure day algorithm: given [currentStreak]/[lastActiveDay] (the
  /// profile's prior values) and [now], returns the new streak state.
  ///
  /// - no prior activity (`lastActiveDay == null`) -> streak becomes 1
  /// - same local day as last activity -> unchanged, `isNewDay: false`
  /// - exactly the next local day -> streak + 1
  /// - any other gap (>=2 days, or a clock going backwards) -> resets to 1
  static StreakUpdate computeNext({
    required DateTime now,
    required int currentStreak,
    required String? lastActiveDay,
  }) {
    final today = toLocalDayString(now);
    if (lastActiveDay == null) {
      return StreakUpdate(streakCount: 1, lastActiveDay: today, isNewDay: true);
    }
    if (lastActiveDay == today) {
      return StreakUpdate(
        streakCount: currentStreak,
        lastActiveDay: today,
        isNewDay: false,
      );
    }
    // Calendar-field subtraction, not `now.subtract(Duration(days: 1))`:
    // that does absolute-time arithmetic and lands on the wrong local date
    // across a DST transition (a "day" isn't always 24 wall-clock hours).
    final yesterday = toLocalDayString(
      DateTime(now.year, now.month, now.day - 1),
    );
    if (lastActiveDay == yesterday) {
      return StreakUpdate(
        streakCount: currentStreak + 1,
        lastActiveDay: today,
        isNewDay: true,
      );
    }
    return StreakUpdate(streakCount: 1, lastActiveDay: today, isNewDay: true);
  }

  /// Applies today's activity exactly once; the caller (`LessonController`)
  /// guards against repeat calls via #010's shared `xpApplied` gate.
  ///
  /// Reads the current profile, runs [computeNext] against the clock's
  /// current time, and persists the result via [StatsRepository.setStreak].
  Future<StreakUpdate> recordActivity() async {
    final profile = await _statsRepo.getProfile();
    final update = computeNext(
      now: _clock.now(),
      currentStreak: profile.streakCount,
      lastActiveDay: profile.lastActiveDay,
    );
    await _statsRepo.setStreak(
      streakCount: update.streakCount,
      lastActiveDay: update.lastActiveDay,
    );
    return update;
  }
}

/// Result of the day algorithm / [StreakService.recordActivity]: the
/// resulting `streak_count`/`last_active_day` and whether this call actually
/// advanced the streak (vs. a same-day replay).
class StreakUpdate {
  final int streakCount;
  final String lastActiveDay;
  final bool isNewDay;

  const StreakUpdate({
    required this.streakCount,
    required this.lastActiveDay,
    required this.isNewDay,
  });
}

final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(
    ref.watch(statsRepositoryProvider),
    ref.watch(systemClockProvider),
  );
});
