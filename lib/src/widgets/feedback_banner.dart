// Bright token-driven feedback banner (issue #015).
//
// Instant bright green/red (+ gold/blue) feedback for answers, saves, and
// imports. Colors come from [FoxSemanticColors] only — never raw colors.
// Text is [onX] on an [X] background so every variant passes AA (see the
// measured ratios in `fox_streak_theme.dart`).
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';
import 'fox_buttons.dart';

/// Banner variants. [xp] celebrates XP gains on a gold fill (dark text).
enum FoxFeedbackVariant { success, error, info, xp }

/// Friendly rounded banner with icon + message.
///
/// The message wraps (never clips) so long DE strings survive. Carries a
/// stable key for #016 hooks.
///
/// Optionally offers an action button ([actionLabel] + [onAction], #125) and
/// a close icon ([onClose] + [closeLabel] for screen readers). Both have
/// 48dp targets; on narrow widths or large fonts the action stacks below
/// the message instead of squeezing it.
class FoxFeedbackBanner extends StatelessWidget {
  final FoxFeedbackVariant variant;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;
  final String? closeLabel;

  /// Below this width, or above [_maxInlineTextScale], the action stacks.
  static const double _minInlineWidth = 360;
  static const double _maxInlineTextScale = 1.3;

  const FoxFeedbackBanner({
    super.key,
    required this.variant,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onClose,
    this.closeLabel,
  }) : icon = null,
       assert((actionLabel == null) == (onAction == null)),
       assert((onClose == null) == (closeLabel == null));

  const FoxFeedbackBanner.withIcon({
    super.key,
    required this.variant,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.onClose,
    this.closeLabel,
  }) : assert((actionLabel == null) == (onAction == null)),
       assert((onClose == null) == (closeLabel == null));

  const FoxFeedbackBanner.success({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onClose,
    this.closeLabel,
  }) : variant = FoxFeedbackVariant.success,
       icon = Icons.check_circle,
       assert((actionLabel == null) == (onAction == null)),
       assert((onClose == null) == (closeLabel == null));

  const FoxFeedbackBanner.error({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onClose,
    this.closeLabel,
  }) : variant = FoxFeedbackVariant.error,
       icon = Icons.error,
       assert((actionLabel == null) == (onAction == null)),
       assert((onClose == null) == (closeLabel == null));

  const FoxFeedbackBanner.info({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onClose,
    this.closeLabel,
  }) : variant = FoxFeedbackVariant.info,
       icon = Icons.info,
       assert((actionLabel == null) == (onAction == null)),
       assert((onClose == null) == (closeLabel == null));

  const FoxFeedbackBanner.xp({super.key, required this.message})
    : variant = FoxFeedbackVariant.xp,
      icon = Icons.star,
      actionLabel = null,
      onAction = null,
      onClose = null,
      closeLabel = null;

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
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stackAction =
                constraints.maxWidth < _minInlineWidth ||
                MediaQuery.textScalerOf(context).scale(1) > _maxInlineTextScale;
            final Widget? action = actionLabel == null
                ? null
                : FoxPrimaryButton(
                    key: const Key('foxFeedbackBannerAction'),
                    label: actionLabel!,
                    onPressed: onAction,
                    // Inverted hue: readable on any banner fill.
                    backgroundColor: fg,
                    foregroundColor: bg,
                  );
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
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
                    if (action != null && !stackAction) ...<Widget>[
                      const SizedBox(width: FoxSpacing.sm),
                      action,
                    ],
                    if (onClose != null)
                      IconButton(
                        key: const Key('foxFeedbackBannerClose'),
                        tooltip: closeLabel,
                        icon: Icon(Icons.close, color: fg),
                        constraints: const BoxConstraints(
                          minWidth: FoxButtonMetrics.minSize,
                          minHeight: FoxButtonMetrics.minSize,
                        ),
                        onPressed: onClose,
                      ),
                  ],
                ),
                if (action != null && stackAction) ...<Widget>[
                  const SizedBox(height: FoxSpacing.sm),
                  action,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
