// App-launch-only "streak on ice" auto-apply (issue #087).
//
// If exactly one local day was missed (`lastActiveDay` is exactly 2 days
// before today) and at least one streak freeze is available,
// [StreakFreezeService.checkAndApplyOnLaunch] consumes one to bridge the
// gap — writing a `daily_activity` row for the missed day (`source:
// streakOnIce`, 0 XP) and advancing `lastActiveDay` to that day, so #011's
// `StreakService.computeNext` sees a normal one-day gap (not a reset) the
// next time the user completes a lesson. `streakCount` itself is left
// untouched: this path only repairs `lastActiveDay`, it doesn't advance the
// streak by itself — this is a new, explicit code path that runs *before*
// `computeNext` would otherwise see (and reset) the gap, not a change to
// that pure algorithm itself.
//
// A gap of 2+ full missed days is explicitly out of scope — the streak
// resets to 1 as before, and no freeze is spent.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clock.dart';
import '../data/providers.dart';
import '../data/stats_repository.dart';

/// Sole writer of the app-launch streak-freeze-consumption path (the
/// wheel-of-fortune's own +1 win lives in `PetService`); both call
/// [StatsRepository.addStreakFreezes].
class StreakFreezeService {
  final StatsRepository _statsRepo;
  final Clock _clock;

  StreakFreezeService(this._statsRepo, [Clock? clock])
    : _clock = clock ?? SystemClock();

  /// Checks eligibility and applies the freeze if eligible, returning
  /// whether it did. Sole caller: [streakFreezeAutoApplyProvider], which
  /// runs this exactly once per app session.
  Future<bool> checkAndApplyOnLaunch() async {
    final profile = await _statsRepo.getProfile();
    final lastActiveDay = profile.lastActiveDay;
    if (lastActiveDay == null || profile.streakFreezesAvailable <= 0) {
      return false;
    }

    final now = _clock.now();
    // Calendar-field subtraction, matching `StreakService.computeNext`'s
    // own day math, so month/year rollovers and DST don't produce an
    // off-by-one day.
    final twoDaysAgo = toLocalDayString(
      DateTime(now.year, now.month, now.day - 2),
    );
    if (lastActiveDay != twoDaysAgo) return false;

    final missedDay = toLocalDayString(
      DateTime(now.year, now.month, now.day - 1),
    );
    await _statsRepo.transaction(() async {
      await _statsRepo.addStreakFreezes(-1);
      await _statsRepo.recordDailyActivity(
        day: missedDay,
        xpDelta: 0,
        source: DailyActivitySource.streakOnIce,
      );
      await _statsRepo.setStreak(
        streakCount: profile.streakCount,
        lastActiveDay: missedDay,
      );
    });
    return true;
  }
}

final streakFreezeServiceProvider = Provider<StreakFreezeService>((ref) {
  return StreakFreezeService(
    ref.watch(statsRepositoryProvider),
    ref.watch(systemClockProvider),
  );
});

/// Runs [StreakFreezeService.checkAndApplyOnLaunch] exactly once per app
/// session — deliberately `ref.read`s (not watches) its dependencies so a
/// later streak/profile write never re-triggers it. Home watches this
/// provider on app launch, before the user does anything else; resolving
/// to `true` drives the one-time "streak saved" banner.
final streakFreezeAutoApplyProvider = FutureProvider<bool>((ref) async {
  return ref.read(streakFreezeServiceProvider).checkAndApplyOnLaunch();
});
