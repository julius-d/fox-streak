// Fixed icon map for the item types (issue #003; `choice`/`freeText` split
// from the original `vocab` by #026), tinted with #015 semantic tokens (no
// raw colors).

import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Icon for an item `type` (`choice|freeText|phone|date`).
///
/// `choice` and `freeText` are both vocab-flavored (#026 split of #002's
/// `vocab`) and share the same translate icon — no new art needed.
IconData iconForItemType(String type) {
  switch (type) {
    case 'choice':
    case 'freeText':
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
/// Vocab-flavored types (`choice`/`freeText`) lean info blue, phone leans
/// success green, birthdays lean streak flame; unknown types fall back to
/// the surface ink. All pairs are AA on both themes (see
/// `fox_streak_theme.dart`).
Color colorForItemType(BuildContext context, String type) {
  final FoxSemanticColors tokens = foxSemantics(context);
  switch (type) {
    case 'choice':
    case 'freeText':
      return tokens.info;
    case 'phone':
      return tokens.success;
    case 'date':
      return tokens.flame;
    default:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}
