// Shared reveal-hint button — exercise card cleanup (issue #027).
//
// Extracted from the eye-icon reveal-hint `IconButton` copy-pasted across
// `dial_pad_exercise.dart` (#008), `free_text_exercise.dart` (#007), and
// `date_exercise.dart` (#009). Callers keep their own reveal/disable logic
// (auto-hide-after-2s vs. disabled-after-use) and just pass [onPressed].

import 'package:flutter/material.dart';

/// Eye-icon button that reveals a hint for the current exercise item.
///
/// Pass `onPressed: null` to render it disabled (free-text's
/// disabled-after-use style); omit it entirely from the tree instead if a
/// card hides the button while the hint is showing (dial pad, date).
class FoxRevealHintButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;

  const FoxRevealHintButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: const Icon(Icons.visibility_outlined),
      tooltip: tooltip,
      onPressed: onPressed,
      color: scheme.primary,
    );
  }
}
