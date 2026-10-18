// Lootbox-trigger algorithm + the sole writer wiring for
// `profileStats.equippedMascotId`/`lessonsCompletedToday`/
// `lessonsCompletedDay` and the `owned_mascots` table (issue #059).
//
// [MascotService.recordLessonCompletion] is the only thing that ever calls
// [MascotRepository.addOwnedMascot] / [StatsRepository.setMascotLessonCounter];
// [MascotService.equip] is the only thing that ever calls
// [StatsRepository.setEquippedMascot].
//
// The random-reward pool additionally excludes any seasonal mascot outside
// its fixed window (issue #063) — equipping an already-owned seasonal
// mascot stays unrestricted year-round, so [equip] itself needs no change.
//
// v#064: the pool is every time-eligible catalog entry regardless of
// ownership — duplicates are possible and increment `OwnedMascots.count`
// instead of being filtered out, so the lootbox always has a mascot
// available (barring the defensive zero-time-eligible-entries edge case).

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clock.dart';
import '../data/mascot_repository.dart';
import '../data/providers.dart';
import '../data/stats_repository.dart';
import '../mascot/mascot_catalog.dart';

/// Sole writer of the mascot-collection columns/table (via
/// [StatsRepository.setEquippedMascot]/[StatsRepository.setMascotLessonCounter]/
/// [MascotRepository.addOwnedMascot]).
class MascotService {
  final StatsRepository _statsRepo;
  final MascotRepository _mascotRepo;
  final Clock _clock;
  final Future<List<MascotEntry>> Function() _loadCatalog;

  MascotService(
    this._statsRepo,
    this._mascotRepo, [
    Clock? clock,
    Future<List<MascotEntry>> Function()? loadCatalog,
  ]) : _clock = clock ?? SystemClock(),
       _loadCatalog = loadCatalog ?? MascotCatalog.load;

  /// Called from the same lesson-completion call site that feeds #010's XP
  /// and #011's streak writes (`LessonController._completeLesson`).
  ///
  /// Bumps the day-scoped `lessonsCompletedToday` counter, resetting it to 1
  /// on a new local day (mirroring `todayXp`'s own day-scoped reset). On the
  /// count reaching exactly 2, picks a catalog entry uniformly at random
  /// from every time-eligible mascot (owned or not — issue #064) and
  /// persists the win.
  ///
  /// Also returns the profile's `equippedMascotId` as of this same
  /// [StatsRepository.getProfile] read, so the caller (which needs it for
  /// the result screen's celebration either way) doesn't have to re-query
  /// the same row a second time right after this call returns.
  Future<({MascotEntry? wonMascot, String equippedMascotId})>
  recordLessonCompletion({Random? random}) async {
    final profile = await _statsRepo.getProfile();
    final equippedMascotId = profile.equippedMascotId;
    final today = toLocalDayString(_clock.now());
    final sameDay = profile.lessonsCompletedDay == today;
    final newCount = sameDay ? profile.lessonsCompletedToday + 1 : 1;
    await _statsRepo.setMascotLessonCounter(count: newCount, day: today);
    if (newCount != 2) {
      return (wonMascot: null, equippedMascotId: equippedMascotId);
    }

    final catalog = await _loadCatalog();
    final now = _clock.now();
    final pool = catalog
        .where((entry) => isMascotInSeason(entry.id, now))
        .toList();
    if (pool.isEmpty) {
      return (wonMascot: null, equippedMascotId: equippedMascotId);
    }

    final reward = pool[(random ?? Random()).nextInt(pool.length)];
    await _mascotRepo.addOwnedMascot(reward.id, now: _clock.now());
    return (wonMascot: reward, equippedMascotId: equippedMascotId);
  }

  /// Equips [mascotId] as the one shown on Home/lesson result/onboarding/
  /// `FoxEmptyState`. Callers (the collection screen) are responsible for
  /// only offering this for already-owned mascots.
  Future<void> equip(String mascotId) => _statsRepo.setEquippedMascot(mascotId);
}

final mascotRepositoryProvider = Provider<MascotRepository>((ref) {
  return MascotRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(systemClockProvider),
  );
});

/// Seam between [MascotService] and the real asset bundle — override with a
/// fake in tests that don't render a widget tree (plain `test()`, no
/// `testWidgets`), so they never touch `rootBundle`/`AssetManifest`, which
/// need a Flutter services binding that only `testWidgets` sets up. Mirrors
/// `foxSoundPlayerProvider`'s seam for `audioplayers`.
final mascotCatalogLoaderProvider =
    Provider<Future<List<MascotEntry>> Function()>((ref) => MascotCatalog.load);

final mascotServiceProvider = Provider<MascotService>((ref) {
  return MascotService(
    ref.watch(statsRepositoryProvider),
    ref.watch(mascotRepositoryProvider),
    ref.watch(systemClockProvider),
    ref.watch(mascotCatalogLoaderProvider),
  );
});
