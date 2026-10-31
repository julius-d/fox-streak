// GitHub-style activity calendar widget for the #084 Streak Details screen.
//
// Dumb/display-only over [ActivityCalendarData] (#084's pure window/bucket/
// streak-run logic) — callers precompute that and pass a per-day semantics
// label builder, so this widget has no data-layer or l10n dependency, same
// spirit as `StreakBadge`.
import 'package:flutter/material.dart';

import '../data/clock.dart' show parseDayString;
import '../theme/fox_streak_theme.dart';
import 'activity_calendar.dart';

/// Cell edge length (dp).
const double _kCellSize = 14;

/// Gap between cells, and between week columns.
const double _kCellGap = 3;

/// One cell per day, grouped into 7-day-tall, Sunday-first week columns
/// (oldest on the left, today on the right), horizontally scrollable with
/// the initial scroll position at today.
class ActivityCalendarView extends StatefulWidget {
  final ActivityCalendarData data;
  final String Function(ActivityDay day) cellSemanticsLabel;

  const ActivityCalendarView({
    super.key,
    required this.data,
    required this.cellSemanticsLabel,
  });

  @override
  State<ActivityCalendarView> createState() => _ActivityCalendarViewState();
}

class _ActivityCalendarViewState extends State<ActivityCalendarView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flame = foxSemantics(context).flame;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final weeks = _groupIntoWeeks(widget.data.days);
    return SizedBox(
      key: const Key('activityCalendar'),
      height: _kCellSize * 7 + _kCellGap * 6,
      child: SingleChildScrollView(
        key: const Key('activityCalendarScroll'),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final week in weeks)
              Padding(
                padding: const EdgeInsets.only(right: _kCellGap),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < week.length; i++) ...[
                      if (i > 0) const SizedBox(height: _kCellGap),
                      week[i] == null
                          ? const SizedBox(
                              width: _kCellSize,
                              height: _kCellSize,
                            )
                          : _DayCell(
                              day: week[i]!,
                              flame: flame,
                              scheme: scheme,
                              semanticsLabel: widget.cellSemanticsLabel(
                                week[i]!,
                              ),
                            ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Groups [days] (ascending) into Sunday-first week columns of exactly 7
/// cells, padding the first (partial) week with leading `null`s so every
/// day lands on its correct weekday row.
List<List<ActivityDay?>> _groupIntoWeeks(List<ActivityDay> days) {
  if (days.isEmpty) return [];
  final weeks = <List<ActivityDay?>>[];
  var currentWeek = <ActivityDay?>[];
  // DateTime.weekday: Monday=1..Sunday=7; rebase so Sunday=0..Saturday=6.
  final firstRow = parseDayString(days.first.day)!.weekday % 7;
  currentWeek.addAll(List<ActivityDay?>.filled(firstRow, null));
  for (final day in days) {
    currentWeek.add(day);
    if (currentWeek.length == 7) {
      weeks.add(currentWeek);
      currentWeek = <ActivityDay?>[];
    }
  }
  if (currentWeek.isNotEmpty) {
    currentWeek.addAll(List<ActivityDay?>.filled(7 - currentWeek.length, null));
    weeks.add(currentWeek);
  }
  return weeks;
}

class _DayCell extends StatelessWidget {
  final ActivityDay day;
  final Color flame;
  final ColorScheme scheme;
  final String semanticsLabel;

  const _DayCell({
    required this.day,
    required this.flame,
    required this.scheme,
    required this.semanticsLabel,
  });

  Border? get _highlightBorder {
    if (day.isCurrentStreak) {
      return Border.all(color: flame, width: 2);
    }
    if (day.isLongestStreak) {
      return Border.all(color: scheme.primary, width: 2);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('activityCalendarCell-${day.day}'),
      label: semanticsLabel,
      child: Container(
        width: _kCellSize,
        height: _kCellSize,
        decoration: BoxDecoration(
          color: colorForActivityLevel(
            day.level,
            flame: flame,
            emptyColor: scheme.surfaceContainerHighest,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.sm)),
          border: _highlightBorder,
        ),
      ),
    );
  }
}

/// Fill color for one [ActivityLevel] bucket: 4 tiers on the flame token's
/// alpha (issue #084) — [emptyColor] (a neutral surface tone, not flame) for
/// [ActivityLevel.none], escalating opacity otherwise. Shared by the
/// calendar cells and the legend swatches so they can never drift apart.
Color colorForActivityLevel(
  ActivityLevel level, {
  required Color flame,
  required Color emptyColor,
}) => switch (level) {
  ActivityLevel.none => emptyColor,
  ActivityLevel.low => flame.withValues(alpha: 0.3),
  ActivityLevel.medium => flame.withValues(alpha: 0.6),
  ActivityLevel.high => flame,
};
