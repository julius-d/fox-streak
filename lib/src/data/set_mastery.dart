// Per-set mastery (issue #134): how many of a set's items are mastered.
//
// An item is mastered when its two most recent answers were both correct and
// given without a hint (a skip is recorded as a wrong answer). Counted by
// `StatsRepository.watchSetMastery`; rendered as crowns on Library set cards.

/// Number of crowns a fully mastered set shows.
const int kMasteryCrownCount = 5;

/// What a set's mastery indicator shows.
enum MasteryKind {
  /// The set has no items: neither crowns nor a badge.
  none,

  /// The set has items, none of them ever answered: the "New" badge.
  fresh,

  /// At least one item was answered: the crowns (possibly all empty).
  crowns,
}

/// Mastery snapshot of one set.
class SetMastery {
  final int itemCount;
  final int masteredCount;

  /// Whether any of the set's current items was ever answered.
  final bool practiced;

  const SetMastery({
    required this.itemCount,
    required this.masteredCount,
    required this.practiced,
  });

  /// A set without items.
  static const SetMastery empty = SetMastery(
    itemCount: 0,
    masteredCount: 0,
    practiced: false,
  );

  MasteryKind get kind {
    if (itemCount == 0) return MasteryKind.none;
    return practiced ? MasteryKind.crowns : MasteryKind.fresh;
  }

  /// Filled crowns, 0..[kMasteryCrownCount], any fraction. Multiplied before
  /// dividing so whole crowns come out exact (3 of 3 items is exactly 5.0).
  double get crowns =>
      itemCount == 0 ? 0 : masteredCount * kMasteryCrownCount / itemCount;

  /// Mastered share as a whole percent, rounded down so 100 means every
  /// item is mastered.
  int get percent => itemCount == 0 ? 0 : masteredCount * 100 ~/ itemCount;

  bool get isComplete => itemCount > 0 && masteredCount == itemCount;

  @override
  bool operator ==(Object other) =>
      other is SetMastery &&
      other.itemCount == itemCount &&
      other.masteredCount == masteredCount &&
      other.practiced == practiced;

  @override
  int get hashCode => Object.hash(itemCount, masteredCount, practiced);

  @override
  String toString() =>
      'SetMastery($masteredCount/$itemCount, practiced: $practiced)';
}
