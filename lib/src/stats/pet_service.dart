// Lootbox-trigger algorithm + the sole writer wiring for
// `profileStats.equippedPetId`/`lessonsCompletedToday`/
// `lessonsCompletedDay` and the `owned_pets` table (issue #059).
//
// [PetService.recordLessonCompletion] is the only thing that ever calls
// [PetRepository.addOwnedPet] / [StatsRepository.setPetLessonCounter]
// / [StatsRepository.addCoins]; [PetService.equip] is the only thing
// that ever calls [StatsRepository.setEquippedPet].
//
// The pet-reward pool additionally excludes any seasonal pet outside
// its fixed window (issue #063) — equipping an already-owned seasonal
// pet stays unrestricted year-round, so [equip] itself needs no change.
//
// v#064: the pet pool is every time-eligible catalog entry regardless of
// ownership — duplicates are possible and increment `OwnedPets.count`
// instead of being filtered out.
//
// v#065: once triggered, a 50/50 coin flip decides between #064's pet
// pool and a weighted coin amount (`drawCoinAmount`) — never both in the
// same trigger.
//
// v#067: the trigger isn't a single once-a-day event — it repeats every 3rd
// completion after the first (2, 5, 8, 11, ...), uncapped for the day.
//
// v#085: a second, independent reward moment — the wheel of fortune —
// fires on `newCount % 3 == 0` (3, 6, 9, ...), uncapped. That cadence is
// disjoint from #067's `newCount >= 2 && (newCount - 2) % 3 == 0` (2, 5,
// 8, 11, ... are all ≡2 mod 3; 3, 6, 9, ... are all ≡0 mod 3), so the two
// never trigger on the same completion and [recordLessonCompletion]'s
// `reward`/`wheelCoinAmount` fields are never both non-null. Unlike the
// lootbox's coin-flip branch, the wheel only ever awards coins (via
// `drawWheelCoinAmount`/[StatsRepository.addCoins]) — never a pet.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clock.dart';
import '../data/pet_repository.dart';
import '../data/providers.dart';
import '../data/stats_repository.dart';
import '../pet/lootbox_reward.dart';
import '../pet/pet_catalog.dart';

/// Sole writer of the pet-collection columns/table and `coinsTotal` (via
/// [StatsRepository.setEquippedPet]/[StatsRepository.setPetLessonCounter]/
/// [PetRepository.addOwnedPet]/[StatsRepository.addCoins]).
class PetService {
  final StatsRepository _statsRepo;
  final PetRepository _petRepo;
  final Clock _clock;
  final Future<List<PetEntry>> Function() _loadCatalog;
  final Random Function() _randomFactory;

  PetService(
    this._statsRepo,
    this._petRepo, [
    Clock? clock,
    Future<List<PetEntry>> Function()? loadCatalog,
    Random Function()? randomFactory,
  ]) : _clock = clock ?? SystemClock(),
       _loadCatalog = loadCatalog ?? PetCatalog.load,
       _randomFactory = randomFactory ?? Random.new;

