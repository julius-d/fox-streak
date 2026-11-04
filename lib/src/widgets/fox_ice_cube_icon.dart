// Ice-cube icon (issue #108), replacing `Icons.ac_unit` (a snowflake)
// everywhere "streak on ice" is shown, so the concept looks identical in
// the coin shop and Home's new per-day streak icon row. Material's bundled
// icon font has no literal ice-cube glyph, so this draws one: a rounded
// square "face" in the single [color] the caller passes — same
// single-color-icon contract as `Icon` — plus a triangular corner shine
// whose own light/dark overlay is derived from [color]'s brightness, so it
// stays visible against both light-theme ice's deep blue and dark-theme
// ice's near-white pastel.
import 'package:flutter/material.dart';

class FoxIceCubeIcon extends StatelessWidget {
  final Color color;
  final double size;

  const FoxIceCubeIcon({super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _IceCubePainter(color)),
    );
  }
}

class _IceCubePainter extends CustomPainter {
  final Color color;

  // Computed once per painter instance (not per `paint()` call) — cheap,
  // but there's no reason to reallocate on every frame.
  final Paint _facePaint;
  final Paint _highlightPaint;

  _IceCubePainter(this.color)
    : _facePaint = Paint()..color = color,
      _highlightPaint = Paint()
        ..color =
            // Flips the shine between a dark or light overlay based on
            // [color]'s own brightness, so it stays visible whether
            // [color] is light-theme ice's deep blue or dark-theme ice's
            // near-white pastel — a hardcoded white highlight would all
            // but disappear on the latter.
            (ThemeData.estimateBrightnessForColor(color) == Brightness.light
                    ? Colors.black
                    : Colors.white)
                .withValues(alpha: 0.35);

  @override
  void paint(Canvas canvas, Size size) {
    final RRect face = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.shortestSide * 0.22),
    );
    canvas.drawRRect(face, _facePaint);

    final Path highlight = Path()
      ..moveTo(size.width * 0.18, size.height * 0.18)
      ..lineTo(size.width * 0.62, size.height * 0.18)
      ..lineTo(size.width * 0.18, size.height * 0.62)
      ..close();
    canvas.drawPath(highlight, _highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _IceCubePainter oldDelegate) =>
      oldDelegate.color != color;
}
