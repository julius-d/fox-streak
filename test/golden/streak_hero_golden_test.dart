// Golden (screenshot-comparison) tests for the #128 Streak Details hero:
// the flame + streak number + encouraging line and the three stat tiles,
// for a live streak and the dimmed no-streak state, in light/dark themes.
//
// Plain `flutter_test` (`matchesGoldenFile`), same approach and per-OS
// baseline layout as `kit_golden_test.dart` (issue #019). Reduce motion is
// on, so the count-up / flicker show their final frame.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/stats/activity_calendar.dart';
import 'package:fox_streak_app/src/stats/streak_details_hero.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

/// Baseline subfolder for the OS this test run is executing on.
String get _goldenPlatformDir {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  return 'linux';
}

ActivityCalendarData _data({required int streak}) => ActivityCalendarData(
  days: [
    ActivityDay(
      day: '2026-10-14',
      isToday: true,
      state: streak > 0 ? ActivityDayState.practiced : ActivityDayState.none,
    ),
  ],
  currentStreakCount: streak,
  longestStreak: 21,
  practiceDays: 87,
  showLongestStreakBand: streak < 21,
  streakFreezesAvailable: 2,
);

Future<void> _expectHeroGolden(
  WidgetTester tester,
  String name, {
  required ActivityCalendarData data,
  required ThemeData theme,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 320));
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
  const Key boundaryKey = Key('goldenBoundary');
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: boundaryKey,
          // Opaque surface, so the dark baseline isn't captured on a
          // transparent (white) backdrop.
          child: ColoredBox(
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(FoxSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreakHero(data: data),
                  const SizedBox(height: FoxSpacing.lg),
                  StreakStatTiles(data: data),
                ],
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
  final List<(String, ThemeData)> themes = <(String, ThemeData)>[
    ('light', FoxStreakTheme.light()),
    ('dark', FoxStreakTheme.dark()),
  ];
  final List<(String, int)> states = <(String, int)>[
    ('streak', 12),
    ('no_streak', 0),
  ];

  for (final (String stateName, int streak) in states) {
    for (final (String themeName, ThemeData theme) in themes) {
      testWidgets('streak hero + stat tiles ($stateName, $themeName)', (
        WidgetTester tester,
      ) async {
        await _expectHeroGolden(
          tester,
          'streak_hero_${stateName}_$themeName',
          data: _data(streak: streak),
          theme: theme,
        );
      });
    }
  }
}
