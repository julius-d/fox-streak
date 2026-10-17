// Level-progress widget, composed on FoxProgressBar (issue #010; animated
// level-up fill added by #053).
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
///
/// [levelUpAnimateFrom], when non-null, is the previous level's progress
/// (0..1) immediately before this lesson's XP crossed a level boundary: the
/// bar animates from there up to 100% then resets to 0 and animates up to
/// [progress] for the new level (issue #053), instead of the plain instant
/// fill used on every other (non-level-up) render.
class FoxLevelProgressBar extends StatelessWidget {
  final int level;
  final double progress;
  final String levelLabel;
  final String progressText;
  final String semanticsLabel;
  final double? levelUpAnimateFrom;

  const FoxLevelProgressBar({
    super.key,
    required this.level,
    required this.progress,
    required this.levelLabel,
    required this.progressText,
    required this.semanticsLabel,
    this.levelUpAnimateFrom,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).extension<FoxSemanticColors>()!.gold;
    final animateFrom = levelUpAnimateFrom;
    final bar = animateFrom == null
        ? FoxProgressBar(
            value: progress,
            color: gold,
            semanticsLabel: semanticsLabel,
            semanticsValue: progressText,
          )
        : _LevelUpFillAnimation(
            from: animateFrom,
            to: progress,
            color: gold,
            semanticsLabel: semanticsLabel,
            semanticsValue: progressText,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(levelLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: FoxSpacing.xs),
        bar,
        const SizedBox(height: FoxSpacing.xs),
        Text(progressText, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Fills to 100% then resets to 0 and fills up to [to] — two independent
/// [TweenSequenceItem]s rather than one continuous tween, since the bar
/// genuinely jumps at the level boundary (issue #053).
class _LevelUpFillAnimation extends StatefulWidget {
  final double from;
  final double to;
  final Color color;
  final String? semanticsLabel;
  final String? semanticsValue;

  const _LevelUpFillAnimation({
    required this.from,
    required this.to,
    required this.color,
    this.semanticsLabel,
    this.semanticsValue,
  });

  @override
  State<_LevelUpFillAnimation> createState() => _LevelUpFillAnimationState();
}

class _LevelUpFillAnimationState extends State<_LevelUpFillAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _value = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: widget.from.clamp(0, 1).toDouble(), end: 1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: widget.to.clamp(0, 1).toDouble()),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const Key('levelUpProgressAnimation'),
      animation: _value,
      builder: (context, _) => FoxProgressBar(
        value: _value.value,
        color: widget.color,
        semanticsLabel: widget.semanticsLabel,
        semanticsValue: widget.semanticsValue,
      ),
    );
  }
}
