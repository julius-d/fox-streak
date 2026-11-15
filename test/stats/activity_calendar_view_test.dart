// Widget tests for the Streak Details calendar (#084, #089, #128): cell
// colors per day state, Monday-first weekday labels, streak bands (open
// ends at week breaks, colors, backwards draw-in), the today marker +
// pulse, the tap-a-day popup, semantics, and the initial scroll position.
// The draw-in / pulse timing itself lives in `StreakDetailsMotion` (#132,
// see streak_motion_test.dart); here they're driven by fixed animations.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/stats/activity_calendar.dart';
import 'package:fox_streak_app/src/stats/activity_calendar_view.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

String oct(int d) => '2026-10-${d.toString().padLeft(2, '0')}';

/// Mon 2026-10-05 .. Wed 2026-10-14 (today). A current streak Fri 09 ..
/// today crosses the Sunday -> Monday break; Oct 10 is a freeze day; Oct
/// 06/07 are a longest-streak run when [withLongest].
ActivityCalendarData fixture({
  bool practicedToday = true,
  bool withLongest = false,
}) {
  final days = <ActivityDay>[
    for (var i = 5; i <= 14; i++)
      ActivityDay(
        day: oct(i),
        xpEarned: i == 10 ? 0 : 20 + i,
        state: switch (i) {
          10 => ActivityDayState.streakFreeze,
          14 when !practicedToday => ActivityDayState.none,
          8 => ActivityDayState.none,
          5 => ActivityDayState.none,
          _ => ActivityDayState.practiced,
        },
        isToday: i == 14,
        isCurrentStreak: i >= 9 && (practicedToday || i < 14),
        isLongestStreak: withLongest && (i == 6 || i == 7),
      ),
  ];
  return ActivityCalendarData(
    days: days,
    currentStreakCount: practicedToday ? 6 : 5,
    longestStreak: 6,
    practiceDays: 7,
    showLongestStreakBand: withLongest,
  );
}

