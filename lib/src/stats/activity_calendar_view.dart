// GitHub-style activity calendar widget for the #084 Streak Details screen.
//
// Dumb/display-only over [ActivityCalendarData] (#084's pure window/bucket/
// streak-run logic) — callers precompute that and pass a per-day semantics
// label builder, so this widget has no l10n (`AppLocalizations`) dependency,
// same spirit as `StreakBadge`. It does read the ambient `Localizations`
// locale directly (via `intl`) to render locale-aware weekday/month header
// letters (#089) — decorative only, excluded from the semantics tree.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/clock.dart' show parseDayString;
import '../theme/fox_streak_theme.dart';
import 'activity_calendar.dart';

/// Cell edge length (dp).
const double _kCellSize = 14;

/// Gap between cells, and between week columns.
const double _kCellGap = 3;

/// Width of the weekday-letter column, and height of the month-label row.
const double _kHeaderSize = 14;

/// Gap between the header labels and the grid they annotate.
const double _kHeaderGap = 4;

/// Shared compact style for the decorative weekday/month header labels —
/// smaller than `labelSmall` so a 3-letter month abbreviation or a weekday
/// letter fits the dense `_kCellSize`-based grid without clipping.
TextStyle _headerLabelStyle(BuildContext context) => TextStyle(
  fontSize: 9,
  height: 1,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

/// An arbitrary Sunday, used only to look up locale-aware weekday names —
/// only its weekday (not its date) matters.
final DateTime _kReferenceSunday = DateTime(2023, 1, 1);

/// Which streak a highlighted run of days belongs to — drives both the
/// highlight color and whether a run connects across a week-column
/// boundary (only same-kind runs connect).
enum _HighlightKind { current, longest }

/// One connected highlight shape spanning the contiguous cells
/// `[startRow, endRow]` (inclusive) of week-column [column].
class _HighlightSegment {
  final int column;
  final int startRow;
  final int endRow;
  final _HighlightKind kind;
  final String firstDay;

  const _HighlightSegment({
    required this.column,
    required this.startRow,
    required this.endRow,
    required this.kind,
    required this.firstDay,
  });
}

/// A short bridge between the bottom (Saturday) cell of week-column
/// [column] and the top (Sunday) cell of week-column `column + 1`, drawn
/// when a run of the same [kind] crosses that boundary.
class _Connector {
  final int column;
  final _HighlightKind kind;

  const _Connector({required this.column, required this.kind});
}

/// One cell per day, grouped into 7-day-tall, Sunday-first week columns
/// (oldest on the left, today on the right), horizontally scrollable with
/// the initial scroll position at today. Sparse weekday letters (Mon/Wed/
/// Fri only) sit in a fixed column to the left; month abbreviations sit in
/// a row above the grid that scrolls together with it (#089).
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
    final ice = foxSemantics(context).ice;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toString();
    final weeks = _groupIntoWeeks(widget.data.days);
    const double gridHeight = _kCellSize * 7 + _kCellGap * 6;
    return SizedBox(
      key: const Key('activityCalendar'),
      height: _kHeaderSize + _kHeaderGap + gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: _WeekdayLabelColumn(locale: locale)),
          const SizedBox(width: _kHeaderGap),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('activityCalendarScroll'),
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: _MonthLabelsRow(weeks: weeks, locale: locale),
                  ),
                  const SizedBox(height: _kHeaderGap),
                  _CalendarGrid(
                    weeks: weeks,
                    flame: flame,
                    ice: ice,
                    scheme: scheme,
                    cellSemanticsLabel: widget.cellSemanticsLabel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed (non-scrolling) column to the left of the grid: a locale-aware
/// narrow weekday letter on the Mon/Wed/Fri rows only — Sun/Tue/Thu/Sat
/// rows are blank (#089's decision: labeling every row repeats letters in
/// several locales, e.g. German Mo/Mi both narrow to "M").
class _WeekdayLabelColumn extends StatelessWidget {
  final String locale;

  const _WeekdayLabelColumn({required this.locale});

  static const List<int> _labeledRows = [1, 3, 5];

  @override
  Widget build(BuildContext context) {
    final DateFormat format = DateFormat.EEEEE(locale);
    final style = _headerLabelStyle(context);
    return SizedBox(
      width: _kHeaderSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: _kHeaderSize + _kHeaderGap),
          for (var row = 0; row < 7; row++) ...[
            if (row > 0) const SizedBox(height: _kCellGap),
            SizedBox(
              width: _kCellSize,
              height: _kCellSize,
              child: _labeledRows.contains(row)
                  ? Center(
                      child: Text(
                        format.format(
                          DateTime(
                            _kReferenceSunday.year,
                            _kReferenceSunday.month,
                            _kReferenceSunday.day + row,
                          ),
                        ),
                        style: style,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// Scrolls together with the grid: a 3-letter, locale-aware month
/// abbreviation positioned above the first week-column in which that month
/// starts (#089), absolutely placed (not laid out per-column) so the text
/// isn't clipped to one cell's width.
class _MonthLabelsRow extends StatelessWidget {
  final List<List<ActivityDay?>> weeks;
  final String locale;

  const _MonthLabelsRow({required this.weeks, required this.locale});

  @override
  Widget build(BuildContext context) {
    final DateFormat format = DateFormat.MMM(locale);
    final labels = _computeMonthLabels(weeks);
    final style = _headerLabelStyle(context);
    bool isLastColumn(int col) => col == weeks.length - 1;
    return SizedBox(
      height: _kHeaderSize,
      width: weeks.length * (_kCellSize + _kCellGap),
      child: Stack(
        children: [
          for (final entry in labels.entries)
            // Every column but the last has at least one more column's
            // worth of header space to its right for the label to bleed
            // into (harmless, since that space is otherwise blank) — the
            // Stack's own bounds end exactly at the last column's right
            // edge, so a label anchored there by its *left* edge would get
            // hard-clipped mid-glyph instead. Anchoring by the *right*
            // edge instead grows the label leftward, which always has
            // room (bleeding into the previous column's header space).
            if (isLastColumn(entry.key))
              Positioned(
                right: 0,
                top: 0,
                child: Text(format.format(entry.value), style: style),
              )
            else
              Positioned(
                left: entry.key * (_kCellSize + _kCellGap),
                top: 0,
                child: Text(format.format(entry.value), style: style),
              ),
        ],
      ),
    );
  }
}

/// For each week-column whose topmost day falls in a different calendar
/// month than the previous column's topmost day, that column's index
/// mapped to the new month's date — one label per column by construction,
/// so two months can never contend for the same column (GitHub-style: a
/// month's exact first day can fall mid-column, in which case its label
/// lands on the following column instead — a UI-polish approximation of
/// "where that month starts", not a contract).
Map<int, DateTime> _computeMonthLabels(List<List<ActivityDay?>> weeks) {
  final labels = <int, DateTime>{};
  int? lastMonthKey;
  for (var col = 0; col < weeks.length; col++) {
    final ActivityDay? firstDay = weeks[col].firstWhere(
      (d) => d != null,
      orElse: () => null,
    );
    if (firstDay == null) continue;
    final date = parseDayString(firstDay.day)!;
    final monthKey = date.year * 12 + date.month;
    if (monthKey != lastMonthKey) {
      labels[col] = date;
      lastMonthKey = monthKey;
    }
  }
  return labels;
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

/// The highlight kind a day's cell renders with — current-streak takes
/// precedence over longest-in-window, same precedence #084's removed
/// per-cell `_highlightBorder` getter used. `null` for an unhighlighted or
/// padding (`null`) day.
_HighlightKind? _kindOf(ActivityDay? day) {
  if (day == null) return null;
  if (day.isCurrentStreak) return _HighlightKind.current;
  if (day.isLongestStreak) return _HighlightKind.longest;
  return null;
}

/// One [_HighlightSegment] per maximal run of same-kind highlighted cells
/// within a single week-column (a run can only be vertically contiguous
/// within a column; crossing into the next column is handled separately by
/// [_computeConnectors]).
List<_HighlightSegment> _computeHighlightSegments(
  List<List<ActivityDay?>> weeks,
) {
  final segments = <_HighlightSegment>[];
  for (var col = 0; col < weeks.length; col++) {
    final week = weeks[col];
    var row = 0;
    while (row < week.length) {
      final kind = _kindOf(week[row]);
      if (kind == null) {
        row++;
        continue;
      }
      var end = row;
      while (end + 1 < week.length && _kindOf(week[end + 1]) == kind) {
        end++;
      }
      segments.add(
        _HighlightSegment(
          column: col,
          startRow: row,
          endRow: end,
          kind: kind,
          firstDay: week[row]!.day,
        ),
      );
      row = end + 1;
    }
  }
  return segments;
}

/// A [_Connector] between week-columns `col` and `col + 1` wherever the
/// bottom (Saturday) cell of `col` and the top (Sunday) cell of `col + 1`
/// are both highlighted with the same kind — the one place a streak's run
/// crosses a week-column boundary.
List<_Connector> _computeConnectors(List<List<ActivityDay?>> weeks) {
  final connectors = <_Connector>[];
  for (var col = 0; col < weeks.length - 1; col++) {
    final bottom = _kindOf(weeks[col][6]);
    final top = _kindOf(weeks[col + 1][0]);
    if (bottom != null && bottom == top) {
      connectors.add(_Connector(column: col, kind: bottom));
    }
  }
  return connectors;
}

/// The day grid itself: a background `Row` of week-columns (plain cells, no
/// per-cell highlight) with the connected streak-highlight shapes and
/// boundary connectors (#089) layered on top, positioned from the same
/// column/row geometry as the cells below them.
class _CalendarGrid extends StatelessWidget {
  final List<List<ActivityDay?>> weeks;
  final Color flame;
  final Color ice;
  final ColorScheme scheme;
  final String Function(ActivityDay day) cellSemanticsLabel;

  const _CalendarGrid({
    required this.weeks,
    required this.flame,
    required this.ice,
    required this.scheme,
    required this.cellSemanticsLabel,
  });

  Color _colorFor(_HighlightKind kind) =>
      kind == _HighlightKind.current ? flame : scheme.primary;

  @override
  Widget build(BuildContext context) {
    final segments = _computeHighlightSegments(weeks);
    final connectors = _computeConnectors(weeks);
    return Stack(
      children: [
        Row(
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
                              ice: ice,
                              scheme: scheme,
                              semanticsLabel: cellSemanticsLabel(week[i]!),
                            ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        for (final segment in segments)
          Positioned(
            left: segment.column * (_kCellSize + _kCellGap),
            top: segment.startRow * (_kCellSize + _kCellGap),
            width: _kCellSize,
            height:
                (segment.endRow - segment.startRow + 1) * _kCellSize +
                (segment.endRow - segment.startRow) * _kCellGap,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  key: Key('activityCalendarHighlight-${segment.firstDay}'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _colorFor(segment.kind),
                      width: 2,
                    ),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(FoxRadius.sm + 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        for (final connector in connectors) ...[
          // Short notch on the Saturday (bottom) cell of `column`, and a
          // matching one on the Sunday (top) cell of `column + 1` —
          // *not* one bar spanning the full grid height: these two cells
          // sit at opposite vertical extremes of the grid (top-to-bottom
          // chronological order within a column means a run crossing the
          // boundary jumps from the bottom of one column straight to the
          // top of the next), so a shape literally joining them would cut
          // across every unrelated row in between.
          Positioned(
            left: (connector.column + 1) * (_kCellSize + _kCellGap) - _kCellGap,
            top: 6 * (_kCellSize + _kCellGap),
            width: _kCellGap,
            height: _kCellSize,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  key: Key(
                    'activityCalendarConnector-${connector.column}-bottom',
                  ),
                  color: _colorFor(connector.kind),
                ),
              ),
            ),
          ),
          Positioned(
            left: (connector.column + 1) * (_kCellSize + _kCellGap) - _kCellGap,
            top: 0,
            width: _kCellGap,
            height: _kCellSize,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  key: Key('activityCalendarConnector-${connector.column}-top'),
                  color: _colorFor(connector.kind),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final ActivityDay day;
  final Color flame;
  final Color ice;
  final ColorScheme scheme;
  final String semanticsLabel;

  const _DayCell({
    required this.day,
    required this.flame,
    required this.ice,
    required this.scheme,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    // A streak-on-ice day (#087) always renders icy-blue, overriding its
    // bucket color entirely — distinct from every flame-bucket color and
    // from a same-bucket low-XP lesson day.
    final Color cellColor = day.isStreakOnIce
        ? ice
        : colorForActivityLevel(
            day.level,
            flame: flame,
            emptyColor: scheme.surfaceContainerHighest,
          );
    return Semantics(
      key: Key('activityCalendarCell-${day.day}'),
      label: semanticsLabel,
      child: Container(
        width: _kCellSize,
        height: _kCellSize,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.sm)),
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
