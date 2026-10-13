// Lesson result screen (issue #005, XP/level wiring from #010, streak
// wiring from #011).
//
// Shows score % + correct/total, FoxMascot celebration (on-fire when this
// lesson just hit a streak milestone, else lit if score > 0, empty on 0),
// FoxCelebration micro-moment, XP-earned count-up + perfect-score bonus
// callout + level-progress bar (#010), streak headline + StreakBadge
// (#011), Practice again + Back to library buttons.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../stats/streak_service.dart';
import '../stats/xp_service.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';
import 'exercise_card.dart';
import 'lesson_controller.dart';

/// Result screen shown when the lesson completes.
class LessonResultScreen extends ConsumerWidget {
  final LessonResult result;
  final AppLocalizations l10n;
  final VoidCallback onPracticeAgain;
  final VoidCallback onBackToLibrary;

  const LessonResultScreen({
    super.key,
    required this.result,
    required this.l10n,
    required this.onPracticeAgain,
    required this.onBackToLibrary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpEarned = XpService.xpEarned(result);
    final bonus = XpService.lessonBonus(result);
    // Read straight from the controller's state (set alongside xpApplied by
    // LessonController._completeLesson) rather than watching the database:
    // this is a one-shot result snapshot, not a live-updating dashboard, so
    // it doesn't need (and shouldn't hold open) a drift watch() stream.
    final xpTotal = ref.watch(
      lessonControllerProvider.select((s) => s.xpTotalAfterLesson),
    );
    final streakCount = ref.watch(
      lessonControllerProvider.select((s) => s.streakCountAfterLesson),
    );
    final isMilestone =
        streakCount != null && StreakService.isMilestone(streakCount);
    final mascotState = isMilestone
        ? FoxMascotState.onFire
        : (result.scorePct > 0 ? FoxMascotState.lit : FoxMascotState.empty);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FoxSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration wrapper for the micro-moment
              FoxCelebration(
                child: FoxMascot(
                  state: mascotState,
                  size: 120,
                  semanticLabel: isMilestone
                      ? l10n.lessonStreakResultText(streakCount)
                      : (result.scorePct > 0
                            ? l10n.lessonCelebrate
                            : l10n.lessonNoScore),
                ),
              ),
              const SizedBox(height: FoxSpacing.xl),
              // Score summary
              Text(
                l10n.lessonScoreSummary(
                  result.correctCount,
                  result.itemIds.length,
                  result.scorePct,
                ),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FoxSpacing.md),
              Text(
                '${result.correctCount} / ${result.itemIds.length}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FoxSpacing.xl),
              // XP-earned count-up (#010)
              FoxCelebration(
                child: _XpCountUp(xp: xpEarned, l10n: l10n),
              ),
              if (bonus > 0) ...[
                const SizedBox(height: FoxSpacing.xs),
                FoxCelebration(
                  child: Text(
                    l10n.lessonXpBonusCallout(bonus),
                    key: const Key('xpBonusCallout'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .extension<FoxSemanticColors>()!
                          .goldInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: FoxSpacing.md),
              _buildLevelProgress(context, xpTotal ?? 0),
              const SizedBox(height: FoxSpacing.lg),
              // Streak section (#011)
              if (streakCount != null) ...[
                FoxCelebration(
                  child: Text(
                    l10n.lessonStreakResultText(streakCount),
                    key: const Key('streakResultText'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foxSemantics(context).flame,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: FoxSpacing.sm),
                StreakBadge(
                  key: const Key('streakBadge'),
                  streakCount: streakCount,
                  todayDone: true,
                  streakCountLabel: l10n.streakCountLabel(streakCount),
                  todayDoneLabel: l10n.streakTodayDoneLabel,
                  semanticsLabel:
                      '${l10n.lessonStreakResultText(streakCount)} '
                      '${l10n.streakTodayDoneLabel}',
                ),
              ],
              const SizedBox(height: FoxSpacing.xxl),
              // Practice again button
              FoxPrimaryButton(
                key: const Key('practiceAgainButton'),
                label: l10n.lessonPracticeAgain,
                expanded: true,
                icon: Icons.refresh,
                onPressed: onPracticeAgain,
              ),
              const SizedBox(height: FoxSpacing.md),
              // Back to library button
              FoxSecondaryButton(
                key: const Key('backToLibraryButton'),
                label: l10n.lessonBackToLibrary,
                expanded: true,
                onPressed: onBackToLibrary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelProgress(BuildContext context, int xpTotal) {
    final level = XpService.levelForXp(xpTotal);
    final lo = XpService.xpForLevel(level);
    final hi = XpService.xpForLevel(level + 1);
    return FoxLevelProgressBar(
      key: const Key('levelProgressBar'),
      level: level,
      progress: XpService.progressToNextLevel(xpTotal),
      levelLabel: l10n.levelLabel(level),
      progressText: l10n.levelProgressText(xpTotal - lo, hi - lo),
      semanticsLabel: l10n.levelProgressLabel,
    );
  }
}

/// XP-earned count-up: a single 600ms elastic-free tween from 0 to [xp]
/// (issue #010's "simple non-lottie count-up" animation budget).
class _XpCountUp extends StatelessWidget {
  final int xp;
  final AppLocalizations l10n;

  const _XpCountUp({required this.xp, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).extension<FoxSemanticColors>()!.goldInk;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: xp),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, _) => Text(
        l10n.xpEarnedLabel(value),
        key: const Key('xpEarnedLabel'),
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: gold, fontWeight: FontWeight.w800),
      ),
    );
  }
}
