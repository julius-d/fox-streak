// Streak-freeze icon (issue #127): the one glyph for a streak freeze —
// Material's flat snowflake, so it renders identically on every platform
// (unlike an emoji). Reverses #108's ice cube. Used by Home's per-day
// streak row, the coin shop's and Streak Details' freeze balance, and
// (via [FoxStreakFreezeIcon.iconData]) the wheel's streak-freeze slice.
// Decorative only: callers keep the accessible text next to it.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

class FoxStreakFreezeIcon extends StatelessWidget {
  /// The snowflake glyph, for painters that can't host a widget (the
  /// wheel's `WheelPainter`).
  static const IconData iconData = Icons.ac_unit;

  /// Defaults to the theme's icy-blue [FoxSemanticColors.ice].
  final Color? color;
  final double size;

  const FoxStreakFreezeIcon({super.key, this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconData,
      color: color ?? foxSemantics(context).ice,
      size: size,
    );
  }
}
