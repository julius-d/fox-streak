// Integration test for the #128 Streak Details glow-up: drives the real
// `FoxStreakApp` from Home's streak badge to the Streak Details screen and
// checks the flame hero, the all-time stat tiles, the grid (today marked,
// opened scrolled to today, a band across a week break) and the tap-a-day
// popup (open, replace, close on outside tap) against real repository rows.
// Since #132 the current streak contains a day saved by a real launch-time
// streak freeze, which counts toward the streak length everywhere.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/stats/activity_calendar_view.dart';

import 'helpers.dart';

/// Wednesday 2026-10-14.
class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 10, 14, 9);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the real Streak Details screen shows the hero, stat tiles, '
      'grid and day popup', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = _FixedClock();
    final statsRepo = StatsRepository(db, clock);
    await statsRepo.setOnboarded();

    // A 5-day record (with a freeze day) long before the 6-month minimum
    // window — still counted all-time and reachable by scrolling.
    for (final day in [
      '2025-11-03',
      '2025-11-04',
      '2025-11-05',
      '2025-11-07',
    ]) {
      await statsRepo.recordDailyActivity(
        day: day,
        xpDelta: 10,
        source: DailyActivitySource.lessonCompleted,
      );
    }
    await statsRepo.recordDailyActivity(
      day: '2025-11-06',
      xpDelta: 0,
      source: DailyActivitySource.streakOnIce,
    );
    // Practiced Sat 2026-10-10 .. Mon 2026-10-12, crossing the Sunday ->
    // Monday break; Tue 13 missed, so the app launch spends one of two
    // banked freezes on it. Today (Wed) not practiced yet.
    for (final day in ['2026-10-10', '2026-10-11', '2026-10-12']) {
      await statsRepo.recordDailyActivity(
        day: day,
        xpDelta: 25,
        source: DailyActivitySource.lessonCompleted,
      );
    }
    await statsRepo.setStreak(streakCount: 3, lastActiveDay: '2026-10-12');
    await statsRepo.addStreakFreezes(2);

    await pumpFoxStreakApp(tester, db: db, clock: clock);
    expect(find.byKey(const Key('streakFreezeAppliedBanner')), findsOneWidget);
    // #132: the saved day is a streak day — 3 practiced + 1 frozen.
    expect(
      find.descendant(
        of: find.byKey(const Key('streakBadge')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    await openStreakDetails(tester);
    expect(find.byKey(const Key('streakDetailsScreen')), findsOneWidget);

    // Hero: counted up to the current streak (freeze day included), with
    // the "not yet today" nudge.
    expect(
      tester.widget<Text>(find.byKey(const Key('streakHeroCount'))).data,
      '4',
    );
    expect(
      find.text('Practice today to keep your streak going.'),
      findsOneWidget,
    );

    // Stat tiles: longest = the 5-day record (freeze day included),
    // practice days = 7 (freezes excluded), 1 freeze left — singular.
    Finder tileValue(String key, String value) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.text(value));
    expect(tileValue('streakStatLongest', '5'), findsOneWidget);
    expect(tileValue('streakStatPracticeDays', '7'), findsOneWidget);
    expect(tileValue('streakStatFreezes', '1'), findsOneWidget);
    expect(tileValue('streakStatFreezes', 'Streak freeze'), findsOneWidget);

    // Grid: opened scrolled to today, today marked, the current streak a
    // band open across the week break, the old record still in the grid.
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('activityCalendarScroll')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.pixels, position.maxScrollExtent);
    expect(
      find.byKey(const Key('activityCalendarTodayMarker')),
      findsOneWidget,
    );
    final StreakBandPainter firstBand =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('activityCalendarBand-2025-11-03')),
                )
                .painter!
            as StreakBandPainter;
    expect(firstBand.openBottom, isFalse);
    final StreakBandPainter weekendBand =
        tester
                .widget<CustomPaint>(
                  find.byKey(const Key('activityCalendarBand-2026-10-10')),
                )
                .painter!
            as StreakBandPainter;
    expect(weekendBand.openBottom, isTrue);
    // The band surrounds exactly the hero's 4 days, the freeze day too.
    final Rect weekBand = tester.getRect(
      find.byKey(const Key('activityCalendarBand-2026-10-12')),
    );
    for (final (day, inBand) in [
      ('2026-10-12', true),
      ('2026-10-13', true),
      ('2026-10-14', false),
    ]) {
      final Offset cell = tester
          .getRect(find.byKey(Key('activityCalendarCell-$day')))
          .center;
      expect(weekBand.contains(cell), inBand, reason: day);
    }
    // #132: the legend has no current-streak entry.
    expect(find.byKey(const Key('legendCurrentStreak')), findsNothing);

    // Tap a practiced day: popup with date + XP.
    Finder popup() => find.byKey(const Key('activityCalendarDayPopup'));
    await tester.tap(find.byKey(const Key('activityCalendarCell-2026-10-12')));
    await pumpFrames(tester, const Duration(milliseconds: 500));
    expect(popup(), findsOneWidget);
    expect(find.text('Mon, Oct 12, 2026'), findsOneWidget);
    expect(find.text('25 XP earned'), findsOneWidget);

    // The frozen day says so.
    await tester.tap(find.byKey(const Key('activityCalendarCell-2026-10-13')));
    await pumpFrames(tester, const Duration(milliseconds: 500));
    expect(find.text('Saved by a streak freeze ❄️'), findsOneWidget);

    // Tapping today replaces it.
    await tester.tap(find.byKey(const Key('activityCalendarCell-2026-10-14')));
    await pumpFrames(tester, const Duration(milliseconds: 500));
    expect(popup(), findsOneWidget);
    expect(find.text('Not practiced yet today'), findsOneWidget);
    expect(find.text('25 XP earned'), findsNothing);

    // Tapping outside closes it.
    await tester.tap(find.byKey(const Key('streakHeroLine')));
    await pumpFrames(tester, const Duration(milliseconds: 500));
    expect(popup(), findsNothing);
  });
}