  /// Called from the same lesson-completion call site that feeds #010's XP
  /// and #011's streak writes (`LessonController._completeLesson`).
  ///
  /// Bumps the day-scoped `lessonsCompletedToday` counter, resetting it to 1
  /// on a new local day (mirroring `todayXp`'s own day-scoped reset). On
  /// that count landing on 2, 5, 8, 11, ... (issue #067: the 2nd completion
  /// of the day, then every 3rd one after that, uncapped), flips a coin
  /// (issue #065): on heads, draws a catalog entry weighted by [PetRarity]
  /// tier from every time-eligible pet (owned or not — issue #064, odds by
  /// issue #069) and persists the win; on tails, draws a weighted coin
  /// amount and adds it to `coinsTotal`.
  ///
  /// Also returns the profile's `equippedPetId` as of this same
  /// [StatsRepository.getProfile] read, so the caller (which needs it for
  /// the result screen's celebration either way) doesn't have to re-query
  /// the same row a second time right after this call returns.
  ///
  /// `wheelCoinAmount` is issue #085's independent wheel-of-fortune win —
  /// a drawn-and-persisted coin amount on `newCount % 3 == 0` (3, 6, 9,
  /// ...), uncapped — see this file's header doc for why it never
  /// coincides with a non-null `reward`.
  Future<({LootboxReward? reward, String equippedPetId, int? wheelCoinAmount})>
  recordLessonCompletion({Random? random}) async {
    final profile = await _statsRepo.getProfile();
    final equippedPetId = profile.equippedPetId;
    final today = toLocalDayString(_clock.now());
    final sameDay = profile.lessonsCompletedDay == today;
    final newCount = sameDay ? profile.lessonsCompletedToday + 1 : 1;
    await _statsRepo.setPetLessonCounter(count: newCount, day: today);

    // Issue #085: every 3rd completion (3, 6, 9, ...), uncapped — disjoint
    // from the lootbox cadence below (see this file's header doc).
    int? wheelCoinAmount;
    if (newCount > 0 && newCount % 3 == 0) {
      wheelCoinAmount = drawWheelCoinAmount(random ?? _randomFactory());
      await _statsRepo.addCoins(wheelCoinAmount);
    }

    // Issue #067: the 2nd completion of the day, then every 3rd one after
    // that (5, 8, 11, ...), uncapped.
    LootboxReward? reward;
    final triggers = newCount >= 2 && (newCount - 2) % 3 == 0;
    if (triggers) {
      final rng = random ?? _randomFactory();
      // 50/50 coin flip (issue #065): true wins coins, false wins a pet.
      if (rng.nextBool()) {
        final amount = drawCoinAmount(rng);
        await _statsRepo.addCoins(amount);
        reward = CoinsReward(amount);
      } else {
        final catalog = await _loadCatalog();
        final now = _clock.now();
        final pool = catalog.where((entry) => entry.isInSeasonAt(now)).toList();
        if (pool.isNotEmpty) {
          final wonEntry = drawPet(pool, rng);
          await _petRepo.addOwnedPet(wonEntry.id, now: _clock.now());
          reward = PetReward(wonEntry);
        }
      }
    }

    // Single source of truth for the "never both non-null" invariant the
    // disjoint cadences are supposed to guarantee (see this file's header
    // doc) — a future edit to either formula that breaks disjointness
    // trips this immediately in debug/test runs, rather than silently
    // pushing both the lootbox and the wheel screens back-to-back.
    assert(
      reward == null || wheelCoinAmount == null,
      'lootbox reward and wheel win must never both be non-null for the '
      'same completion',
    );
    return (
      reward: reward,
      equippedPetId: equippedPetId,
      wheelCoinAmount: wheelCoinAmount,
    );
  }

  /// Equips [petId] as the one shown on Home/lesson result/onboarding/
  /// `FoxEmptyState`. Callers (the collection screen) are responsible for
  /// only offering this for already-owned pets.
  Future<void> equip(String petId) => _statsRepo.setEquippedPet(petId);
}

final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(systemClockProvider),
  );
});

/// Seam between [PetService] and [PetCatalog.load] — override with a fixture
/// catalog in tests that want a reduced or reordered pool instead of the
/// full static catalog. Mirrors `foxSoundPlayerProvider`'s seam for
/// `audioplayers`.
final petCatalogLoaderProvider = Provider<Future<List<PetEntry>> Function()>(
  (ref) => PetCatalog.load,
);

/// Seam for [PetService]'s default `Random` (issue #065's coin flip +
/// #064's pet pick) — real callers (`LessonController`) never pass a
/// `random` to [PetService.recordLessonCompletion], so without this
/// override point, a widget/integration test driving the real provider
/// stack would get a genuinely random (and thus flaky-to-assert-on)
/// outcome. Mirrors [petCatalogLoaderProvider]'s override shape.
final petRandomProvider = Provider<Random Function()>((ref) => Random.new);

final petServiceProvider = Provider<PetService>((ref) {
  return PetService(
    ref.watch(statsRepositoryProvider),
    ref.watch(petRepositoryProvider),
    ref.watch(systemClockProvider),
    ref.watch(petCatalogLoaderProvider),
    ref.watch(petRandomProvider),
  );
});
