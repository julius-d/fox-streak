// GitHub-style activity calendar widget for the Streak Details screen
// (#084, #089, reworked by #128).
//
// Display-only over [ActivityCalendarData] — callers precompute that and
// pass per-day semantics-label / popup-text builders, so this widget has no
// l10n (`AppLocalizations`) dependency, same spirit as `StreakBadge`. It
// does read the ambient `Localizations` locale directly (via `intl`) to
// render locale-aware weekday/month header letters (#089) — decorative
// only, excluded from the semantics tree.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/clock.dart' show parseDayString;
import '../theme/fox_streak_theme.dart';
import 'activity_calendar.dart';
import 'streak_motion.dart';

/// Cell edge length (dp) — ~3 months visible at once on a 360dp phone.
const double _kCellSize = 20;

/// Gap between cells, and between week columns. The streak band's stroke
/// runs down the middle of this gap.
const double _kCellGap = 4;

const double _kCellRadius = 6;

/// The band's stroke width, and how far its outer edge reaches past the
/// cells it surrounds — also the grid's own padding, so a band at the
/// grid's edge never pokes outside it.
const double _kBandStroke = 2;
const double _kBandOutset = _kCellGap / 2 + _kBandStroke / 2;

/// Minimum width of the weekday-letter column / height of the month-label
/// row — both grow with the text scale (up to [_kMaxHeaderTextScale]).
const double _kMinHeaderSize = 16;

const double _kHeaderFontSize = 10;

/// The header letters follow the system font size up to this factor — any
/// more and a weekday letter outgrows its 20dp row.
const double _kMaxHeaderTextScale = 2;

/// Gap between the header labels and the grid they annotate.
const double _kHeaderGap = 4;

/// Distance from one cell's origin to the next one's.
const double _kCellPitch = _kCellSize + _kCellGap;

