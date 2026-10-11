// Chunky rounded playful buttons — Duolingo-style kit (issue #015).
//
// Material 3 governs standard components; the chunky 3D press-feel lives
// only here, never as one-off screen styling. All three buttons:
// - guarantee a 48dp minimum target,
// - use bold labels that wrap (max 3 lines) or ellipsize — never clip, so
//   long DE labels survive narrow screens,
// - carry stable keys via [Key] params for the #016 e2e hooks.
//
// [FoxCheckButton] is the full-width lesson check button (#005–#009 reuse
// it instead of building their own).
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Label that wraps long translations instead of clipping them.
Widget _foxLabel(String label, TextStyle? style) {
  return Text(
    label,
    textAlign: TextAlign.center,
    softWrap: true,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}

/// Hard-shadow wrapper giving the Duolingo-style 3D press feel.
///
/// A static 4dp offset shadow in the button's own hue — cheap to build
/// (no animation controllers), so it stays inside the #014 animation
/// budget. Disabled buttons drop the shadow.
Widget _foxShadow({
  required BuildContext context,
  required Color shadow,
  required bool enabled,
  required Widget child,
}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.all(
        Radius.circular(FoxButtonMetrics.radius),
      ),
      boxShadow: enabled
          ? <BoxShadow>[
              BoxShadow(
                color: shadow,
                offset: const Offset(0, FoxButtonMetrics.shadowOffset),
              ),
            ]
          : null,
    ),
    child: child,
  );
}

/// Primary chunky button (filled, hard shadow).
///
/// Set [expanded] for full-width form saves; otherwise the button hugs its
/// content while keeping the 48dp minimum. [isLoading] swaps the label for
/// a spinner and disables presses.
class FoxPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool isLoading;
  final IconData? icon;

  /// Optional hue override (e.g. error red for destructive confirms).
  /// Defaults to the theme primary. Foreground follows automatically.
  final Color? backgroundColor;
  final Color? foregroundColor;

  const FoxPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = false,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool enabled = onPressed != null && !isLoading;
    final Widget child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20),
                const SizedBox(width: FoxSpacing.sm),
              ],
              Flexible(child: _foxLabel(label, text.labelLarge)),
            ],
          );
    final ButtonStyle style = FilledButton.styleFrom(
      minimumSize: expanded
          ? const Size(double.infinity, FoxButtonMetrics.minSize)
          : const Size(FoxButtonMetrics.minSize, FoxButtonMetrics.minSize),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: _foxShadow(
        context: context,
        shadow: (backgroundColor ?? scheme.primary).withValues(alpha: 0.45),
        enabled: enabled,
        child: FilledButton(
          style: style,
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      ),
    );
  }
}

/// Secondary chunky button (outlined, hard shadow).
class FoxSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  const FoxSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool enabled = onPressed != null;
    final ButtonStyle style = OutlinedButton.styleFrom(
      minimumSize: expanded
          ? const Size(double.infinity, FoxButtonMetrics.minSize)
          : const Size(FoxButtonMetrics.minSize, FoxButtonMetrics.minSize),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: _foxShadow(
        context: context,
        shadow: scheme.outlineVariant,
        enabled: enabled,
        child: OutlinedButton(
          style: style,
          onPressed: onPressed,
          child: _foxLabel(label, text.labelLarge),
        ),
      ),
    );
  }
}

/// Full-width lesson check button (#005–#009 exercise shells reuse this).
///
/// Taller than the 48dp floor (56dp) for thumb reach at the screen bottom;
/// [correctState] tints it green/red for instant bright feedback after a
/// check (null while answering).
class FoxCheckButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool? correctState;

  const FoxCheckButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.correctState,
  });

  @override
  Widget build(BuildContext context) {
    final FoxSemanticColors tokens = foxSemantics(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool enabled = onPressed != null;
    final Color? bg = switch (correctState) {
      true => tokens.success,
      false => tokens.error,
      null => null,
    };
    final Color? fg = switch (correctState) {
      true => tokens.onSuccess,
      false => tokens.onError,
      null => null,
    };
    final ButtonStyle style = FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 56),
      backgroundColor: bg,
      foregroundColor: fg,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: FilledButton(
        style: style,
        onPressed: onPressed,
        child: _foxLabel(label, text.labelLarge),
      ),
    );
  }
}
