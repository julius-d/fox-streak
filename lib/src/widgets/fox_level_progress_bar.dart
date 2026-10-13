// Level-progress widget, composed on FoxProgressBar (issue #010).
//
// Dumb/display-only: callers precompute level/progress/label text (via
// XpService's formulas) and pass them in — this widget has no data-layer
// dependency, so #012's Home can reuse it the same way #010's
// LessonResultScreen does.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';
import 'fox_progress_bar.dart';

/// Gold-filled [FoxProgressBar] topped with a "Level N" label and a numeric
/// progress-to-next-level line underneath.
class FoxLevelProgressBar extends StatelessWidget {
  final int level;
  final double progress;
  final String levelLabel;
  final String progressText;
  final String semanticsLabel;

  const FoxLevelProgressBar({
    super.key,
    required this.level,
    required this.progress,
    required this.levelLabel,
    required this.progressText,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).extension<FoxSemanticColors>()!.gold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(levelLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: FoxSpacing.xs),
        FoxProgressBar(
          value: progress,
          color: gold,
          semanticsLabel: semanticsLabel,
          semanticsValue: progressText,
        ),
        const SizedBox(height: FoxSpacing.xs),
        Text(progressText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
