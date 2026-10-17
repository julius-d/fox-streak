// Fixed icon map for items (issue #003; `choice`/`freeText` split from the
// original `vocab` by #026), tinted with #015 semantic tokens (no raw
// colors). `choice`/`freeText` are keyed by the set's `category` (#045),
// not by `type` — a single translate icon for every non-vocab set (e.g.
// math facts, geography capitals) was misleading; `phone`/`date` stay keyed
// by `type`, since that distinction is still meaningful per item.

import 'package:flutter/material.dart';

import '../data/validation.dart';
import '../theme/fox_streak_theme.dart';

/// Icon for an item `type` (`choice|freeText|phone|date`); `choice`/
/// `freeText` defer to [iconForSetCategory] using the owning set's
/// `category` (`null` treated as `vocab`).
IconData iconForItemType(String type, String? category) {
  switch (type) {
    case 'choice':
    case 'freeText':
      return iconForSetCategory(category);
    case 'phone':
      return Icons.phone;
    case 'date':
      return Icons.cake;
    default:
      return Icons.help_outline;
  }
}

/// Icon for a set `category` (`vocab|general|math|geography`, `null`
/// treated as `vocab`).
IconData iconForSetCategory(String? category) {
  switch (effectiveSetCategory(category)) {
    case 'math':
      return Icons.calculate;
    case 'geography':
      return Icons.public;
    case 'general':
      return Icons.quiz;
    default:
      return Icons.translate;
  }
}

/// Token-driven tint for an item `type` icon.
///
/// `phone` leans success green, birthdays lean streak flame; unknown types
/// fall back to the surface ink. `choice`/`freeText` defer to
/// [colorForSetCategory]. All pairs are AA on both themes (see
/// `fox_streak_theme.dart`).
Color colorForItemType(BuildContext context, String type, String? category) {
  final FoxSemanticColors tokens = foxSemantics(context);
  switch (type) {
    case 'choice':
    case 'freeText':
      return colorForSetCategory(context, category);
    case 'phone':
      return tokens.success;
    case 'date':
      return tokens.flame;
    default:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// Token-driven tint for a set `category` icon (`null` treated as `vocab`).
///
/// `vocab` leans info blue (unchanged); `math`/`geography` get their own AA
/// pairs; `general` is a catch-all and shares the surface-ink fallback.
Color colorForSetCategory(BuildContext context, String? category) {
  final FoxSemanticColors tokens = foxSemantics(context);
  switch (effectiveSetCategory(category)) {
    case 'math':
      return tokens.math;
    case 'geography':
      return tokens.geography;
    case 'general':
      return Theme.of(context).colorScheme.onSurfaceVariant;
    default:
      return tokens.info;
  }
}
