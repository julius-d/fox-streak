// Extended-FAB label that keeps its FAB on screen (issue #133).
//
// An extended FAB is a fixed 56dp tall, so its one-line label can't wrap;
// with the largest system font on a narrow phone (German labels, e.g.
// "Marktplatz hinzufügen") it grew wider than the screen and Scaffold
// pushed the FAB past the left edge. [FoxFabLabel] caps the label at the
// width left between the FAB margins and scales it down to fit — never
// clipped, never truncated. A label that already fits renders as a plain
// `Text`.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class FoxFabLabel extends StatelessWidget {
  final String text;

  const FoxFabLabel(this.text, {super.key});

  // Extended FAB chrome beside the label: Flutter's M3 defaults (the app
  // theme doesn't override them). `SpeedDial`'s morphing FAB reuses them.
  static const double startPadding = 16;
  static const double endPadding = 20;
  static const double iconSize = 24;
  static const double iconLabelSpacing = 8;
  static const double _chrome =
      startPadding + endPadding + iconSize + iconLabelSpacing;

  @override
  Widget build(BuildContext context) {
    final maxWidth = math.max(
      0.0,
      MediaQuery.sizeOf(context).width -
          2 * kFloatingActionButtonMargin -
          _chrome,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(text)),
    );
  }
}
