// Mastery crowns + "New" badge (issue #134, added to the #015 widget kit).
//
// Display-only: callers pass the fill (0..5 crowns, any fraction) and, while
// animating, per-crown pop scales and the shimmer position. The Library
// card's `SetMasteryIndicator` drives them; no data-layer dependency here.

import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Five crowns filled continuously from left to right with XP-gold; unfilled
/// parts are an outline. Not announced on its own — the caller wraps it in
/// one semantics label for the whole indicator.
class FoxMasteryCrowns extends StatelessWidget {
  static const int count = 5;
  static const double crownWidth = 20;
  static const double crownHeight = 18;
  static const double gap = 2;

  /// Filled crowns, clamped to 0..[count].
  final double fill;

  /// Scale of each crown (pop); null means 1 for all.
  final List<double>? crownScales;

  /// Gold shimmer sweep position, 0 (left) .. 1 (right); null for none.
  final double? shimmer;

  const FoxMasteryCrowns({
    super.key,
    required this.fill,
    this.crownScales,
    this.shimmer,
  });

  @override
  Widget build(BuildContext context) {
    final semantics = foxSemantics(context);
    final outline = Theme.of(context).colorScheme.outline;
    final double clamped = fill.clamp(0, count).toDouble();
    Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          Transform.scale(
            scale: crownScales?[i] ?? 1,
            child: CustomPaint(
              key: Key('masteryCrown-$i'),
              size: const Size(crownWidth, crownHeight),
              painter: _CrownPainter(
                fill: (clamped - i).clamp(0, 1).toDouble(),
                fillColor: semantics.gold,
                fullStrokeColor: semantics.goldInk,
                outlineColor: outline,
              ),
            ),
          ),
        ],
      ],
    );
    final double? sweep = shimmer;
    if (sweep != null) {
      // A pale gold derived from the XP-gold token, swept across the crowns
      // (srcATop: only where a crown is painted).
      final Color sheen = HSLColor.fromColor(semantics.gold)
          .withLightness(0.92)
          .toColor();
      final double center = -0.3 + sweep * 1.6;
      row = ShaderMask(
        key: const Key('masteryShimmer'),
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            sheen.withValues(alpha: 0),
            sheen,
            sheen.withValues(alpha: 0),
          ],
          stops: [center - 0.25, center, center + 0.25],
        ).createShader(bounds),
        child: row,
      );
    }
    return ExcludeSemantics(child: row);
  }
}

class _CrownPainter extends CustomPainter {
  final double fill;
  final Color fillColor;
  final Color fullStrokeColor;
  final Color outlineColor;

  _CrownPainter({
    required this.fill,
    required this.fillColor,
    required this.fullStrokeColor,
    required this.outlineColor,
  });

  static Path _crown(Size size) {
    final double w = size.width;
    final double h = size.height;
    return Path()
      ..moveTo(w * 0.12, h * 0.88)
      ..lineTo(w * 0.88, h * 0.88)
      ..lineTo(w * 0.96, h * 0.24)
      ..lineTo(w * 0.70, h * 0.50)
      ..lineTo(w * 0.50, h * 0.10)
      ..lineTo(w * 0.30, h * 0.50)
      ..lineTo(w * 0.04, h * 0.24)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path crown = _crown(size);
    if (fill > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * fill, size.height));
      canvas.drawPath(crown, Paint()..color = fillColor);
      canvas.restore();
    }
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = fill >= 1 ? fullStrokeColor : outlineColor,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter old) =>
      old.fill != fill ||
      old.fillColor != fillColor ||
      old.fullStrokeColor != fullStrokeColor ||
      old.outlineColor != outlineColor;
}

/// Small pill badge, e.g. "New" on a set nobody practiced yet. The label
/// wraps instead of clipping at large font sizes.
class FoxNewBadge extends StatelessWidget {
  final String label;

  const FoxNewBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.pill)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FoxSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
