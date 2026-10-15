// Daily-goal ring (issue #012, added to the #015 widget kit).
//
// Circular, token-driven, a11y-labelled — visually distinct from #010's
// linear `FoxLevelProgressBar` (gold fill, pill shape) since both now sit
// on the same Home screen. Dumb/display-only: callers precompute the
// 0..1 fill and any center label; this widget has no data-layer
// dependency.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Circular progress ring for the daily XP goal.
///
/// [value] is clamped to 0..1. [centerLabel] (e.g. "12 / 30") renders inside
/// the ring; always pass [semanticsLabel]/[semanticsValue] so the goal is
/// announced to screen readers.
class FoxGoalRing extends StatelessWidget {
  final double value;
  final String? centerLabel;
  final String? semanticsLabel;
  final String? semanticsValue;
  final double size;

  static const double _strokeWidth = 10;

  const FoxGoalRing({
    super.key,
    required this.value,
    this.centerLabel,
    this.semanticsLabel,
    this.semanticsValue,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double clamped = value.clamp(0, 1).toDouble();
    return Semantics(
      label: semanticsLabel,
      value: semanticsValue ?? '${(clamped * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: clamped,
                strokeWidth: _strokeWidth,
                strokeCap: StrokeCap.round,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foxSemantics(context).gold,
                ),
              ),
            ),
            if (centerLabel != null)
              // Constrained to the ring's inner diameter (a small margin
              // inside the stroke) and shrunk to fit via FittedBox, so a
              // long label or a large device text-scale never clips or
              // paints over the arc.
              Padding(
                padding: const EdgeInsets.all(_strokeWidth + 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    centerLabel!,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
