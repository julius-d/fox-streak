// Library set-card mastery motion (issue #134): what plays when a card shows
// a set's mastery after it last showed another value. Pure, so the rules are
// unit-tested without pumping frames; `SetMasteryIndicator` renders it.

import '../data/set_mastery.dart';

/// The animation from the previously shown mastery to the current one.
class MasteryMotion {
  /// Filled crowns at the start and end of the fill, 0..[kMasteryCrownCount].
  final double fromCrowns;
  final double toCrowns;

  /// The "New" badge shrinks away and the crowns fade in before the fill.
  final bool morphFromNew;

  /// The set just reached 100%: one gold shimmer after the fill.
  final bool shimmer;

  const MasteryMotion({
    required this.fromCrowns,
    required this.toCrowns,
    required this.morphFromNew,
    required this.shimmer,
  });

  bool get fills => toCrowns > fromCrowns;

  /// Indexes of the crowns that become full during the fill (each pops).
  List<int> get poppingCrowns => [
    for (var i = 0; i < kMasteryCrownCount; i++)
      if (fromCrowns < i + 1 && toCrowns >= i + 1) i,
  ];
}

/// The motion from [shown] (what the card last showed; null if it never
/// showed this set) to [current], or null when [current] is simply shown:
/// a first or plain visit, a drop or no change, or reduced motion.
MasteryMotion? planMasteryMotion({
  required SetMastery? shown,
  required SetMastery current,
  required bool reduceMotion,
}) {
  if (reduceMotion || shown == null) return null;
  if (current.kind != MasteryKind.crowns) return null;
  switch (shown.kind) {
    case MasteryKind.fresh:
      return MasteryMotion(
        fromCrowns: 0,
        toCrowns: current.crowns,
        morphFromNew: true,
        shimmer: current.isComplete,
      );
    case MasteryKind.crowns:
      if (current.crowns <= shown.crowns) return null;
      return MasteryMotion(
        fromCrowns: shown.crowns,
        toCrowns: current.crowns,
        morphFromNew: false,
        shimmer: current.isComplete,
      );
    case MasteryKind.none:
      return null;
  }
}
