// XP-up screen (issue #078), split out of the old combined lesson result
// screen so XP/level-up gets its own focused moment. Shown always, right
// after the loot box/streak-saved screens (if either applied) and before
// the summary screen. Carries over #010's XP count-up + perfect-score
// bonus callout + level-progress bar, and #053's level-up callout +
// confetti + chime, unchanged. Pops itself on Continue, same shape as
// `LootboxScreen`/`StreakSavedScreen`.

import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../stats/xp_service.dart';
import '../theme/fox_streak_theme.dart';
import '../widgets/widgets.dart';

/// Full-screen XP celebration, shown once per lesson completion.
class XpUpScreen extends StatelessWidget {
  final int xpEarned;
  final int bonus;
  final int xpTotal;
  final int? xpTotalBefore;
  final AppLocalizations l10n;

  const XpUpScreen({
    super.key,
    required this.xpEarned,
    required this.bonus,
    required this.xpTotal,
    required this.xpTotalBefore,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final xpTotalBefore = this.xpTotalBefore;
    final leveledUp =
        xpTotalBefore != null &&
        XpService.levelForXp(xpTotal) > XpService.levelForXp(xpTotalBefore);
    final level = XpService.levelForXp(xpTotal);
    final lo = XpService.xpForLevel(level);
    final hi = XpService.xpForLevel(level + 1);
    final animateFrom = leveledUp
        ? XpService.progressToNextLevel(xpTotalBefore)
        : null;

    return Stack(
      children: [
        Scaffold(
          key: const Key('xpUpScreen'),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(FoxSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FoxCelebration(
                      child: _XpCountUp(xp: xpEarned, l10n: l10n),
                    ),
                    if (bonus > 0) ...[
                      const SizedBox(height: FoxSpacing.xs),
                      FoxCelebration(
                        child: Text(
                          l10n.lessonXpBonusCallout(bonus),
                          key: const Key('xpBonusCallout'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .extension<FoxSemanticColors>()!
                                    .goldInk,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                    if (leveledUp) ...[
                      const SizedBox(height: FoxSpacing.xs),
                      FoxCelebration(
                        child: Text(
                          l10n.lessonLevelUpCallout(level),
                          key: const Key('levelUpCallout'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .extension<FoxSemanticColors>()!
                                    .goldInk,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: FoxSpacing.md),
                    FoxLevelProgressBar(
                      key: const Key('levelProgressBar'),
                      level: level,
                      progress: XpService.progressToNextLevel(xpTotal),
                      levelLabel: l10n.levelLabel(level),
                      progressText: l10n.levelProgressText(
                        xpTotal - lo,
                        hi - lo,
                      ),
                      semanticsLabel: l10n.levelProgressLabel,
                      levelUpAnimateFrom: animateFrom,
                    ),
                    const SizedBox(height: FoxSpacing.xxl),
                    FoxPrimaryButton(
                      key: const Key('xpUpContinueButton'),
                      label: l10n.lessonContinue,
                      expanded: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _LevelUpEffects(active: leveledUp),
      ],
    );
  }
}

/// Confetti burst + level-up chime, triggered exactly once per XP-up screen
/// that leveled up (issue #053). A dedicated [State] — rather than inline
/// logic in the stateless [XpUpScreen] — so a stray ancestor rebuild can
/// never replay the burst/chime a second time; [initState] only runs once
/// per mount.
class _LevelUpEffects extends ConsumerStatefulWidget {
  final bool active;

  const _LevelUpEffects({required this.active});

  @override
  ConsumerState<_LevelUpEffects> createState() => _LevelUpEffectsState();
}

class _LevelUpEffectsState extends ConsumerState<_LevelUpEffects> {
  // Null on the (common, non-level-up) inactive path: no point allocating a
  // ConfettiController — and the ticker/AnimationController it backs — for
  // a widget that never shows any confetti.
  ConfettiController? _confettiController;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      final controller = ConfettiController(
        duration: const Duration(milliseconds: 500),
      );
      _confettiController = controller;
      controller.play();
      if (ref.read(foxSoundEnabledProvider)) {
        unawaited(ref.read(foxSoundPlayerProvider).playLevelUp());
      }
    }
  }

  @override
  void dispose() {
    _confettiController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _confettiController;
    if (controller == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          key: const Key('levelUpConfetti'),
          confettiController: controller,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 60,
        ),
      ),
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
