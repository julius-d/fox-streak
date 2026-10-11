// Fixed icon map for the three item types (issue #003), tinted with #015
// semantic tokens (no raw colors).

import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Icon for an item `type` (`vocab|phone|date`).
IconData iconForItemType(String type) {
  switch (type) {
    case 'vocab':
      return Icons.translate;
    case 'phone':
      return Icons.phone;
    case 'date':
      return Icons.cake;
    default:
      return Icons.help_outline;
  }
}

/// Token-driven tint for an item `type` icon.
///
/// Vocab leans info blue, phone leans success green, birthdays lean streak
/// flame; unknown types fall back to the surface ink. All pairs are AA on
/// both themes (see `fox_streak_theme.dart`).
Color colorForItemType(BuildContext context, String type) {
  final FoxSemanticColors tokens = foxSemantics(context);
  switch (type) {
    case 'vocab':
      return tokens.info;
    case 'phone':
      return tokens.success;
    case 'date':
      return tokens.flame;
    default:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}
