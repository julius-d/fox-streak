// Lootbox reward result type + the coin-amount weighted draw (issue #065).
//
// `PetService.recordLessonCompletion`'s 50/50 coin flip either wins a
// catalog pet (#064's full-pool draw, unchanged) or a coin amount here —
// never both in the same trigger.
//
// Issue #085 adds the wheel-of-fortune's own coin table/draw alongside the
// lootbox's — a distinct, wheel-sized table so every slice stays legible on
// a drawn wheel. Issue #087 extends that wheel with a 7th, rarer segment —
// winning a "streak on ice" instead of coins — via the [WheelReward] sealed
// type / [kWheelSegments] / [drawWheelSegment] below. The wheel's trigger is
// a disjoint cadence from the lootbox's (see `PetService`'s class doc), so
// the two draws never both run for the same completion.

import 'dart:math';

import 'pet_catalog.dart';

/// What a triggered #059 lootbox awarded: a pet (#064's full-pool draw)
/// or a coin amount (#065) — never both in the same trigger.
sealed class LootboxReward {
  const LootboxReward();
}

/// A won (or re-won, see #064) catalog pet.
class PetReward extends LootboxReward {
  final PetEntry entry;

  const PetReward(this.entry);

  @override
  bool operator ==(Object other) => other is PetReward && other.entry == entry;

  @override
  int get hashCode => entry.hashCode;
}

/// A won coin amount, one of [kLootboxCoinAmounts].
class CoinsReward extends LootboxReward {
  final int amount;

  const CoinsReward(this.amount);

  @override
  bool operator ==(Object other) =>
      other is CoinsReward && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;
}

/// The lootbox's possible coin amounts: 5, 10, ..., 100.
const List<int> kLootboxCoinAmounts = [
  5, 10, 15, 20, 25, 30, 35, 40, 45, 50, //
  55, 60, 65, 70, 75, 80, 85, 90, 95, 100,
];

/// Each amount's draw weight, linearly decreasing so smaller amounts are
/// more likely — 100 for 5 coins, down to 5 for 100 coins.
int _weightForCoinAmount(int amount) => 105 - amount;

/// Sum of every [kLootboxCoinAmounts] entry's [_weightForCoinAmount] (1050),
/// i.e. the exclusive upper bound for the cumulative draw in
/// [drawCoinAmount].
final int kLootboxCoinTotalWeight = kLootboxCoinAmounts
    .map(_weightForCoinAmount)
    .reduce((a, b) => a + b);

/// Draws a coin amount from [kLootboxCoinAmounts] via a single
/// cumulative-weight draw off [random], weighted so smaller amounts are
/// more likely per [_weightForCoinAmount].
int drawCoinAmount(Random random) => _drawWeighted(
  random,
  kLootboxCoinAmounts,
  _weightForCoinAmount,
  kLootboxCoinTotalWeight,
);

/// Single cumulative-weight draw shared by [drawCoinAmount]/
/// [drawWheelSegment]: picks one of [items] off [random], weighted by
/// [weightOf] — smaller [totalWeight]-th of the way through [random]'s
/// draw lands on items whose cumulative weight-so-far is smaller.
T _drawWeighted<T>(
  Random random,
  List<T> items,
  int Function(T) weightOf,
  int totalWeight,
) {
  var draw = random.nextInt(totalWeight);
  for (final item in items) {
    final weight = weightOf(item);
    if (draw < weight) return item;
    draw -= weight;
  }
  throw StateError('unreachable: draw exceeded total weight');
}

/// What the wheel-of-fortune awarded (issues #085/#087): a coin amount or
/// the rarer streak-on-ice win — never both in the same spin.
sealed class WheelReward {
  const WheelReward();
}

/// A won wheel coin amount, one of [kWheelCoinAmounts] (issue #085).
class WheelCoinsReward extends WheelReward {
  final int amount;

  const WheelCoinsReward(this.amount);

  @override
  bool operator ==(Object other) =>
      other is WheelCoinsReward && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;
}

/// A won streak-on-ice (issue #087): increments `streakFreezesAvailable`
/// instead of `coinsTotal` (see `StatsRepository.addStreakFreezes`).
class WheelStreakOnIceReward extends WheelReward {
  const WheelStreakOnIceReward();

  @override
  bool operator ==(Object other) => other is WheelStreakOnIceReward;

  @override
  int get hashCode => 0;
}

/// The wheel's coin amounts (issue #085) — a distinct, 6-value table from
/// [kLootboxCoinAmounts], sized so every slice stays legible on a drawn
/// wheel.
const List<int> kWheelCoinAmounts = [10, 20, 30, 50, 75, 100];

/// The wheel's fixed slice order (issue #087 adds the streak-on-ice 7th
/// slice after #085's original six coin amounts). `WheelScreen` paints
/// slice `i` for `kWheelSegments[i]` and [wheelTargetRotationTurns]
/// (`wheel_screen.dart`) relies on this exact order/length to compute which
/// rotation lands which slice under the pointer.
final List<WheelReward> kWheelSegments = [
  ...kWheelCoinAmounts.map(WheelCoinsReward.new),
  const WheelStreakOnIceReward(),
];

/// Each segment's draw weight: coin amounts keep #085's linearly-decreasing
/// `110 - amount` shape (100 for 10 coins, down to 10 for 100 coins); the
/// streak-on-ice segment draws at a fixed weight of 5 — rarer than every
/// coin amount (the smallest coin weight, for 100 coins, is 10) per issue
/// #087's "rare/exciting win" decision.
int _weightForWheelSegment(WheelReward segment) => switch (segment) {
  WheelCoinsReward(amount: final amount) => 110 - amount,
  WheelStreakOnIceReward() => 5,
};

/// Sum of every [kWheelSegments] entry's [_weightForWheelSegment] (380),
/// i.e. the exclusive upper bound for the cumulative draw in
/// [drawWheelSegment].
final int kWheelSegmentsTotalWeight = kWheelSegments
    .map(_weightForWheelSegment)
    .reduce((a, b) => a + b);

/// Draws a [WheelReward] from [kWheelSegments] via a single cumulative-
/// weight draw off [random], weighted per [_weightForWheelSegment] —
/// mirrors [drawCoinAmount]'s shape against the wheel's own table.
WheelReward drawWheelSegment(Random random) => _drawWeighted(
  random,
  kWheelSegments,
  _weightForWheelSegment,
  kWheelSegmentsTotalWeight,
);