/// Shared compact style for the decorative weekday/month header labels.
TextStyle _headerLabelStyle(BuildContext context) => TextStyle(
  fontSize: _kHeaderFontSize,
  height: 1,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

/// Width of the weekday column / height of the month row for the ambient
/// (already clamped, see [_ActivityCalendarViewState.build]) text scale.
double _headerExtent(BuildContext context) => math.max(
  _kMinHeaderSize,
  MediaQuery.textScalerOf(context).scale(_kHeaderFontSize) + 4,
);

/// An arbitrary Monday, used only to look up locale-aware weekday names —
/// only its weekday (not its date) matters.
final DateTime _kReferenceMonday = DateTime(2023, 1, 2);

/// The two lines of the tap-a-day popup.
typedef ActivityDayPopupText = ({String date, String status});

/// Fill color for a cell in [state] — shared by the calendar cells and the
/// screen's legend swatches so the two can never drift apart.
Color colorForDayState(
  ActivityDayState state, {
  required FoxSemanticColors semantics,
  required ColorScheme scheme,
}) => switch (state) {
  ActivityDayState.practiced => semantics.flame,
  ActivityDayState.streakFreeze => semantics.ice,
  ActivityDayState.none => scheme.surfaceContainerHighest,
};

/// Stroke color for a streak band of [kind] — flame for the current
/// streak, gold (the record/trophy color) for the all-time longest.
Color colorForStreakBand(StreakBandKind kind, FoxSemanticColors semantics) =>
    switch (kind) {
      StreakBandKind.current => semantics.flame,
      StreakBandKind.longest => semantics.goldInk,
    };

/// One cell per day, grouped into 7-day-tall, Monday-first week columns
/// (oldest on the left, today on the right), horizontally scrollable with
/// the initial scroll position at today. Sparse weekday letters (Mon/Wed/
/// Fri only) sit in a fixed column to the left; month abbreviations sit in
/// a row above the grid that scrolls together with it (#089). Streak runs
/// are outlined by one continuous band each (#128); tapping a day opens a
/// small popup anchored at it.
class ActivityCalendarView extends StatefulWidget {
  final ActivityCalendarData data;
  final String Function(ActivityDay day) cellSemanticsLabel;
  final ActivityDayPopupText Function(ActivityDay day) dayPopupText;

  const ActivityCalendarView({
    super.key,
    required this.data,
    required this.cellSemanticsLabel,
    required this.dayPopupText,
  });

  @override
  State<ActivityCalendarView> createState() => _ActivityCalendarViewState();
}

class _ActivityCalendarViewState extends State<ActivityCalendarView>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final OverlayPortalController _popupController = OverlayPortalController();
  final LayerLink _popupLink = LayerLink();
  late final AnimationController _bandDrawIn = AnimationController(
    vsync: this,
    duration: kStreakBandDrawInDuration,
  );
  late final AnimationController _todayPulse = AnimationController(
    vsync: this,
    duration: kStreakPulseCycle * kStreakPulseCycles,
  );
  ScrollPosition? _ancestorScroll;
  ActivityDay? _selectedDay;

  /// Whether the popup grows leftward from the selected cell (cell in the
  /// right half of the calendar) instead of rightward, so it stays on
  /// screen next to today.
  bool _popupAlignEnd = false;
  bool _animationsStarted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_dismissPopup);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scrolling the screen around the calendar dismisses the popup too.
    final ScrollPosition? ancestor = Scrollable.maybeOf(context)?.position;
    if (ancestor != _ancestorScroll) {
      _ancestorScroll?.removeListener(_dismissPopup);
      _ancestorScroll = ancestor?..addListener(_dismissPopup);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _bandDrawIn.value = 1;
      _todayPulse
        ..stop()
        ..value = 0;
    } else if (!_animationsStarted) {
      _bandDrawIn.forward(from: 0);
      if (!widget.data.practicedToday) _todayPulse.forward(from: 0);
    }
    _animationsStarted = true;
  }

  @override
  void didUpdateWidget(ActivityCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      // The selected day belongs to the old data; no setState needed here,
      // build always runs after didUpdateWidget.
      _selectedDay = null;
      _popupController.hide();
      if (widget.data.practicedToday) {
        _todayPulse
          ..stop()
          ..value = 0;
      }
    }
  }

  @override
  void dispose() {
    _ancestorScroll?.removeListener(_dismissPopup);
    _scrollController.dispose();
    _bandDrawIn.dispose();
    _todayPulse.dispose();
    super.dispose();
  }

  void _dismissPopup() {
    if (_selectedDay == null) return;
    setState(() => _selectedDay = null);
    _popupController.hide();
  }

  void _selectDay(ActivityDay day, Offset globalTap) {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    setState(() {
      _selectedDay = day;
      _popupAlignEnd = box.globalToLocal(globalTap).dx > box.size.width / 2;
    });
    _popupController.show();
  }

  @override
  Widget build(BuildContext context) {
    final FoxSemanticColors semantics = foxSemantics(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String locale = Localizations.localeOf(context).toString();
    final weeks = groupIntoWeeks(widget.data.days);
    const double gridHeight = _kCellSize * 7 + _kCellGap * 6 + _kBandOutset * 2;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _kMaxHeaderTextScale,
      child: Builder(
        builder: (context) => _buildCalendar(
          context,
          weeks: weeks,
          gridHeight: gridHeight,
          semantics: semantics,
          scheme: scheme,
          locale: locale,
        ),
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context, {
    required List<List<ActivityDay?>> weeks,
    required double gridHeight,
    required FoxSemanticColors semantics,
    required ColorScheme scheme,
    required String locale,
  }) {
    return TapRegion(
      onTapOutside: (_) => _dismissPopup(),
      child: OverlayPortal(
        controller: _popupController,
        overlayChildBuilder: _buildPopup,
        child: SizedBox(
          key: const Key('activityCalendar'),
          height: _headerExtent(context) + _kHeaderGap + gridHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: _WeekdayLabelColumn(locale: locale)),
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
                        semantics: semantics,
                        scheme: scheme,
                        bandDrawIn: _bandDrawIn,
                        todayPulse: _todayPulse,
                        selectedDay: _selectedDay,
                        popupLink: _popupLink,
                        cellSemanticsLabel: widget.cellSemanticsLabel,
                        onDayTap: _selectDay,
                        onBackgroundTap: _dismissPopup,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopup(BuildContext context) {
    final ActivityDay? day = _selectedDay;
    if (day == null) return const SizedBox.shrink();
    final ActivityDayPopupText text = widget.dayPopupText(day);
    return CompositedTransformFollower(
      link: _popupLink,
      showWhenUnlinked: false,
      targetAnchor: _popupAlignEnd ? Alignment.topRight : Alignment.topLeft,
      followerAnchor: _popupAlignEnd
          ? Alignment.bottomRight
          : Alignment.bottomLeft,
      offset: const Offset(0, -FoxSpacing.xs),
      child: Align(
        alignment: _popupAlignEnd
            ? Alignment.bottomRight
            : Alignment.bottomLeft,
        child: _DayPopup(text: text, onTap: _dismissPopup),
      ),
    );
  }
}

/// The small bubble shown above a tapped day: its date and what happened.
/// Purely an extra for sighted touch users — screen readers already get
/// the same information from each cell's own label, so it's excluded from
/// semantics.
class _DayPopup extends StatelessWidget {
  final ActivityDayPopupText text;
  final VoidCallback onTap;

  const _DayPopup({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color onColor = theme.colorScheme.onInverseSurface;
    return ExcludeSemantics(
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Material(
            key: const Key('activityCalendarDayPopup'),
            color: theme.colorScheme.inverseSurface,
            elevation: 3,
            borderRadius: const BorderRadius.all(Radius.circular(FoxRadius.sm)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FoxSpacing.md,
                vertical: FoxSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.date,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    text.status,
                    style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed (non-scrolling) column to the left of the grid: a locale-aware
/// narrow weekday letter on the Mon/Wed/Fri rows only (the 1st, 3rd and 5th
/// rows of a Monday-first week) — the other rows are blank (#089's
/// decision: labeling every row repeats letters in several locales, e.g.
/// German Mo/Mi both narrow to "M").
class _WeekdayLabelColumn extends StatelessWidget {
  final String locale;

  const _WeekdayLabelColumn({required this.locale});

  static const List<int> _labeledRows = [0, 2, 4];

  @override
  Widget build(BuildContext context) {
    final DateFormat format = DateFormat.EEEEE(locale);
    final style = _headerLabelStyle(context);
    final double extent = _headerExtent(context);
    return SizedBox(
      width: extent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: extent + _kHeaderGap + _kBandOutset),
          for (var row = 0; row < 7; row++) ...[
            if (row > 0) const SizedBox(height: _kCellGap),
            SizedBox(
              width: extent,
              height: _kCellSize,
              child: _labeledRows.contains(row)
                  ? Center(
                      child: Text(
                        format.format(
                          DateTime(
                            _kReferenceMonday.year,
                            _kReferenceMonday.month,
                            _kReferenceMonday.day + row,
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
/// abbreviation positioned above the first week-column whose top day
/// starts a new month (#089), absolutely placed (not laid out per-column)
/// so the text isn't clipped to one cell's width.
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
      height: _headerExtent(context),
      width: _gridWidth(weeks.length),
      child: Stack(
        children: [
          for (final entry in labels.entries)
            // Every column but the last has at least one more column's
            // worth of header space to its right for the label to bleed
            // into — the Stack's own bounds end at the last column's right
            // edge, so a label anchored there by its *left* edge would get
            // hard-clipped mid-glyph instead. Anchoring by the *right* edge
            // grows it leftward, which always has room.
            if (isLastColumn(entry.key))
              Positioned(
                right: _kBandOutset,
                top: 0,
                child: Text(format.format(entry.value), style: style),
              )
            else
              Positioned(
                left: _kBandOutset + entry.key * _kCellPitch,
                top: 0,
                child: Text(format.format(entry.value), style: style),
              ),
        ],
      ),
    );
  }
}

double _gridWidth(int columns) =>
    columns * _kCellSize + (columns - 1) * _kCellGap + _kBandOutset * 2;

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

/// The day grid itself: a background `Row` of week-columns with the streak
/// bands (#128) painted on top, positioned from the same column/row
/// geometry as the cells below them.
class _CalendarGrid extends StatelessWidget {
  final List<List<ActivityDay?>> weeks;
  final FoxSemanticColors semantics;
  final ColorScheme scheme;
  final Animation<double> bandDrawIn;
  final Animation<double> todayPulse;
  final ActivityDay? selectedDay;
  final LayerLink popupLink;
  final String Function(ActivityDay day) cellSemanticsLabel;
  final void Function(ActivityDay day, Offset globalTap) onDayTap;
  final VoidCallback onBackgroundTap;

  const _CalendarGrid({
    required this.weeks,
    required this.semantics,
    required this.scheme,
    required this.bandDrawIn,
    required this.todayPulse,
    required this.selectedDay,
    required this.popupLink,
    required this.cellSemanticsLabel,
    required this.onDayTap,
    required this.onBackgroundTap,
  });

  @override
  Widget build(BuildContext context) {
    final segments = computeStreakBandSegments(weeks);
    final int currentDays = segments
        .where((s) => s.kind == StreakBandKind.current)
        .fold(0, (sum, s) => sum + s.length);
    return GestureDetector(
      // Taps on gaps or padding cells close the popup; day cells win the
      // gesture arena over this as the deeper detector.
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onBackgroundTap,
      child: Padding(
        padding: const EdgeInsets.all(_kBandOutset),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < weeks.length; col++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: col == weeks.length - 1 ? 0 : _kCellGap,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var row = 0; row < 7; row++) ...[
                          if (row > 0) const SizedBox(height: _kCellGap),
                          _buildCell(weeks[col][row]),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            for (final segment in segments)
              Positioned(
                left: segment.column * _kCellPitch - _kBandOutset,
                top: segment.startRow * _kCellPitch - _kBandOutset,
                width: _kCellSize + _kBandOutset * 2,
                height:
                    segment.length * _kCellSize +
                    (segment.length - 1) * _kCellGap +
                    _kBandOutset * 2,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: bandDrawIn,
                      builder: (context, _) => CustomPaint(
                        key: Key('activityCalendarBand-${segment.firstDay}'),
                        painter: StreakBandPainter(
                          color: colorForStreakBand(segment.kind, semantics),
                          openTop: segment.openTop,
                          openBottom: segment.openBottom,
                          reveal: segment.kind == StreakBandKind.current
                              ? _revealOf(
                                  segment,
                                  bandDrawIn.value,
                                  currentDays,
                                )
                              : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// How much of [segment] is drawn at draw-in progress [t]: the current
  /// band grows backwards from today, one day after another (across week
  /// breaks too), so a segment starts once all [StreakBandSegment.daysAfter]
  /// later days are in.
  static double _revealOf(StreakBandSegment segment, double t, int total) {
    final double revealedDays = t * total;
    return ((revealedDays - segment.daysAfter) / segment.length).clamp(0, 1);
  }

  Widget _buildCell(ActivityDay? day) {
    if (day == null) {
      return const SizedBox(width: _kCellSize, height: _kCellSize);
    }
    final Widget cell = _DayCell(
      day: day,
      color: colorForDayState(day.state, semantics: semantics, scheme: scheme),
      todayRingColor: scheme.onSurface,
      todayPulse: day.isToday ? todayPulse : null,
      semanticsLabel: cellSemanticsLabel(day),
    );
    return GestureDetector(
      // Screen readers keep reading each cell's own label; the popup is an
      // extra for sighted touch users (#128), so no semantic tap action.
      excludeFromSemantics: true,
      onTapUp: (details) => onDayTap(day, details.globalPosition),
      child: identical(day, selectedDay)
          ? CompositedTransformTarget(link: popupLink, child: cell)
          : cell,
    );
  }
}

class _DayCell extends StatelessWidget {
  final ActivityDay day;
  final Color color;
  final Color todayRingColor;
  final Animation<double>? todayPulse;
  final String semanticsLabel;

  const _DayCell({
    required this.day,
    required this.color,
    required this.todayRingColor,
    required this.todayPulse,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell = Container(
      width: _kCellSize,
      height: _kCellSize,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(_kCellRadius)),
      ),
    );
    final Animation<double>? pulse = todayPulse;
    if (pulse != null) {
      // Today's ring sits inside the cell, clear of the streak band that
      // runs through the gaps around it.
      cell = AnimatedBuilder(
        animation: pulse,
        child: cell,
        builder: (context, child) {
          final double wave = streakPulseWave(pulse.value);
          return Transform.scale(
            scale: 1 + 0.08 * wave,
            child: Stack(
              children: [
                child!,
                Positioned.fill(
                  child: DecoratedBox(
                    key: const Key('activityCalendarTodayMarker'),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: todayRingColor.withValues(alpha: 1 - 0.4 * wave),
                        width: 2,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(_kCellRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return Semantics(
      key: Key('activityCalendarCell-${day.day}'),
      label: semanticsLabel,
      child: cell,
    );
  }
}

/// Paints one [StreakBandSegment]'s outline into its box: a rounded band
/// around the segment's cells, left open (no cap) at an end where the run
/// continues into the neighboring week column (#128). [reveal] (0..1) draws
/// only the bottom part — the band's backwards draw-in grows each segment
/// from its latest day (bottom) up to its earliest (top); a partly drawn
/// segment gets a rounded leading edge.
class StreakBandPainter extends CustomPainter {
  final Color color;
  final bool openTop;
  final bool openBottom;
  final double reveal;

  const StreakBandPainter({
    required this.color,
    required this.openTop,
    required this.openBottom,
    this.reveal = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final Rect box = (Offset.zero & size).deflate(_kBandStroke / 2);
    final Rect rect = Rect.fromLTRB(
      box.left,
      box.bottom - box.height * reveal.clamp(0, 1),
      box.right,
      box.bottom,
    );
    canvas.drawPath(
      streakBandPath(
        rect,
        openTop: reveal >= 1 && openTop,
        openBottom: openBottom,
        radius: _kCellRadius + _kBandOutset,
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _kBandStroke,
    );
  }

  @override
  bool shouldRepaint(StreakBandPainter oldDelegate) =>
      color != oldDelegate.color ||
      openTop != oldDelegate.openTop ||
      openBottom != oldDelegate.openBottom ||
      reveal != oldDelegate.reveal;
}

/// The outline of a band filling [rect]: a rounded rectangle, minus its
/// top and/or bottom side when [openTop]/[openBottom] — the two side lines
/// then run straight to the rect's edge, with nothing sticking out.
Path streakBandPath(
  Rect rect, {
  required bool openTop,
  required bool openBottom,
  required double radius,
}) {
  final double r = [
    radius,
    rect.width / 2,
    rect.height / 2,
  ].reduce((a, b) => a < b ? a : b);
  final Radius corner = Radius.circular(r);
  final Path path = Path();
  if (!openTop && !openBottom) {
    return path..addRRect(RRect.fromRectAndRadius(rect, corner));
  }
  if (openTop && openBottom) {
    return path
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.left, rect.bottom)
      ..moveTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom);
  }
  if (openBottom) {
    // Rounded cap on top only.
    return path
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: corner)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: corner)
      ..lineTo(rect.right, rect.bottom);
  }
  // Rounded cap on the bottom only.
  return path
    ..moveTo(rect.left, rect.top)
    ..lineTo(rect.left, rect.bottom - r)
    ..arcToPoint(
      Offset(rect.left + r, rect.bottom),
      radius: corner,
      clockwise: false,
    )
    ..lineTo(rect.right - r, rect.bottom)
    ..arcToPoint(
      Offset(rect.right, rect.bottom - r),
      radius: corner,
      clockwise: false,
    )
    ..lineTo(rect.right, rect.top);
}
