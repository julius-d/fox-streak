// Painting for the wheel-of-fortune dial (issue #117 restyle of #085's flat
// disc): soft shadow, rim with small lights, slice dividers, radial labels
// and a hub — plus the win-moment treatment (winning slice pulses, the
// others dim).
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// AA contrast for normal text — the floor dimmed slice labels must keep.
const double kWheelMinLabelContrast = 4.5;

/// The fill + label colors of a slice dimmed into the background.
typedef WheelDimmedColors = ({Color fill, Color label});

/// Blends [fill] towards [surface] until either [onFill] or [onSurface] reads
/// on it with at least [kWheelMinLabelContrast]. At a full blend the fill is
/// [surface] itself, where [onSurface] is the theme's own text color, so the
/// loop always terminates with a legible pair.
WheelDimmedColors wheelDimmedColors({
  required Color fill,
  required Color onFill,
  required Color surface,
  required Color onSurface,
}) {
  for (double amount = 0.55; amount < 1; amount += 0.05) {
    final Color dimmed = Color.lerp(fill, surface, amount)!;
    for (final Color label in <Color>[onFill, onSurface]) {
      if (_contrast(label, dimmed) >= kWheelMinLabelContrast) {
        return (fill: dimmed, label: label);
      }
    }
  }
  return (fill: surface, label: onSurface);
}

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// What one wheel slice shows: a text label (a coin amount) or an icon glyph
/// (the streak-freeze snowflake, #127). Both are drawn in the slice's
/// contrasting foreground color.
sealed class WheelSliceLabel {
  const WheelSliceLabel();
}

final class WheelTextLabel extends WheelSliceLabel {
  final String text;

  const WheelTextLabel(this.text);
}

final class WheelIconLabel extends WheelSliceLabel {
  final IconData icon;

  const WheelIconLabel(this.icon);
}

/// Paints `labels.length` equal pie slices. Slice `0` starts at the top
/// (12 o'clock) and slices proceed clockwise — `wheelTargetRotationTurns`
/// relies on this exact layout.
///
/// When [winningIndex] is non-null the wheel is in its win moment: that
/// slice is drawn at full colors, grown by up to [pulseGrowth] of the radius
/// following [pulse], and every other slice is dimmed (see
/// [wheelDimmedColors]).
class WheelPainter extends CustomPainter {
  WheelPainter({
    required this.labels,
    required this.sliceColors,
    required this.onSliceColors,
    required this.textStyle,
    required this.rimColor,
    required this.rimLightColor,
    required this.dividerColor,
    required this.hubColor,
    required this.shadowColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
    this.winningIndex,
    this.pulse,
  }) : assert(
         sliceColors.length == labels.length &&
             onSliceColors.length == labels.length,
         'sliceColors/onSliceColors must have one entry per labels entry '
         '(labels: ${labels.length}, sliceColors: ${sliceColors.length}, '
         'onSliceColors: ${onSliceColors.length})',
       ),
       super(repaint: pulse);

  static const int rimLightCount = 14;
  static const double rimWidthFraction = 0.09;
  static const double pulseGrowth = 0.05;

  /// An icon label's size relative to [textStyle]'s font size — a glyph
  /// at text size reads smaller than the bold digits beside it.
  static const double iconLabelScale = 1.25;

  final List<WheelSliceLabel> labels;
  final List<Color> sliceColors;
  final List<Color> onSliceColors;
  final TextStyle textStyle;
  final Color rimColor;
  final Color rimLightColor;
  final Color dividerColor;
  final Color hubColor;
  final Color shadowColor;
  final Color surfaceColor;
  final Color onSurfaceColor;
  final int? winningIndex;
  final Animation<double>? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    // Leave a margin outside the rim for the shadow.
    final double outer = size.shortestSide / 2 - size.shortestSide * 0.03;
    final double rim = outer * rimWidthFraction * 2;
    final double inner = outer - rim;
    final double sliceAngle = 2 * math.pi / labels.length;

    canvas.drawCircle(
      center + Offset(0, outer * 0.04),
      outer,
      Paint()
        ..color = shadowColor.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, outer * 0.06),
    );
    canvas.drawCircle(center, outer, Paint()..color = rimColor);

    final double pulseValue = pulse?.value ?? 0;
    for (var i = 0; i < labels.length; i++) {
      final bool winning = i == winningIndex;
      final bool dimmed = winningIndex != null && !winning;
      final double radius = winning
          ? inner * (1 + pulseGrowth * pulseValue)
          : inner;
      final WheelDimmedColors? dim = dimmed
          ? wheelDimmedColors(
              fill: sliceColors[i],
              onFill: onSliceColors[i],
              surface: surfaceColor,
              onSurface: onSurfaceColor,
            )
          : null;
      final double startAngle = -math.pi / 2 + i * sliceAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        Paint()..color = dim?.fill ?? sliceColors[i],
      );
      _paintLabel(
        canvas,
        center,
        radius,
        startAngle + sliceAngle / 2,
        labels[i],
        dim?.label ?? onSliceColors[i],
      );
    }

    final Paint divider = Paint()
      ..color = dividerColor
      ..strokeWidth = math.max(1.5, inner * 0.015);
    for (var i = 0; i < labels.length; i++) {
      final double angle = -math.pi / 2 + i * sliceAngle;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        divider,
      );
    }

    final Paint light = Paint()..color = rimLightColor;
    final double lightRadius = rim * 0.2;
    for (var i = 0; i < rimLightCount; i++) {
      final double angle = 2 * math.pi * i / rimLightCount;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * (inner + rim / 2),
        lightRadius,
        light,
      );
    }

    canvas.drawCircle(center, inner * 0.16, Paint()..color = rimColor);
    canvas.drawCircle(center, inner * 0.11, Paint()..color = hubColor);
  }

  /// Draws [label] along the slice direction, reading from the hub outwards.
  void _paintLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    WheelSliceLabel label,
    Color color,
  ) {
    final TextPainter painter = TextPainter(
      text: _spanFor(label, color),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle);
    painter.paint(
      canvas,
      Offset(radius * 0.7 - painter.width / 2, -painter.height / 2),
    );
    canvas.restore();
  }

  TextSpan _spanFor(WheelSliceLabel label, Color color) => switch (label) {
    WheelTextLabel(text: final text) => TextSpan(
      text: text,
      style: textStyle.copyWith(color: color),
    ),
    // Same font setup the `Icon` widget uses to render an [IconData].
    WheelIconLabel(icon: final icon) => TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        inherit: false,
        color: color,
        fontSize: (textStyle.fontSize ?? 16) * iconLabelScale,
        fontFamily: icon.fontFamily,
        fontFamilyFallback: icon.fontFamilyFallback,
        package: icon.fontPackage,
        height: 1,
      ),
    ),
  };

  // Every input is rebuilt per frame of the parent anyway; a cheap repaint
  // beats a field-by-field comparison that silently misses new fields.
  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) => true;
}
