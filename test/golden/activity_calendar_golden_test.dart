// Golden (screenshot-comparison) tests for the #089 Streak Details
// calendar polish: weekday/month header labels and the connected (not
// per-cell) streak highlight, across `en`/`de` locales (weekday letters
// differ, e.g. German Mo/Mi both narrow to "M") and light/dark themes.
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

ActivityDay _day(
  String d, {
  bool isCurrentStreak = false,
  bool isLongestStreak = false,
  ActivityLevel level = ActivityLevel.none,
}) => ActivityDay(
  day: d,
  xpEarned: 0,
  hasActivity: level != ActivityLevel.none,
  level: level,
  isCurrentStreak: isCurrentStreak,
  isLongestStreak: isLongestStreak,
);

/// 3 week-columns (2026-09-27..2026-10-12): a longest-in-window run
/// (Sep28-30, primary color) entirely within the first column, and a
/// current streak (Oct09-12, flame color) that crosses the boundary
/// between the 2nd and 3rd columns — covering both #089 highlight shapes
/// and the connector in one fixture.
final ActivityCalendarData _data = ActivityCalendarData(
  days: [
    _day('2026-09-27'),
    _day('2026-09-28', isLongestStreak: true, level: ActivityLevel.medium),
    _day('2026-09-29', isLongestStreak: true, level: ActivityLevel.medium),
    _day('2026-09-30', isLongestStreak: true, level: ActivityLevel.medium),
    _day('2026-10-01', level: ActivityLevel.low),
    _day('2026-10-02'),
    _day('2026-10-03', level: ActivityLevel.low),
    _day('2026-10-04'),
    _day('2026-10-05', level: ActivityLevel.medium),
    _day('2026-10-06', level: ActivityLevel.low),
    _day('2026-10-07', level: ActivityLevel.high),
    _day('2026-10-08'),
    _day('2026-10-09', isCurrentStreak: true, level: ActivityLevel.high),
    _day('2026-10-10', isCurrentStreak: true, level: ActivityLevel.high),
    _day('2026-10-11', isCurrentStreak: true, level: ActivityLevel.high),
    _day('2026-10-12', isCurrentStreak: true, level: ActivityLevel.high),
  ],
  currentStreakCount: 4,
  longestStreakInWindow: 3,
  longestDiffersFromCurrent: true,
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
  const Size calendarSize = Size(69, 134);
  await tester.binding.setSurfaceSize(const Size(100, 160));
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
      testWidgets('activity calendar header labels + connected streak '
          '($localeName, $themeName)', (WidgetTester tester) async {
        await _expectCalendarGolden(
          tester,
          'activity_calendar_${localeName}_$themeName',
          locale: locale,
          theme: theme,
        );
      });
    }
  }
}
