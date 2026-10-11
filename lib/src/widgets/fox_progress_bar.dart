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
class FoxProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final String? semanticsLabel;
  final String? semanticsValue;

  const FoxProgressBar({
    super.key,
    required this.value,
    this.color,
    this.semanticsLabel,
    this.semanticsValue,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double clamped = value.clamp(0, 1).toDouble();
    return Semantics(
      label: semanticsLabel,
      value: semanticsValue ?? '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.pill)),
        child: SizedBox(
          height: 16,
          child: LinearProgressIndicator(
            value: clamped,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color ?? scheme.primary),
            borderRadius: const BorderRadius.all(
              Radius.circular(FoxRadius.pill),
            ),
          ),
        ),
      ),
    );
  }
}
