// Bright token-driven feedback banner (issue #015).
//
// Instant bright green/red (+ gold/blue) feedback for answers, saves, and
// imports. Colors come from [FoxSemanticColors] only — never raw colors.
// Text is [onX] on an [X] background so every variant passes AA (see the
// measured ratios in `fox_streak_theme.dart`).
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Banner variants. [xp] celebrates XP gains on a gold fill (dark text).
enum FoxFeedbackVariant { success, error, info, xp }

/// Friendly rounded banner with icon + message.
///
/// The message wraps (never clips) so long DE strings survive. Carries a
/// stable key for #016 hooks.
class FoxFeedbackBanner extends StatelessWidget {
  final FoxFeedbackVariant variant;
  final String message;
  final IconData? icon;

  const FoxFeedbackBanner({
    super.key,
    required this.variant,
    required this.message,
  }) : icon = null;

  const FoxFeedbackBanner.withIcon({
    super.key,
    required this.variant,
    required this.message,
    required this.icon,
  });

  const FoxFeedbackBanner.success({super.key, required this.message})
    : variant = FoxFeedbackVariant.success,
      icon = Icons.check_circle;

  const FoxFeedbackBanner.error({super.key, required this.message})
    : variant = FoxFeedbackVariant.error,
      icon = Icons.error;

  const FoxFeedbackBanner.info({super.key, required this.message})
    : variant = FoxFeedbackVariant.info,
      icon = Icons.info;

  const FoxFeedbackBanner.xp({super.key, required this.message})
    : variant = FoxFeedbackVariant.xp,
      icon = Icons.star;

  @override
  Widget build(BuildContext context) {
    final FoxSemanticColors tokens = foxSemantics(context);
    final TextTheme text = Theme.of(context).textTheme;
    final (Color bg, Color fg) = switch (variant) {
      FoxFeedbackVariant.success => (tokens.success, tokens.onSuccess),
      FoxFeedbackVariant.error => (tokens.error, tokens.onError),
      FoxFeedbackVariant.info => (tokens.info, tokens.onInfo),
      FoxFeedbackVariant.xp => (tokens.gold, tokens.onGold),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: FoxButtonMetrics.minSize),
        padding: const EdgeInsets.symmetric(
          horizontal: FoxSpacing.lg,
          vertical: FoxSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.md)),
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: FoxSpacing.sm),
            ],
            Expanded(
              child: Text(
                message,
                softWrap: true,
                style: text.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
