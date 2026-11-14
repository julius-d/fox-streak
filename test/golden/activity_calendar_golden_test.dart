// Golden (screenshot-comparison) tests for the Streak Details calendar
// (#089, #128): weekday/month header labels, Monday-first weeks, the three
// cell states, today's ring and the streak bands (open at a Sunday ->
// Monday break), across `en`/`de` locales (weekday letters differ, e.g.
// German Mo/Mi both narrow to "M") and light/dark themes.
//
// Plain `flutter_test` (`matchesGoldenFile`), same approach and per-OS
// baseline layout as `kit_golden_test.dart` (issue #019) — see that file's
// header for why baselines can't be a single cross-platform set.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/stats/activity_calendar.dart';
import 'package:fox_streak_app/src/stats/activity_calendar_view.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

/// Baseline subfolder for the OS this test run is executing on.
String get _goldenPlatformDir {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  return 'linux';
}

String _d(int month, int day) =>
    '2026-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

/// 3 Monday-first week-columns (Mon 2026-09-28 .. Wed 2026-10-14 = today):
/// a longest-streak run (Sep 29 - Oct 1, gold) inside the first column, and
/// a current streak (Fri Oct 9 .. today, flame) with a freeze day (Oct 10)
/// that crosses the Sunday -> Monday break between the 2nd and 3rd columns
/// — the open band ends, today's ring and all three cell states in one
/// fixture.
final ActivityCalendarData _data = ActivityCalendarData(
  days: [
    for (final (month, day) in [
      for (var d = 28; d <= 30; d++) (9, d),
      for (var d = 1; d <= 14; d++) (10, d),
    ])
      ActivityDay(
        day: _d(month, day),
        xpEarned: 20,
        state: switch ((month, day)) {
          (10, 10) => ActivityDayState.streakFreeze,
          (9, 29) || (9, 30) || (10, 1) => ActivityDayState.practiced,
          (10, 5) || (10, 7) => ActivityDayState.practiced,
          (10, final int d) when d >= 9 => ActivityDayState.practiced,
          _ => ActivityDayState.none,
        },
        isToday: month == 10 && day == 14,
        isLongestStreak:
            (month, day) == (9, 29) ||
            (month, day) == (9, 30) ||
            (month, day) == (10, 1),
        isCurrentStreak: month == 10 && day >= 9,
      ),
  ],
  currentStreakCount: 6,
  longestStreak: 6,
  practiceDays: 11,
  showLongestStreakBand: true,
);

/// Pumps the calendar under [locale]/[theme] at its exact natural size (3
/// week-columns wide, so nothing is scrolled off-screen and no extra
/// surface space bleeds into the captured bounds) and asserts it matches
/// the baseline PNG named `goldens/<platform>/$name.png`.
Future<void> _expectCalendarGolden(
  WidgetTester tester,
  String name, {
  required Locale locale,
  required ThemeData theme,
}) async {
  const Size calendarSize = Size(90, 190);
  await tester.binding.setSurfaceSize(const Size(120, 220));
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
  const Key boundaryKey = Key('goldenBoundary');
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Final state, no draw-in / today pulse mid-frame.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: calendarSize.width,
              height: calendarSize.height,
              child: ActivityCalendarView(
                data: _data,
                cellSemanticsLabel: (day) => day.day,
                dayPopupText: (day) => (date: day.day, status: ''),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byKey(boundaryKey),
    matchesGoldenFile('goldens/$_goldenPlatformDir/$name.png'),
  );
}

void main() {
  final List<(String, Locale)> locales = <(String, Locale)>[
    ('en', const Locale('en')),
    ('de', const Locale('de')),
  ];
  final List<(String, ThemeData)> themes = <(String, ThemeData)>[
    ('light', FoxStreakTheme.light()),
    ('dark', FoxStreakTheme.dark()),
  ];

  for (final (String localeName, Locale locale) in locales) {
    for (final (String themeName, ThemeData theme) in themes) {
      testWidgets(
        'activity calendar headers + streak bands across a week break '
        '($localeName, $themeName)',
        (WidgetTester tester) async {
          await _expectCalendarGolden(
            tester,
            'activity_calendar_${localeName}_$themeName',
            locale: locale,
            theme: theme,
          );
        },
      );
    }
  }
}
