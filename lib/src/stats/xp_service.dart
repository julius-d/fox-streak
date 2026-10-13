// XP + level formulas and the sole writer wiring for xp_total/today_xp
// (issue #010).
//
// The static formulas (`xpForOutcome`, `lessonBonus`, `xpEarned`,
// `levelForXp`, `xpForLevel`, `progressToNextLevel`) are pure and reused by
// the UI for display math; [XpService.applyLessonResult] is the only thing
// that ever calls [StatsRepository.addXp].

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clock.dart';
import '../data/providers.dart';
import '../data/stats_repository.dart';
import '../lesson/exercise_card.dart';

/// XP awarded for a correct answer with no hint used.
const int kXpCorrectNoHint = 10;

/// XP awarded for a correct answer where a hint was used.
const int kXpCorrectWithHint = 5;

/// Flat bonus XP for a perfect (100%) lesson score.
const int kXpPerfectBonus = 5;

/// Sole writer of `xp_total`/`today_xp` (via [StatsRepository.addXp]).
class XpService {
  final StatsRepository _statsRepo;
  final Clock _clock;

  XpService(this._statsRepo, [Clock? clock]) : _clock = clock ?? SystemClock();

  /// XP for a single outcome: 10 correct/no-hint, 5 correct/hint, 0 otherwise
  /// (wrong or skipped). `firstTry` doesn't factor in — no retry exists.
  static int xpForOutcome(LessonItemOutcome outcome) {
    if (!outcome.correct) return 0;
    return outcome.hintUsed ? kXpCorrectWithHint : kXpCorrectNoHint;
  }

  /// Flat +5 bonus when [result] is a perfect (100%) score.
  static int lessonBonus(LessonResult result) =>
      result.scorePct == 100 ? kXpPerfectBonus : 0;

  /// Total XP earned by [result]: per-item XP plus the perfect bonus.
  static int xpEarned(LessonResult result) =>
      result.outcomes.fold<int>(0, (sum, o) => sum + xpForOutcome(o)) +
      lessonBonus(result);

  /// Level for a lifetime [xpTotal]: `floor(sqrt(xpTotal / 100)) + 1`.
  static int levelForXp(int xpTotal) => sqrt(xpTotal / 100).floor() + 1;

  /// XP required to reach [level]: `(level - 1)^2 * 100`.
  static int xpForLevel(int level) => (level - 1) * (level - 1) * 100;

  /// Progress 0..1 from the current level's threshold to the next.
  static double progressToNextLevel(int xpTotal) {
    final level = levelForXp(xpTotal);
    final lo = xpForLevel(level);
    final hi = xpForLevel(level + 1);
    return (xpTotal - lo) / (hi - lo);
  }

  /// Applies [result]'s XP exactly once; the caller (`LessonController`)
  /// guards against repeat calls via `LessonState.xpApplied`.
  Future<XpApplication> applyLessonResult(LessonResult result) async {
    final earned = xpEarned(result);
    final xpTotal = await _statsRepo.addXp(earned, now: _clock.now());
    return XpApplication(earned: earned, xpTotal: xpTotal);
  }
}

/// Result of applying a lesson's XP: how much was earned and the resulting
/// lifetime `xpTotal` — handed straight to the UI so it never has to
/// re-query the database for the level-progress widget.
class XpApplication {
  final int earned;
  final int xpTotal;

  const XpApplication({required this.earned, required this.xpTotal});
}

final xpServiceProvider = Provider<XpService>((ref) {
  return XpService(
    ref.watch(statsRepositoryProvider),
    ref.watch(systemClockProvider),
  );
});
