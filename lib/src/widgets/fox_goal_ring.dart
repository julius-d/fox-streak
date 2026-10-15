// Daily-goal ring (issue #012, added to the #015 widget kit; reworked in
// #037).
//
// Circular, token-driven, a11y-labelled — visually distinct from #010's
// linear `FoxLevelProgressBar` (gold fill, pill shape) since both now sit
// on the same Home screen. Dumb/display-only: callers precompute the
// (possibly >1, overflowing) fill ratio and the two label lines; this
// widget has no data-layer dependency.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// How much of the outer (current) lap is swept, and how many earlier laps
/// are fully completed, for a given overflowing [value].
///
/// Pulled out of [_GoalRingPainter] so the lap math is unit-testable
/// without a canvas.
@visibleForTesting
({double outerSweep, int nestedLaps}) foxGoalRingLapGeometry(double value) {
  final double target = value < 0 ? 0 : value;
  final int completedLaps = target.floor();
  final double fraction = target - completedLaps;
  final double outerSweep = fraction > 0
      ? fraction
      : (completedLaps > 0 ? 1.0 : 0.0);
  final int nestedLaps = fraction > 0 ? completedLaps : completedLaps - 1;
  return (outerSweep: outerSweep, nestedLaps: nestedLaps < 0 ? 0 : nestedLaps);
}

/// How many of [nestedLapsWanted] nested laps actually fit between
/// [outerRadius] and [labelClearRadius] without crowding the center label.
@visibleForTesting
int foxGoalRingVisibleNestedLaps({
  required int nestedLapsWanted,
  required double outerRadius,
  required double strokeWidth,
  required double lapGap,
  required double labelClearRadius,
}) {
  int visible = 0;
  for (int lap = 0; lap < nestedLapsWanted; lap++) {
    final double radius = outerRadius - (lap + 1) * (strokeWidth + lapGap);
    if (radius < labelClearRadius) {
      break;
    }
    visible++;
  }
  return visible;
}

/// Circular progress ring for the daily XP goal.
///
/// [value] is the total progress toward the goal and is allowed to exceed
/// `1.0`: each whole number is one completed "lap" around the ring. A lap
/// beyond the first nests inside the outer ring as a filled inner circle
/// (fitness-tracker style), so exceeding the goal several times over stays
/// visible instead of just looking "full". The outermost ring always shows
/// the current (possibly partial) lap.
///
/// [primaryLabel] (e.g. "12 XP") and [secondaryLabel] (e.g. "today") render
/// as two short lines inside the ring — the goal amount itself is conveyed
/// by how full the ring is, not restated in text. Always pass
/// [semanticsLabel]/[semanticsValue] so the goal is announced to screen
/// readers (which can't see the fill).
class FoxGoalRing extends StatelessWidget {
  final double value;
  final String? primaryLabel;
  final String? secondaryLabel;
  final String? semanticsLabel;
  final String? semanticsValue;
  final double size;

  static const double _strokeWidth = 7;
  static const double _lapGap = 3;
  static const double _labelClearRadiusFactor = 0.28;
  static const Duration _animationDuration = Duration(milliseconds: 700);

  const FoxGoalRing({
    super.key,
    required this.value,
    this.primaryLabel,
    this.secondaryLabel,
    this.semanticsLabel,
    this.semanticsValue,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double target = value < 0 ? 0 : value;
    final double labelClearRadius = size * _labelClearRadiusFactor;
    final double labelMargin = size / 2 - labelClearRadius;

    return Semantics(
      label: semanticsLabel,
      value: semanticsValue ?? '${(target * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              duration: _animationDuration,
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: target),
              builder: (BuildContext context, double animated, _) {
                return CustomPaint(
                  size: Size.square(size),
                  painter: _GoalRingPainter(
                    value: animated,
                    strokeWidth: _strokeWidth,
                    lapGap: _lapGap,
                    labelClearRadius: labelClearRadius,
                    trackColor: scheme.surfaceContainerHighest,
                    fillColor: foxSemantics(context).gold,
                  ),
                );
              },
            ),
            if (primaryLabel != null || secondaryLabel != null)
              // Constrained to the clear center (kept free of nested laps
              // by the painter) and shrunk to fit via FittedBox, so a long
              // label or a large device text-scale never clips or paints
              // over the ring.
              Padding(
                padding: EdgeInsets.all(labelMargin),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (primaryLabel != null)
                        Text(
                          primaryLabel!,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      if (secondaryLabel != null)
                        Text(
                          secondaryLabel!,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints the goal ring: a track circle, the current (outermost, possibly
/// partial) lap, and any fully-completed earlier laps nested inward as
/// filled circles — stopping before they'd reach [labelClearRadius].
class _GoalRingPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final double lapGap;
  final double labelClearRadius;
  final Color trackColor;
  final Color fillColor;

  _GoalRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.lapGap,
    required this.labelClearRadius,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double outerRadius = size.shortestSide / 2 - strokeWidth / 2;
    if (outerRadius <= 0) {
      return;
    }

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, outerRadius, trackPaint);

    final (outerSweep: double outerSweep, nestedLaps: int nestedLapsWanted) =
        foxGoalRingLapGeometry(value);
    if (outerSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        -math.pi / 2,
        2 * math.pi * outerSweep,
        false,
        fillPaint,
      );
    }

    // The outer ring already represents one lap (the current one); nest
    // the remaining completed laps inward, stopping before they would
    // intrude on the center label.
    final int visibleNestedLaps = foxGoalRingVisibleNestedLaps(
      nestedLapsWanted: nestedLapsWanted,
      outerRadius: outerRadius,
      strokeWidth: strokeWidth,
      lapGap: lapGap,
      labelClearRadius: labelClearRadius,
    );
    for (int lap = 0; lap < visibleNestedLaps; lap++) {
      final double radius = outerRadius - (lap + 1) * (strokeWidth + lapGap);
      canvas.drawCircle(center, radius, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GoalRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.lapGap != lapGap ||
        oldDelegate.labelClearRadius != labelClearRadius ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.fillColor != fillColor;
  }
}
