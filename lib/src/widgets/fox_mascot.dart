// Fox mascot placeholder + placement/state rules (issue #015).
//
// The fox plays the Duolingo-owl role: it appears in empty states, result
// celebrations, and streak moments — never as decoration sprinkled at
// random. Canonical states (shared with #011): `empty | lit | on-fire`.
// - `empty`: fox is greyed out / sleepy — no sets yet, no activity today.
// - `lit`: fox is bright and happy — activity done, streak alive.
// - `on-fire`: fox celebrates with flame — streak milestone / result cheer.
//
// Where the fox may appear: [FoxEmptyState] headers, result/celebration
// surfaces (#005–#009), streak widgets (#011), onboarding (#012). Nowhere
// else without a design reason.
//
// Placeholder: [FoxMascot] is vector-drawn (no binary asset, no new deps,
// so the iOS + Windows + Android 3-platform rule holds). Final art is
// explicitly out of this issue and swaps in behind this same widget API.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Canonical fox states, shared with the #011 streak system.
enum FoxMascotState {
  /// Greyed out / sleepy: nothing here yet.
  empty,

  /// Bright and happy: activity done, streak alive.
  lit,

  /// Celebrating with flame: milestone / result cheer.
  onFire,
}

/// Placeholder fox mascot (vector-drawn; final art swaps in here later).
///
/// Always provide [semanticLabel] (or null for purely decorative repeats
/// next to a labelled heading) so screen readers announce the moment.
class FoxMascot extends StatelessWidget {
  final FoxMascotState state;
  final double size;
  final String? semanticLabel;

  const FoxMascot({
    super.key,
    required this.state,
    this.size = 96,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final FoxSemanticColors tokens = foxSemantics(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color face = switch (state) {
      FoxMascotState.empty => scheme.surfaceContainerHighest,
      FoxMascotState.lit => scheme.primaryContainer,
      FoxMascotState.onFire => scheme.primaryContainer,
    };
    final Color glow = switch (state) {
      FoxMascotState.empty => scheme.outlineVariant,
      FoxMascotState.lit => scheme.primary,
      FoxMascotState.onFire => tokens.flame,
    };
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: SizedBox(
        key: Key('foxMascot-${state.name}'),
        width: size,
        height: size,
        child: CustomPaint(
          painter: _FoxPainter(face: face, glow: glow, lit: state),
        ),
      ),
    );
  }
}

/// Minimal geometric fox face: round head, two ears, closed happy eyes.
///
/// Deliberately simple — a stand-in until final art lands. States differ
/// by tint + flame mark, so state is never color-only (a11y).
class _FoxPainter extends CustomPainter {
  final Color face;
  final Color glow;
  final FoxMascotState lit;

  _FoxPainter({required this.face, required this.glow, required this.lit});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Paint fill = Paint()..color = face;
    final Paint edge = Paint()
      ..color = glow
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045;
    final Paint dark = Paint()..color = glow;

    // Head.
    canvas.drawCircle(Offset(s / 2, s * 0.56), s * 0.34, fill);
    canvas.drawCircle(Offset(s / 2, s * 0.56), s * 0.34, edge);
    // Ears.
    for (final double dx in <double>[-1, 1]) {
      final Path ear = Path()
        ..moveTo(s / 2 + dx * s * 0.18, s * 0.32)
        ..lineTo(s / 2 + dx * s * 0.36, s * 0.08)
        ..lineTo(s / 2 + dx * s * 0.38, s * 0.36)
        ..close();
      canvas.drawPath(ear, fill);
      canvas.drawPath(ear, edge);
    }
    // Eyes: happy arcs when lit/on-fire, sleepy dots when empty.
    for (final double dx in <double>[-1, 1]) {
      final Offset c = Offset(s / 2 + dx * s * 0.13, s * 0.56);
      if (lit == FoxMascotState.empty) {
        canvas.drawCircle(c, s * 0.028, dark);
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: s * 0.06),
          3.5,
          2.4,
          false,
          dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.035,
        );
      }
    }
    // Snout.
    canvas.drawCircle(Offset(s / 2, s * 0.68), s * 0.05, dark);
    // Flame mark for the on-fire state (never color-only).
    if (lit == FoxMascotState.onFire) {
      final Path flame = Path()
        ..moveTo(s * 0.78, s * 0.34)
        ..quadraticBezierTo(s * 0.86, s * 0.2, s * 0.78, s * 0.06)
        ..quadraticBezierTo(s * 0.76, s * 0.2, s * 0.68, s * 0.22)
        ..quadraticBezierTo(s * 0.72, s * 0.3, s * 0.78, s * 0.34)
        ..close();
      canvas.drawPath(flame, dark..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _FoxPainter old) {
    return old.face != face || old.glow != glow || old.lit != lit;
  }
}