Future<void> pumpCalendar(
  WidgetTester tester,
  ActivityCalendarData data, {
  double? width,
  bool settle = true,
  Animation<double> bandDrawIn = kAlwaysCompleteAnimation,
  Animation<double> todayPulse = kAlwaysDismissedAnimation,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: FoxStreakTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            const Text('outside', key: Key('outside')),
            SizedBox(
              width: width,
              child: ActivityCalendarView(
                data: data,
                cellSemanticsLabel: (day) => 'cell-${day.day}',
                dayPopupText: (day) =>
                    (date: 'date-${day.day}', status: 'status-${day.day}'),
                bandDrawIn: bandDrawIn,
                todayPulse: todayPulse,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Color cellColor(WidgetTester tester, String day) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(Key('activityCalendarCell-$day')),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration! as BoxDecoration).color!;
}

StreakBandPainter bandOf(WidgetTester tester, String firstDay) =>
    tester
            .widget<CustomPaint>(
              find.byKey(Key('activityCalendarBand-$firstDay')),
            )
            .painter!
        as StreakBandPainter;

double todayScale(WidgetTester tester, String day) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byKey(Key('activityCalendarCell-$day')),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getMaxScaleOnAxis();

void main() {
  testWidgets('renders exactly one cell per day', (tester) async {
    await pumpCalendar(tester, fixture());
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'activityCalendarCell-',
            ),
      ),
      findsNWidgets(10),
    );
  });

  testWidgets('cells show only three states: practiced (flame), streak '
      'freeze (ice), no practice (neutral)', (tester) async {
    await pumpCalendar(tester, fixture());
    final theme = FoxStreakTheme.light();
    final semantics = theme.extension<FoxSemanticColors>()!;
    expect(cellColor(tester, oct(9)), semantics.flame);
    expect(cellColor(tester, oct(10)), semantics.ice);
    expect(
      cellColor(tester, oct(8)),
      theme.colorScheme.surfaceContainerHighest,
    );
  });

  testWidgets('weekday letters sit on the Mon/Wed/Fri rows (1st, 3rd, 5th) '
      'of a Monday-first week', (tester) async {
    await pumpCalendar(tester, fixture());
    final double mondayY = tester.getCenter(find.text('M')).dy;
    final double wednesdayY = tester.getCenter(find.text('W')).dy;
    final double fridayY = tester.getCenter(find.text('F')).dy;
    // Row 0 = Monday 2026-10-05, row 2 = Wed 07, row 4 = Fri 09.
    expect(
      mondayY,
      moreOrLessEquals(
        tester.getCenter(find.byKey(Key('activityCalendarCell-${oct(5)}'))).dy,
      ),
    );
    expect(
      wednesdayY,
      moreOrLessEquals(
        tester.getCenter(find.byKey(Key('activityCalendarCell-${oct(7)}'))).dy,
      ),
    );
    expect(
      fridayY,
      moreOrLessEquals(
        tester.getCenter(find.byKey(Key('activityCalendarCell-${oct(9)}'))).dy,
      ),
    );
    expect(find.text('T'), findsNothing);
    expect(find.text('S'), findsNothing);
    expect(find.text('Oct'), findsOneWidget);
  });

  testWidgets('a current streak crossing Sunday -> Monday renders as two '
      'flame bands, open at the week break', (tester) async {
    await pumpCalendar(tester, fixture());
    final flame = FoxStreakTheme.light().extension<FoxSemanticColors>()!.flame;
    final first = bandOf(tester, oct(9));
    expect(first.color, flame);
    expect(first.openTop, isFalse);
    expect(first.openBottom, isTrue);
    final second = bandOf(tester, oct(12));
    expect(second.openTop, isTrue);
    expect(second.openBottom, isFalse);
    // One band per column, not per day.
    expect(find.byKey(Key('activityCalendarBand-${oct(10)}')), findsNothing);
    expect(find.byKey(Key('activityCalendarBand-${oct(13)}')), findsNothing);
  });

  testWidgets('the band never pokes outside the grid: the open ends stop '
      'at the grid edge', (tester) async {
    await pumpCalendar(tester, fixture());
    final Rect grid = tester.getRect(find.byKey(const Key('activityCalendar')));
    for (final day in [oct(9), oct(12)]) {
      final Rect band = tester.getRect(
        find.byKey(Key('activityCalendarBand-$day')),
      );
      expect(band.bottom, lessThanOrEqualTo(grid.bottom));
      expect(band.top, greaterThanOrEqualTo(grid.top));
    }
  });

  testWidgets('a longest-streak band uses the gold color', (tester) async {
    await pumpCalendar(tester, fixture(withLongest: true));
    final gold = FoxStreakTheme.light().extension<FoxSemanticColors>()!.goldInk;
    expect(bandOf(tester, oct(6)).color, gold);
  });

  testWidgets('without animations the band is fully drawn and today does '
      'not pulse', (tester) async {
    await pumpCalendar(tester, fixture(practicedToday: false), settle: false);
    await tester.pump();
    expect(bandOf(tester, oct(9)).reveal, 1);
    expect(bandOf(tester, oct(12)).reveal, 1);
    expect(todayScale(tester, oct(14)), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the current band draws in backwards: today first, the '
      'earliest days last', (tester) async {
    final drawIn = AnimationController(vsync: const TestVSync());
    addTearDown(drawIn.dispose);
    await pumpCalendar(tester, fixture(), bandDrawIn: drawIn);
    // Nothing drawn before the draw-in starts.
    expect(bandOf(tester, oct(12)).reveal, 0);
    expect(bandOf(tester, oct(9)).reveal, 0);
    // 6 days total; the later column (3 days) grows first.
    drawIn.value = 0.25;
    await tester.pump();
    expect(bandOf(tester, oct(12)).reveal, greaterThan(0));
    expect(bandOf(tester, oct(9)).reveal, 0);
    drawIn.value = 0.75;
    await tester.pump();
    expect(bandOf(tester, oct(12)).reveal, 1);
    expect(bandOf(tester, oct(9)).reveal, inExclusiveRange(0, 1));
    drawIn.value = 1;
    await tester.pump();
    expect(bandOf(tester, oct(12)).reveal, 1);
    expect(bandOf(tester, oct(9)).reveal, 1);
  });

  testWidgets('today is marked and scales with the pulse intensity', (
    tester,
  ) async {
    final pulse = AnimationController(vsync: const TestVSync());
    addTearDown(pulse.dispose);
    await pumpCalendar(
      tester,
      fixture(practicedToday: false),
      todayPulse: pulse,
    );
    expect(
      find.byKey(const Key('activityCalendarTodayMarker')),
      findsOneWidget,
    );
    expect(todayScale(tester, oct(14)), 1);
    pulse.value = 1;
    await tester.pump();
    expect(todayScale(tester, oct(14)), moreOrLessEquals(1.08));
    pulse.value = 0;
    await tester.pump();
    expect(todayScale(tester, oct(14)), 1);
  });

  testWidgets('a practiced today is marked too', (tester) async {
    await pumpCalendar(tester, fixture());
    expect(
      find.byKey(const Key('activityCalendarTodayMarker')),
      findsOneWidget,
    );
  });

  group('tap a day', () {
    Finder popup() => find.byKey(const Key('activityCalendarDayPopup'));

    testWidgets('shows a popup with the day\'s date and status', (
      tester,
    ) async {
      await pumpCalendar(tester, fixture());
      await tester.tap(find.byKey(Key('activityCalendarCell-${oct(10)}')));
      await tester.pumpAndSettle();
      expect(popup(), findsOneWidget);
      expect(find.text('date-${oct(10)}'), findsOneWidget);
      expect(find.text('status-${oct(10)}'), findsOneWidget);
    });

    testWidgets('tapping another day replaces it — only one popup', (
      tester,
    ) async {
      await pumpCalendar(tester, fixture());
      await tester.tap(find.byKey(Key('activityCalendarCell-${oct(10)}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('activityCalendarCell-${oct(6)}')));
      await tester.pumpAndSettle();
      expect(popup(), findsOneWidget);
      expect(find.text('date-${oct(10)}'), findsNothing);
      expect(find.text('date-${oct(6)}'), findsOneWidget);
    });

    testWidgets('tapping outside closes it', (tester) async {
      await pumpCalendar(tester, fixture());
      await tester.tap(find.byKey(Key('activityCalendarCell-${oct(10)}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('outside')));
      await tester.pumpAndSettle();
      expect(popup(), findsNothing);
    });

    testWidgets('tapping the popup itself closes it', (tester) async {
      await pumpCalendar(tester, fixture());
      await tester.tap(find.byKey(Key('activityCalendarCell-${oct(10)}')));
      await tester.pumpAndSettle();
      await tester.tap(popup());
      await tester.pumpAndSettle();
      expect(popup(), findsNothing);
    });

    testWidgets('scrolling the calendar closes it', (tester) async {
      final days = buildWindowDays(today: DateTime(2026, 10, 14))
          .map((d) => ActivityDay(day: d, isToday: d == oct(14)))
          .toList();
      await pumpCalendar(
        tester,
        ActivityCalendarData(
          days: days,
          currentStreakCount: 0,
          longestStreak: 0,
          practiceDays: 0,
          showLongestStreakBand: false,
        ),
        width: 200,
      );
      await tester.tap(find.byKey(Key('activityCalendarCell-${oct(13)}')));
      await tester.pumpAndSettle();
      expect(popup(), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('activityCalendarScroll')),
        const Offset(100, 0),
      );
      await tester.pumpAndSettle();
      expect(popup(), findsNothing);
    });

    testWidgets('empty padding cells are not tappable', (tester) async {
      // First day Wed 2026-10-07: Mon/Tue of that column are padding.
      final data = ActivityCalendarData(
        days: [for (var i = 7; i <= 9; i++) ActivityDay(day: oct(i))],
        currentStreakCount: 0,
        longestStreak: 0,
        practiceDays: 0,
        showLongestStreakBand: false,
      );
      await pumpCalendar(tester, data);
      final Offset wed = tester.getCenter(
        find.byKey(Key('activityCalendarCell-${oct(7)}')),
      );
      final double pitch =
          tester
              .getCenter(find.byKey(Key('activityCalendarCell-${oct(8)}')))
              .dy -
          wed.dy;
      await tester.tapAt(wed - Offset(0, 2 * pitch));
      await tester.pumpAndSettle();
      expect(popup(), findsNothing);
    });
  });

  testWidgets('a cell carries the caller-provided semantics label and no '
      'extra tap action (the popup is for sighted users only)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCalendar(tester, fixture());
    final node = tester.getSemantics(
      find.byKey(Key('activityCalendarCell-${oct(11)}')),
    );
    expect(node.label, 'cell-${oct(11)}');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets('the initial scroll position is at the end (today)', (
    tester,
  ) async {
    final days = buildWindowDays(today: DateTime(2026, 10, 11))
        .map((d) => ActivityDay(day: d))
        .toList();
    await pumpCalendar(
      tester,
      ActivityCalendarData(
        days: days,
        currentStreakCount: 0,
        longestStreak: 0,
        practiceDays: 0,
        showLongestStreakBand: false,
      ),
      width: 200,
    );
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('activityCalendarScroll')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent);
  });
}
