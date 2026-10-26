// Friendly generic progress bar (issue #015).
//
// Pill-shaped, token-driven, screen-reader labelled. #010 composes the
// level-progress widget on top of this (e.g. gold fill + XP label) instead
// of building its own bar.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Generic progress bar with value in 0..1 (clamped).
///
/// [color] defaults to the theme primary; pass `gold` for XP-flavoured
/// fills. Always expose [semanticsLabel] + [semanticsValue] so progress is
/// announced.
///
/// [animated], when `true`, tweens the fill (300ms, `Curves.easeInOut`)
/// whenever [value] changes between rebuilds instead of jumping instantly
/// (issue #066); the initial build still renders its starting value
/// immediately. Opt in per caller — default `false` keeps every existing
/// caller's instant-jump behavior, including callers like
/// [FoxLevelProgressBar] that already drive [value] via their own
/// animation and must not be double-animated. Also respects
/// `MediaQuery.disableAnimations`: when set, the fill jumps straight to
/// the new value even if [animated] is `true`.
class FoxProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final String? semanticsLabel;
  final String? semanticsValue;
  final bool animated;

  const FoxProgressBar({
    super.key,
    required this.value,
    this.color,
    this.semanticsLabel,
    this.semanticsValue,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final double clamped = value.clamp(0, 1).toDouble();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      value: semanticsValue ?? '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.pill)),
        child: SizedBox(
          height: 16,
          child: animated && !reduceMotion
              ? TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: clamped, end: clamped),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  builder: (context, animatedValue, _) =>
                      _fill(scheme, animatedValue),
                )
              : _fill(scheme, clamped),
        ),
      ),
    );
  }

  Widget _fill(ColorScheme scheme, double clamped) {
    return LinearProgressIndicator(
      value: clamped,
      backgroundColor: scheme.surfaceContainerHighest,
      valueColor: AlwaysStoppedAnimation<Color>(color ?? scheme.primary),
      borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.pill)),
    );
  }
}
