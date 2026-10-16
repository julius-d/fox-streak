// Motion + feedback language (issue #015).
//
// Rules: instant bright green/red answers, bouncy celebratory micro-moments
// (XP pop, streak-flame lit, result cheer), encouraging copy with no
// shaming (copy itself is owned by #012). Animation budget is deliberately
// tiny — one short elastic scale, no controllers to dispose
// (lottie lands in #014).
//
// Haptics/sound: [foxHapticsEnabledProvider] is the single toggle
// (default on, mutable). #005/#012 own the settings UI surface; kit effects
// check the flag before buzzing. Sound has no dep in this issue —
// [FoxFeedback] is the hook point where a sound call goes later.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Haptic + sound toggle. Default on; mutable from settings (#005/#012).
class FoxHapticsEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void setEnabled({required bool value}) => state = value;
}

final NotifierProvider<FoxHapticsEnabled, bool> foxHapticsEnabledProvider =
    NotifierProvider<FoxHapticsEnabled, bool>(FoxHapticsEnabled.new);

/// Instant answer feedback: bright banner colors (see [FoxFeedbackBanner])
/// plus an optional haptic tick. Call from check handlers, e.g.
/// `FoxFeedback.success(context, ref)`.
///
/// The [BuildContext] params are intentionally unused today — reserved for
/// future inline surfaces (e.g. a banner/snackbar hook). Haptics only need
/// the [WidgetRef].
abstract final class FoxFeedback {
  static Future<void> success(BuildContext context, WidgetRef ref) {
    return _buzz(ref, HapticFeedback.lightImpact);
  }

  static Future<void> error(BuildContext context, WidgetRef ref) {
    return _buzz(ref, HapticFeedback.heavyImpact);
  }

  static Future<void> celebrate(BuildContext context, WidgetRef ref) {
    return _buzz(ref, HapticFeedback.mediumImpact);
  }

  static Future<void> _buzz(WidgetRef ref, Future<void> Function() buzz) async {
    if (!ref.read(foxHapticsEnabledProvider)) return;
    // Sound hook: no audio dep in this issue (budget reserved for #014).
    await buzz();
  }
}

/// Bouncy celebratory wrapper for XP pops, streak-flame lits, result
/// cheers. Single 500ms elastic scale-in — no controller, no disposal.
class FoxCelebration extends StatelessWidget {
  final Widget child;

  const FoxCelebration({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (BuildContext context, double scale, Widget? kid) {
        return Transform.scale(scale: scale, child: kid);
      },
      child: child,
    );
  }
}
