// Widget tests for the #084/#089 Streak Details calendar's rendering:
// per-day cell colors (bucket thresholds), connected current-streak/
// longest-streak highlight shapes (incl. boundary connectors), weekday/
// month header labels, empty/no-data days, and the initial scroll position.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/stats/activity_calendar.dart';
import 'package:fox_streak_app/src/stats/activity_calendar_view.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

Future<void> pumpCalendar(
  WidgetTester tester,
  ActivityCalendarData data, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        theme: FoxStreakTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ActivityCalendarView(
            data: data,
            cellSemanticsLabel: (day) => 'cell-${day.day}',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

BoxDecoration highlightDecorationOf(WidgetTester tester, String firstDay) {
  final container = tester.widget<Container>(
    find.byKey(Key('activityCalendarHighlight-$firstDay')),
  );
  return container.decoration as BoxDecoration;
}

/// Any connector widget's key contains this, regardless of which pair of
/// adjacent week-columns it bridges — tests only care whether one exists.
Finder anyConnectorFinder() => find.byWidgetPredicate(
  (widget) =>
      widget.key?.toString().contains('activityCalendarConnector') ?? false,
);

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
    expect(
      find.byKey(const Key('activityCalendarHighlight-2026-10-11')),
      findsNothing,
    );
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

  testWidgets('a current-streak day gets a flame-colored highlight shape', (
    tester,
  ) async {
    final data = ActivityCalendarData(
      days: [day('2026-10-11', hasActivity: true, isCurrentStreak: true)],
      currentStreakCount: 1,
      longestStreakInWindow: 0,
      longestDiffersFromCurrent: false,
    );
    await pumpCalendar(tester, data);

    final decoration = highlightDecorationOf(tester, '2026-10-11');
    final flame = foxSemantics(tester.element(find.byType(Scaffold))).flame;
    expect((decoration.border as Border).top.color, flame);
  });

  testWidgets(
    'a longest-streak (non-current) day gets a distinct highlight shape',
    (tester) async {
      final data = ActivityCalendarData(
        days: [day('2026-09-01', hasActivity: true, isLongestStreak: true)],
        currentStreakCount: 0,
        longestStreakInWindow: 1,
        longestDiffersFromCurrent: true,
      );
      await pumpCalendar(tester, data);

      final decoration = highlightDecorationOf(tester, '2026-09-01');
      final scheme = Theme.of(tester.element(find.byType(Scaffold)))
          .colorScheme;
      final flame = foxSemantics(tester.element(find.byType(Scaffold))).flame;
      final borderColor = (decoration.border as Border).top.color;
      expect(borderColor, scheme.primary);
      expect(borderColor, isNot(flame));
    },
  );

  testWidgets(
    'a run of consecutive same-column streak days renders as one merged '
    'shape, not one per cell',
    (tester) async {
      // 2026-10-12/13/14 (Mon/Tue/Wed) fall in the same Sunday-first week
      // column.
      final data = ActivityCalendarData(
        days: [
          day('2026-10-12', hasActivity: true, isCurrentStreak: true),
          day('2026-10-13', hasActivity: true, isCurrentStreak: true),
          day('2026-10-14', hasActivity: true, isCurrentStreak: true),
        ],
        currentStreakCount: 3,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );
      await pumpCalendar(tester, data);

      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-12')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-13')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-14')),
        findsNothing,
      );
      // The merged shape spans all 3 cells plus the 2 gaps between them.
      final size = tester.getSize(
        find.byKey(const Key('activityCalendarHighlight-2026-10-12')),
      );
      expect(size.height, closeTo(14 * 3 + 3 * 2, 0.01));
    },
  );

  testWidgets(
    'a current streak crossing a week-column boundary renders two merged '
    'shapes joined by a connector',
    (tester) async {
      // 2026-10-09/10 (Fri/Sat) end one week column; 2026-10-11/12
      // (Sun/Mon) continue in the next.
      final data = ActivityCalendarData(
        days: [
          day('2026-10-09', hasActivity: true, isCurrentStreak: true),
          day('2026-10-10', hasActivity: true, isCurrentStreak: true),
          day('2026-10-11', hasActivity: true, isCurrentStreak: true),
          day('2026-10-12', hasActivity: true, isCurrentStreak: true),
        ],
        currentStreakCount: 4,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );
      await pumpCalendar(tester, data);

      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-09')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-11')),
        findsOneWidget,
      );
      // One notch on the Saturday cell, one on the Sunday cell.
      expect(anyConnectorFinder(), findsNWidgets(2));
    },
  );

  testWidgets(
    'no connector is rendered when a run does not reach both boundary '
    'cells',
    (tester) async {
      // 2026-10-11/12 (Sun/Mon) alone: the preceding week's Saturday
      // (2026-10-10) isn't part of the run, so there's nothing to bridge.
      final data = ActivityCalendarData(
        days: [
          day('2026-10-10', hasActivity: true),
          day('2026-10-11', hasActivity: true, isCurrentStreak: true),
          day('2026-10-12', hasActivity: true, isCurrentStreak: true),
        ],
        currentStreakCount: 2,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );
      await pumpCalendar(tester, data);

      expect(anyConnectorFinder(), findsNothing);
    },
  );

  testWidgets(
    'a run ending on the Saturday of the very last week-column renders '
    'with no dangling connector (nothing to bridge to)',
    (tester) async {
      // 2026-10-08/09/10 (Thu/Fri/Sat) is a single week-column with no
      // column after it.
      final data = ActivityCalendarData(
        days: [
          day('2026-10-08', hasActivity: true, isCurrentStreak: true),
          day('2026-10-09', hasActivity: true, isCurrentStreak: true),
          day('2026-10-10', hasActivity: true, isCurrentStreak: true),
        ],
        currentStreakCount: 3,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );
      await pumpCalendar(tester, data);

      expect(
        find.byKey(const Key('activityCalendarHighlight-2026-10-08')),
        findsOneWidget,
      );
      expect(anyConnectorFinder(), findsNothing);
    },
  );

  testWidgets(
    'weekday letters appear only on the Mon/Wed/Fri rows, locale-aware',
    (tester) async {
      final data = ActivityCalendarData(
        days: [day('2026-10-11')],
        currentStreakCount: 0,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );
      await pumpCalendar(tester, data, locale: const Locale('en'));
      expect(find.text('M'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      // Sunday/Tuesday/Thursday/Saturday rows are blank, not labeled 'S'/
      // 'T': only the 3 labeled rows render any weekday text at all.
      expect(find.text('S'), findsNothing);
      expect(find.text('T'), findsNothing);

      await pumpCalendar(tester, data, locale: const Locale('de'));
      // German: Montag/Mittwoch both narrow to 'M' (confirmed collision,
      // same as #089's rationale for not labeling every row) while Freitag
      // narrows to 'F'.
      expect(find.text('M'), findsNWidgets(2));
      expect(find.text('F'), findsOneWidget);
    },
  );

  testWidgets(
    'month abbreviations appear above each month\'s first week-column, '
    'locale-aware',
    (tester) async {
      // Window: 2026-09-27 (Sun) .. 2026-10-12 (Mon) — 3 week columns.
      // Column 0 (Sep27-Oct03) is September's first column even though
      // October's days start mid-column; column 1 (Oct04-10) is the first
      // column whose own topmost day is October.
      final days = [
        for (
          var d = DateTime(2026, 9, 27);
          !d.isAfter(DateTime(2026, 10, 12));
          d = d.add(const Duration(days: 1))
        )
          day(
            '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
          ),
      ];
      final data = ActivityCalendarData(
        days: days,
        currentStreakCount: 0,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );

      await pumpCalendar(tester, data, locale: const Locale('en'));
      expect(find.text('Sep'), findsOneWidget);
      expect(find.text('Oct'), findsOneWidget);

      await pumpCalendar(tester, data, locale: const Locale('de'));
      expect(find.text('Sep'), findsOneWidget);
      expect(find.text('Okt'), findsOneWidget);
    },
  );

  testWidgets(
    'a month label still renders (right-anchored, not clipped) when its '
    'column is the very last one, with no column to its right to bleed '
    'into',
    (tester) async {
      // Window: 2026-09-28 (Mon) .. 2026-10-04 (Sun) — column 0 is
      // September, column 1 (just 2026-10-04) is October's first column
      // *and* the last column in the whole dataset.
      final days = [
        for (
          var d = DateTime(2026, 9, 28);
          !d.isAfter(DateTime(2026, 10, 4));
          d = d.add(const Duration(days: 1))
        )
          day(
            '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
          ),
      ];
      final data = ActivityCalendarData(
        days: days,
        currentStreakCount: 0,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );

      await pumpCalendar(tester, data, locale: const Locale('en'));
      expect(tester.takeException(), isNull);
      expect(find.text('Sep'), findsOneWidget);
      expect(find.text('Oct'), findsOneWidget);
    },
  );

  testWidgets(
    'weekday/month header labels are excluded from the semantics tree',
    (tester) async {
      final data = ActivityCalendarData(
        days: [day('2026-10-11', hasActivity: true, xp: 10)],
        currentStreakCount: 0,
        longestStreakInWindow: 0,
        longestDiffersFromCurrent: false,
      );
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCalendar(tester, data);

      // The weekday letter renders visually...
      expect(find.text('M'), findsOneWidget);
      // ...but isn't surfaced as its own semantics node, unlike the cell's
      // own (unchanged) semantics label.
      expect(find.bySemanticsLabel('M'), findsNothing);
      expect(find.bySemanticsLabel('cell-2026-10-11'), findsOneWidget);
      handle.dispose();
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
