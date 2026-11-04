// Streak badge widget, composed on the #015 kit (issue #011; per-day icon
// row added in #108).
//
// Dumb/display-only: callers pass in the streak count + whether today's
// activity is already done + the ordered per-day icon kinds — this widget
// has no data-layer dependency, so #012's Home can reuse it the same way
// #010's LessonResultScreen does.
import 'package:flutter/material.dart';

import '../theme/fox_streak_theme.dart';
import 'fox_ice_cube_icon.dart';

/// One day's render in [StreakBadge.dayIcons]: a flame for a day with
/// normal practice activity, an ice cube for a day saved by a streak-on-ice
/// (#087's `DailyActivitySource.streakOnIce`).
enum StreakDayIcon { flame, ice }

/// Edge length of each icon in [StreakBadge]'s per-day row (#108) — smaller
/// than the 18dp "today done" check so a long streak's row stays compact.
const double kStreakDayIconSize = 16;

/// Gap between adjacent icons in [StreakBadge]'s per-day row (#108).
const double kStreakDayIconGap = FoxSpacing.xs;

/// How many of [totalDays] per-day icons fit within [availableWidth] at
/// [iconSize] + [iconGap] each (issue #108's fit-to-width, crop-oldest-first
/// rule) — pure and independent of any widget so it's directly
/// unit-testable. Always at least 1 once [totalDays] >= 1, even when
/// [availableWidth] is too small or negative (the "minimum one icon
/// guaranteed" decision), and never more than [totalDays].
int visibleStreakDayIconCount({
  required int totalDays,
  required double availableWidth,
  double iconSize = kStreakDayIconSize,
  double iconGap = kStreakDayIconGap,
}) {
  if (totalDays <= 0) return 0;
  if (!availableWidth.isFinite) return totalDays;
  // n icons need n*iconSize + (n-1)*iconGap <= availableWidth, i.e.
  // n <= (availableWidth + iconGap) / (iconSize + iconGap).
  final int fit = ((availableWidth + iconGap) / (iconSize + iconGap)).floor();
  return fit.clamp(1, totalDays);
}

/// Per-day icon row (crops oldest-first to fit) + streak count + a "today
/// done" check, token-driven via [FoxSemanticColors.flame]/[ice].
class StreakBadge extends StatelessWidget {
  final int streakCount;
  final bool todayDone;
  final String streakCountLabel;
  final String? todayDoneLabel;
  final String semanticsLabel;

  /// One entry per day of the current streak, oldest first, most-recent
  /// (rightmost) last — issue #108. Decorative: never given individual
  /// semantics labels, since [semanticsLabel] already summarizes the whole
  /// badge for screen readers.
  final List<StreakDayIcon> dayIcons;

  const StreakBadge({
    super.key,
    required this.streakCount,
    required this.todayDone,
    required this.streakCountLabel,
    required this.semanticsLabel,
    required this.dayIcons,
    this.todayDoneLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Color flame = foxSemantics(context).flame;
    final Color ice = foxSemantics(context).ice;
    final TextStyle? countStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: flame, fontWeight: FontWeight.w700);

    return Semantics(
      label: semanticsLabel,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TextPainter textPainter = TextPainter(
            text: TextSpan(text: streakCountLabel, style: countStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          double reserved =
              2 * FoxSpacing.lg + // Container's own horizontal padding.
              textPainter.width;
          if (todayDone) reserved += FoxSpacing.sm + 18;
          if (dayIcons.isNotEmpty) reserved += FoxSpacing.sm;
          final int visibleCount = dayIcons.isEmpty
              ? 0
              : visibleStreakDayIconCount(
                  totalDays: dayIcons.length,
                  availableWidth: constraints.maxWidth - reserved,
                );
          final List<StreakDayIcon> visibleIcons = visibleCount == 0
              ? const []
              : dayIcons.sublist(dayIcons.length - visibleCount);

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FoxSpacing.lg,
              vertical: FoxSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: flame.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(
                Radius.circular(FoxRadius.pill),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < visibleIcons.length; i++) ...[
                  if (i > 0) const SizedBox(width: kStreakDayIconGap),
                  _StreakDayIconView(
                    icon: visibleIcons[i],
                    flame: flame,
                    ice: ice,
                  ),
                ],
                if (visibleIcons.isNotEmpty)
                  const SizedBox(width: FoxSpacing.sm),
                Text(
                  streakCountLabel,
                  key: const Key('streakCountLabel'),
                  style: countStyle,
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
          );
        },
      ),
    );
  }
}

class _StreakDayIconView extends StatelessWidget {
  final StreakDayIcon icon;
  final Color flame;
  final Color ice;

  const _StreakDayIconView({
    required this.icon,
    required this.flame,
    required this.ice,
  });

  @override
  Widget build(BuildContext context) {
    switch (icon) {
      case StreakDayIcon.flame:
        return Icon(
          Icons.local_fire_department,
          color: flame,
          size: kStreakDayIconSize,
        );
      case StreakDayIcon.ice:
        return FoxIceCubeIcon(color: ice, size: kStreakDayIconSize);
    }
  }
}
