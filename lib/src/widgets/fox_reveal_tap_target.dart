// Shared reward-reveal dial/animation wrapper — extracted from
// `WheelScreen`'s `_WheelDial` and `LootboxScreen`'s `_LootboxAnimation`,
// which had independently grown the exact same gating shape (issue #095).

import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Interactive-vs-revealed gating + `InkWell`/`Semantics` wrapper shared by
/// reward-reveal screens (`WheelScreen`'s dial, `LootboxScreen`'s opening
/// animation): the same shape around a different [child] visual.
///
/// When [onTap] is non-null, wraps [child] in an `InkWell` (keyed by
/// [tapKey]) plus button [Semantics] using [semanticLabel] — required in
/// that case — sized to at least `FoxButtonMetrics.minSize`. When [onTap]
/// is null, [semanticLabel] is optional: if given, [child] is wrapped in an
/// image-style [Semantics]; if omitted, [child] renders unwrapped, for a
/// caller's mid-transition state that has nothing meaningful to announce.
class FoxRevealTapTarget extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Key? tapKey;

  const FoxRevealTapTarget({
    super.key,
    required this.child,
    required this.borderRadius,
    this.onTap,
    this.semanticLabel,
    this.tapKey,
  }) : assert(
         onTap == null || semanticLabel != null,
         'semanticLabel is required when onTap is non-null',
       );

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = this.onTap;
    if (onTap == null) {
      final String? label = semanticLabel;
      if (label == null) return child;
      return Semantics(label: label, image: true, child: child);
    }

    return InkWell(
      key: tapKey,
      borderRadius: borderRadius,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: semanticLabel!,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: FoxButtonMetrics.minSize,
            minHeight: FoxButtonMetrics.minSize,
          ),
          child: child,
        ),
      ),
    );
  }
}
