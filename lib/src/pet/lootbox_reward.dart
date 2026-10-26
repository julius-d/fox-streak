// Lootbox reward result type + the coin-amount weighted draw (issue #065).
//
// `PetService.recordLessonCompletion`'s 50/50 coin flip either wins a
// catalog pet (#064's full-pool draw, unchanged) or a coin amount here —
// never both in the same trigger.

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
int drawCoinAmount(Random random) {
  var draw = random.nextInt(kLootboxCoinTotalWeight);
  for (final amount in kLootboxCoinAmounts) {
    final weight = _weightForCoinAmount(amount);
    if (draw < weight) return amount;
    draw -= weight;
  }
  throw StateError('unreachable: draw exceeded total coin weight');
}
