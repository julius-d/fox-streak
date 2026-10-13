// Streak badge widget, composed on the #015 kit (issue #011).
//
// Dumb/display-only: callers pass in the streak count + whether today's
// activity is already done — this widget has no data-layer dependency, so
// #012's Home can reuse it the same way #010's LessonResultScreen does.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';

/// Flame icon + streak count + a "today done" check, token-driven via
/// [FoxSemanticColors.flame].
class StreakBadge extends StatelessWidget {
  final int streakCount;
  final bool todayDone;
  final String streakCountLabel;
  final String? todayDoneLabel;
  final String semanticsLabel;

  const StreakBadge({
    super.key,
    required this.streakCount,
    required this.todayDone,
    required this.streakCountLabel,
    required this.semanticsLabel,
    this.todayDoneLabel,
  });

  @override
  Widget build(BuildContext context) {
    final flame = foxSemantics(context).flame;
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FoxSpacing.lg,
          vertical: FoxSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: flame.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.pill)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, color: flame),
            const SizedBox(width: FoxSpacing.sm),
            Text(
              streakCountLabel,
              key: const Key('streakCountLabel'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: flame, fontWeight: FontWeight.w700),
            ),
            if (todayDone) ...[
              const SizedBox(width: FoxSpacing.sm),
              Icon(
                Icons.check_circle,
                color: flame,
                size: 18,
                semanticLabel: todayDoneLabel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
