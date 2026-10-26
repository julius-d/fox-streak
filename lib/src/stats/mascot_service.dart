// Lootbox-trigger algorithm + the sole writer wiring for
// `profileStats.equippedMascotId`/`lessonsCompletedToday`/
// `lessonsCompletedDay` and the `owned_mascots` table (issue #059).
//
// [MascotService.recordLessonCompletion] is the only thing that ever calls
// [MascotRepository.addOwnedMascot] / [StatsRepository.setMascotLessonCounter]
// / [StatsRepository.addCoins]; [MascotService.equip] is the only thing
// that ever calls [StatsRepository.setEquippedMascot].
//
// The mascot-reward pool additionally excludes any seasonal mascot outside
// its fixed window (issue #063) — equipping an already-owned seasonal
// mascot stays unrestricted year-round, so [equip] itself needs no change.
//
// v#064: the mascot pool is every time-eligible catalog entry regardless of
// ownership — duplicates are possible and increment `OwnedMascots.count`
// instead of being filtered out.
//
// v#065: once triggered, a 50/50 coin flip decides between #064's mascot
// pool and a weighted coin amount (`drawCoinAmount`) — never both in the
// same trigger.
//
// v#067: the trigger isn't a single once-a-day event — it repeats every 3rd
// completion after the first (2, 5, 8, 11, ...), uncapped for the day.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clock.dart';
import '../data/mascot_repository.dart';
import '../data/providers.dart';
import '../data/stats_repository.dart';
import '../mascot/lootbox_reward.dart';
import '../mascot/mascot_catalog.dart';

/// Sole writer of the mascot-collection columns/table and `coinsTotal` (via
/// [StatsRepository.setEquippedMascot]/[StatsRepository.setMascotLessonCounter]/
/// [MascotRepository.addOwnedMascot]/[StatsRepository.addCoins]).
class MascotService {
  final StatsRepository _statsRepo;
  final MascotRepository _mascotRepo;
  final Clock _clock;
  final Future<List<MascotEntry>> Function() _loadCatalog;
  final Random Function() _randomFactory;

  MascotService(
    this._statsRepo,
    this._mascotRepo, [
    Clock? clock,
    Future<List<MascotEntry>> Function()? loadCatalog,
    Random Function()? randomFactory,
  ]) : _clock = clock ?? SystemClock(),
       _loadCatalog = loadCatalog ?? MascotCatalog.load,
       _randomFactory = randomFactory ?? Random.new;

  /// Called from the same lesson-completion call site that feeds #010's XP
  /// and #011's streak writes (`LessonController._completeLesson`).
  ///
  /// Bumps the day-scoped `lessonsCompletedToday` counter, resetting it to 1
  /// on a new local day (mirroring `todayXp`'s own day-scoped reset). On
  /// that count landing on 2, 5, 8, 11, ... (issue #067: the 2nd completion
  /// of the day, then every 3rd one after that, uncapped), flips a coin
  /// (issue #065): on heads, picks a catalog entry uniformly at random from
  /// every time-eligible mascot (owned or not — issue #064) and persists
  /// the win; on tails, draws a weighted coin amount and adds it to
  /// `coinsTotal`.
  ///
  /// Also returns the profile's `equippedMascotId` as of this same
  /// [StatsRepository.getProfile] read, so the caller (which needs it for
  /// the result screen's celebration either way) doesn't have to re-query
  /// the same row a second time right after this call returns.
  Future<({LootboxReward? reward, String equippedMascotId})>
  recordLessonCompletion({Random? random}) async {
    final profile = await _statsRepo.getProfile();
    final equippedMascotId = profile.equippedMascotId;
    final today = toLocalDayString(_clock.now());
    final sameDay = profile.lessonsCompletedDay == today;
    final newCount = sameDay ? profile.lessonsCompletedToday + 1 : 1;
    await _statsRepo.setMascotLessonCounter(count: newCount, day: today);
    // Issue #067: the 2nd completion of the day, then every 3rd one after
    // that (5, 8, 11, ...), uncapped.
    final triggers = newCount >= 2 && (newCount - 2) % 3 == 0;
    if (!triggers) {
      return (reward: null, equippedMascotId: equippedMascotId);
    }

    final rng = random ?? _randomFactory();
    // 50/50 coin flip (issue #065): true wins coins, false wins a mascot.
    if (rng.nextBool()) {
      final amount = drawCoinAmount(rng);
      await _statsRepo.addCoins(amount);
      return (reward: CoinsReward(amount), equippedMascotId: equippedMascotId);
    }

    final catalog = await _loadCatalog();
    final now = _clock.now();
    final pool = catalog
        .where((entry) => isMascotInSeason(entry.id, now))
        .toList();
    if (pool.isEmpty) {
      return (reward: null, equippedMascotId: equippedMascotId);
    }

    final wonEntry = pool[rng.nextInt(pool.length)];
    await _mascotRepo.addOwnedMascot(wonEntry.id, now: _clock.now());
    return (reward: MascotReward(wonEntry), equippedMascotId: equippedMascotId);
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

/// Seam for [MascotService]'s default `Random` (issue #065's coin flip +
/// #064's mascot pick) — real callers (`LessonController`) never pass a
/// `random` to [MascotService.recordLessonCompletion], so without this
/// override point, a widget/integration test driving the real provider
/// stack would get a genuinely random (and thus flaky-to-assert-on)
/// outcome. Mirrors [mascotCatalogLoaderProvider]'s override shape.
final mascotRandomProvider = Provider<Random Function()>((ref) => Random.new);

final mascotServiceProvider = Provider<MascotService>((ref) {
  return MascotService(
    ref.watch(statsRepositoryProvider),
    ref.watch(mascotRepositoryProvider),
    ref.watch(systemClockProvider),
    ref.watch(mascotCatalogLoaderProvider),
    ref.watch(mascotRandomProvider),
  );
});
