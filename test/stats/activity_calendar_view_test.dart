// Widget tests for the #084 Streak Details calendar's rendering: per-day
// cell colors (bucket thresholds), current-streak/longest-streak
// highlight borders, empty/no-data days, and the initial scroll position.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/stats/activity_calendar.dart';
import 'package:fox_streak_app/src/stats/activity_calendar_view.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

Future<void> pumpCalendar(
  WidgetTester tester,
  ActivityCalendarData data,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        home: Scaffold(
          body: ActivityCalendarView(
            data: data,
            cellSemanticsLabel: (day) => 'cell-${day.day}',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

ActivityDay day(
  String d, {
  int xp = 0,
  bool hasActivity = false,
  ActivityLevel level = ActivityLevel.none,
  bool isCurrentStreak = false,
  bool isLongestStreak = false,
}) => ActivityDay(
  day: d,
  xpEarned: xp,
  hasActivity: hasActivity,
  level: level,
  isCurrentStreak: isCurrentStreak,
  isLongestStreak: isLongestStreak,
);

BoxDecoration decorationOf(WidgetTester tester, String dayStr) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(Key('activityCalendarCell-$dayStr')),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration as BoxDecoration;
}

void main() {
  testWidgets('renders exactly one cell per day', (tester) async {
    final data = ActivityCalendarData(
      days: [day('2026-10-09'), day('2026-10-10'), day('2026-10-11')],
      currentStreakCount: 0,
      longestStreakInWindow: 0,
      longestDiffersFromCurrent: false,
    );
    await pumpCalendar(tester, data);

    expect(
      find.byKey(const Key('activityCalendarCell-2026-10-09')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('activityCalendarCell-2026-10-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('activityCalendarCell-2026-10-11')),
      findsOneWidget,
    );
  });

  testWidgets('a day with no activity renders the neutral empty color', (
    tester,
  ) async {
    final data = ActivityCalendarData(
      days: [day('2026-10-11')],
      currentStreakCount: 0,
      longestStreakInWindow: 0,
      longestDiffersFromCurrent: false,
    );
    await pumpCalendar(tester, data);

    final decoration = decorationOf(tester, '2026-10-11');
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    expect(decoration.color, scheme.surfaceContainerHighest);
    expect(decoration.border, isNull);
  });

  testWidgets(
    'low/medium/high buckets render increasing flame alpha, distinct from '
    'the empty color',
    (tester) async {
      final data = ActivityCalendarData(
        days: [
          day('2026-10-09', hasActivity: true, level: ActivityLevel.low),
          day('2026-10-10', hasActivity: true, level: ActivityLevel.medium),
          day('2026-10-11', hasActivity: true, level: ActivityLevel.high),
        ],
        currentStreakCount: 0,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );
      await pumpCalendar(tester, data);

      final low = decorationOf(tester, '2026-10-09').color!;
      final medium = decorationOf(tester, '2026-10-10').color!;
      final high = decorationOf(tester, '2026-10-11').color!;

      expect(low.a, lessThan(medium.a));
      expect(medium.a, lessThan(high.a));
      expect(high.a, 1.0);
    },
  );

  testWidgets('a current-streak day gets a flame-colored highlight border', (
    tester,
  ) async {
    final data = ActivityCalendarData(
      days: [day('2026-10-11', hasActivity: true, isCurrentStreak: true)],
      currentStreakCount: 1,
      longestStreakInWindow: 0,
      longestDiffersFromCurrent: false,
    );
    await pumpCalendar(tester, data);

    final decoration = decorationOf(tester, '2026-10-11');
    final flame = foxSemantics(tester.element(find.byType(Scaffold))).flame;
    expect((decoration.border as Border).top.color, flame);
  });

  testWidgets(
    'a longest-streak (non-current) day gets a distinct highlight border',
    (tester) async {
      final data = ActivityCalendarData(
        days: [day('2026-09-01', hasActivity: true, isLongestStreak: true)],
        currentStreakCount: 0,
        longestStreakInWindow: 1,
        longestDiffersFromCurrent: true,
      );
      await pumpCalendar(tester, data);

      final decoration = decorationOf(tester, '2026-09-01');
      final scheme = Theme.of(tester.element(find.byType(Scaffold)))
          .colorScheme;
      final flame = foxSemantics(tester.element(find.byType(Scaffold))).flame;
      final borderColor = (decoration.border as Border).top.color;
      expect(borderColor, scheme.primary);
      expect(borderColor, isNot(flame));
    },
  );

  testWidgets('a cell carries the caller-provided semantics label', (
    tester,
  ) async {
    final data = ActivityCalendarData(
      days: [day('2026-10-11', hasActivity: true, xp: 10)],
      currentStreakCount: 0,
      longestStreakInWindow: 0,
      longestDiffersFromCurrent: false,
    );
    await pumpCalendar(tester, data);

    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('activityCalendarCell-2026-10-11')),
    );
    expect(semantics.properties.label, 'cell-2026-10-11');
  });

  testWidgets('the initial scroll position is at the end (today)', (
    tester,
  ) async {
    final days = buildWindowDays(today: DateTime(2026, 10, 11))
        .map((d) => day(d))
        .toList();
    final data = ActivityCalendarData(
      days: days,
      currentStreakCount: 0,
      longestStreakInWindow: 0,
      longestDiffersFromCurrent: false,
    );
    // Narrower than the full ~6-month calendar width so it actually needs
    // to scroll (the default 800px test surface fits the whole thing).
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: ActivityCalendarView(
                data: data,
                cellSemanticsLabel: (day) => 'cell-${day.day}',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('activityCalendarScroll')),
        matching: find.byType(Scrollable),
      ),
    );
    final position = scrollable.position;
    expect(position.pixels, position.maxScrollExtent);
    expect(position.maxScrollExtent, greaterThan(0));
  });
}
