// Widget tests for StreakDetailsScreen (#084, glow-up #128, polish #132):
// the three hero states, the all-time stat tiles (freeze days excluded from
// practice days, singular/plural captions), a freeze day counted into the
// streak, the day popup copy, the legend, the opening sequence (order,
// start after the page transition, pause while hidden or covered), reduce
// motion, large fonts, and that everything reflects real repository state.
//
// NOTE on pumping: never `pumpAndSettle()` — the flame and today pulse loop
// for as long as the screen is visible (#132), so it never settles; the
// helpers pump through the opening sequence for a fixed time instead. Same
// drift `watch()`-under-fake-async caveat as `test/home/home_screen_test.dart`
// (this screen watches `profileProvider` transitively via
// `activityCalendarProvider`).

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/stats/activity_calendar_view.dart';
import 'package:fox_streak_app/src/stats/streak_details_screen.dart';
import 'package:fox_streak_app/src/stats/streak_freeze_service.dart';
import 'package:fox_streak_app/src/stats/streak_service.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import '../data/test_helpers.dart';

/// Pumps [ms] of fake time in 100ms frames.
Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Count-up (1.5 s) + band draw-in (2 s), with some slack: afterwards only
/// the loops are still running.
const int kOpeningMs = 4000;

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// kTestToday is Sunday 2026-10-11.
const String today = '2026-10-11';

Future<void> practice(StatsRepository stats, String day, {int xp = 10}) =>
    stats.recordDailyActivity(
      day: day,
      xpDelta: xp,
      source: DailyActivitySource.lessonCompleted,
    );

Future<void> freezeDay(StatsRepository stats, String day) =>
    stats.recordDailyActivity(
      day: day,
      xpDelta: 0,
      source: DailyActivitySource.streakOnIce,
    );

/// Pumps the screen and waits until the provider has resolved (and, unless
/// [settleAnimations] is off, until the opening sequence has played).
Future<void> pumpStreakDetails(
  WidgetTester tester, {
  Future<void> Function(StatsRepository stats)? seed,
  bool reduceMotion = false,
  double textScale = 1,
  bool settleAnimations = true,
  Locale? locale,
}) async {
  final clock = FakeClock(kTestToday);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  if (seed != null) {
    await seed(StatsRepository(db, clock));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        theme: FoxStreakTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const StreakDetailsScreen(),
      ),
    ),
  );
  await waitForHero(tester);
  if (settleAnimations) await pumpFor(tester, kOpeningMs);
}

/// Lets the (real-async) drift query resolve until the hero is on screen,
/// without advancing fake time.
Future<void> waitForHero(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    if (find.byKey(const Key('streakHero')).evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Streak Details never showed its hero');
}

String heroCount(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('streakHeroCount'))).data!;

double scaleAbove(WidgetTester tester, Finder child) => tester
    .widget<Transform>(
      find.ancestor(of: child, matching: find.byType(Transform)).first,
    )
    .transform
    .getMaxScaleOnAxis();

double flameScale(WidgetTester tester) =>
    scaleAbove(tester, find.byKey(const Key('streakHeroFlame')));

double todayScale(WidgetTester tester) =>
    scaleAbove(tester, find.byKey(const Key('activityCalendarTodayMarker')));

double bandReveal(WidgetTester tester, String firstDay) =>
    (tester
                .widget<CustomPaint>(
                  find.byKey(Key('activityCalendarBand-$firstDay')),
                )
                .painter!
            as StreakBandPainter)
        .reveal;

/// Max flame / today-cell scale seen over [ms] of fake time.
Future<({double flame, double today})> peakScales(
  WidgetTester tester,
  int ms, {
  bool withToday = true,
}) async {
  var flame = 1.0;
  var today = 1.0;
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
    if (flameScale(tester) > flame) flame = flameScale(tester);
    if (withToday && todayScale(tester) > today) today = todayScale(tester);
  }
  return (flame: flame, today: today);
}

void main() {
  testWidgets('shows the title, hero, stat tiles, calendar and legend; the '
      'old text headlines are gone', (tester) async {
    await pumpStreakDetails(tester);

    expect(find.text('Streak history'), findsOneWidget);
    expect(find.byKey(const Key('streakHero')), findsOneWidget);
    expect(find.byKey(const Key('streakStatLongest')), findsOneWidget);
    expect(find.byKey(const Key('streakStatPracticeDays')), findsOneWidget);
    expect(find.byKey(const Key('streakStatFreezes')), findsOneWidget);
    expect(find.byKey(const Key('activityCalendar')), findsOneWidget);
    expect(find.byKey(const Key('activityCalendarLegend')), findsOneWidget);
    expect(find.byKey(const Key('currentStreakHeadline')), findsNothing);
    expect(find.byKey(const Key('longestStreakHeadline')), findsNothing);
    expect(find.byKey(const Key('streakFreezesAvailableLabel')), findsNothing);
    await unmount(tester);
  });

  group('hero', () {
    testWidgets('no streak: 0, a dimmed still flame and an inviting line', (
      tester,
    ) async {
      await pumpStreakDetails(tester);

      expect(heroCount(tester), '0');
      expect(find.text('Start a new streak today!'), findsOneWidget);
      final flame = tester.widget<Icon>(
        find.byKey(const Key('streakHeroFlame')),
      );
      final theme = FoxStreakTheme.light();
      expect(
        flame.color,
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
      );
      await unmount(tester);
    });

    testWidgets('practiced today: the streak number and a celebrating line', (
      tester,
    ) async {
      await pumpStreakDetails(
        tester,
        seed: (stats) async {
          await practice(stats, '2026-10-10');
          await practice(stats, today);
          await stats.setStreak(streakCount: 2, lastActiveDay: today);
        },
      );

      expect(heroCount(tester), '2');
      expect(find.text('days in a row!'), findsOneWidget);
      expect(find.text("You're on fire! See you tomorrow."), findsOneWidget);
      final flame = tester.widget<Icon>(
        find.byKey(const Key('streakHeroFlame')),
      );
      expect(
        flame.color,
        FoxStreakTheme.light().extension<FoxSemanticColors>()!.flame,
      );
      await unmount(tester);
    });

    testWidgets('streak alive, not practiced yet today: a friendly nudge', (
      tester,
    ) async {
      await pumpStreakDetails(
        tester,
        seed: (stats) async {
          await practice(stats, '2026-10-10');
          await stats.setStreak(streakCount: 1, lastActiveDay: '2026-10-10');
        },
      );

      expect(heroCount(tester), '1');
      expect(find.text('day in a row!'), findsOneWidget);
      expect(
        find.text('Practice today to keep your streak going.'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('screen readers get the final streak value, not the '
        'count-up frame', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpStreakDetails(
        tester,
        seed: (stats) async {
          await practice(stats, today);
          await stats.setStreak(streakCount: 4, lastActiveDay: today);
        },
      );

      expect(
        tester.getSemantics(find.byKey(const Key('streakHero'))).label,
        contains('Current streak: 4 days'),
      );
      handle.dispose();
      await unmount(tester);
    });
  });

  testWidgets('stat tiles: all-time longest streak (freeze days count), '
      'practice days (freeze days excluded), and freezes owned', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpStreakDetails(
      tester,
      seed: (stats) async {
        // A 4-day record a year ago, with one freeze day in it.
        await practice(stats, '2025-09-01');
        await practice(stats, '2025-09-02');
        await freezeDay(stats, '2025-09-03');
        await practice(stats, '2025-09-04');
        await practice(stats, today);
        await stats.setStreak(streakCount: 1, lastActiveDay: today);
        await stats.addStreakFreezes(2);
      },
    );

    String tileLabel(String key) =>
        tester.getSemantics(find.byKey(Key(key))).label;
    expect(tileLabel('streakStatLongest'), 'Longest streak: 4 days');
    expect(tileLabel('streakStatPracticeDays'), '4 practice days in total');
    expect(tileLabel('streakStatFreezes'), '2 streak freezes available');
    for (final (key, value) in [
      ('streakStatLongest', '4'),
      ('streakStatPracticeDays', '4'),
      ('streakStatFreezes', '2'),
    ]) {
      expect(
        find.descendant(of: find.byKey(Key(key)), matching: find.text(value)),
        findsOneWidget,
      );
    }
    // #127's snowflake sits in the freezes tile — the only one on the
    // screen (calendar cells + legend stay icon-free, #087).
    expect(
      find.descendant(
        of: find.byKey(const Key('streakStatFreezes')),
        matching: find.byType(FoxStreakFreezeIcon),
      ),
      findsOneWidget,
    );
    expect(find.byType(FoxStreakFreezeIcon), findsOneWidget);
    handle.dispose();
    await unmount(tester);
  });

  testWidgets('the longest streak is never shown below the current streak', (
    tester,
  ) async {
    await pumpStreakDetails(
      tester,
      seed: (stats) async {
        await practice(stats, today);
        await stats.setStreak(streakCount: 30, lastActiveDay: today);
      },
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('streakStatLongest')),
        matching: find.text('30'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('a day saved by a streak freeze is a streak day: hero, '
      'longest tile and band all show the same 7 days (#132)', (tester) async {
    await pumpStreakDetails(
      tester,
      seed: (stats) async {
        // Practiced Mon 5 .. Fri 9; the app opens on Sun 11 with Saturday
        // missed and a freeze banked; then today's lesson.
        for (var d = 5; d <= 9; d++) {
          await practice(stats, '2026-10-0$d');
        }
        await stats.setStreak(streakCount: 5, lastActiveDay: '2026-10-09');
        await stats.addStreakFreezes(1);
        final clock = FakeClock(kTestToday);
        expect(
          await StreakFreezeService(stats, clock).checkAndApplyOnLaunch(),
          isTrue,
        );
        await practice(stats, today);
        await StreakService(stats, clock).recordActivity();
      },
    );

    expect(heroCount(tester), '7');
    expect(
      find.descendant(
        of: find.byKey(const Key('streakStatLongest')),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
    // Mon..Sun is one week column: one current band around all 7 days.
    final band = tester.getRect(
      find.byKey(const Key('activityCalendarBand-2026-10-05')),
    );
    for (var d = 5; d <= 11; d++) {
      final cell = tester.getRect(
        find.byKey(
          Key('activityCalendarCell-2026-10-${d.toString().padLeft(2, '0')}'),
        ),
      );
      expect(band.contains(cell.center), isTrue, reason: 'Oct $d in band');
    }
    expect(
      find.byKey(const Key('activityCalendarBand-2026-10-04')),
      findsNothing,
    );
    await unmount(tester);
  });

  group('stat tile captions follow their number (#132)', () {
    Future<void> seedOnes(StatsRepository stats) async {
      await practice(stats, today);
      await stats.setStreak(streakCount: 1, lastActiveDay: today);
      await stats.addStreakFreezes(1);
    }

    Future<void> seedPlural(StatsRepository stats) async {
      await practice(stats, '2026-10-10');
      await practice(stats, today);
      await stats.setStreak(streakCount: 2, lastActiveDay: today);
      await stats.addStreakFreezes(2);
    }

    String tileLabel(WidgetTester tester, String key) =>
        tester.getSemantics(find.byKey(Key(key))).label;

    Finder inTile(String key, String text) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

    testWidgets('German: singular for 1', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpStreakDetails(
        tester,
        seed: seedOnes,
        locale: const Locale('de'),
      );
      expect(inTile('streakStatPracticeDays', 'Übungstag'), findsOneWidget);
      expect(inTile('streakStatFreezes', 'Streak-Freeze'), findsOneWidget);
      expect(inTile('streakStatLongest', 'Längster Streak'), findsOneWidget);
      expect(
        tileLabel(tester, 'streakStatPracticeDays'),
        '1 Übungstag insgesamt',
      );
      expect(
        tileLabel(tester, 'streakStatFreezes'),
        '1 Streak-Freeze verfügbar',
      );
      expect(tileLabel(tester, 'streakStatLongest'), 'Längster Streak: 1 Tag');
      expect(
        tester.getSemantics(find.byKey(const Key('streakHero'))).label,
        contains('Aktueller Streak: 1 Tag'),
      );
      handle.dispose();
      await unmount(tester);
    });

    testWidgets('German: plural for 0 and 2+', (tester) async {
      await pumpStreakDetails(tester, locale: const Locale('de'));
      expect(inTile('streakStatPracticeDays', 'Übungstage'), findsOneWidget);
      expect(inTile('streakStatFreezes', 'Streak-Freezes'), findsOneWidget);
      expect(find.text('Starte heute einen neuen Streak!'), findsOneWidget);
      await unmount(tester);

      await pumpStreakDetails(
        tester,
        seed: seedPlural,
        locale: const Locale('de'),
      );
      expect(inTile('streakStatPracticeDays', 'Übungstage'), findsOneWidget);
      expect(inTile('streakStatFreezes', 'Streak-Freezes'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('English: singular for 1, plural otherwise', (tester) async {
      await pumpStreakDetails(tester, seed: seedOnes);
      expect(inTile('streakStatPracticeDays', 'Practice day'), findsOneWidget);
      expect(inTile('streakStatFreezes', 'Streak freeze'), findsOneWidget);
      await unmount(tester);

      await pumpStreakDetails(tester, seed: seedPlural);
      expect(inTile('streakStatPracticeDays', 'Practice days'), findsOneWidget);
      expect(inTile('streakStatFreezes', 'Streak freezes'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('legend', () {
    testWidgets('explains the three cell states; no current-streak entry '
        '(#132)', (tester) async {
      await pumpStreakDetails(tester);
      expect(find.text('Practiced'), findsOneWidget);
      expect(find.text('Saved by a streak freeze'), findsOneWidget);
      expect(find.text('No practice'), findsOneWidget);
      expect(find.text('Current streak'), findsNothing);
      expect(find.byKey(const Key('legendCurrentStreak')), findsNothing);
      expect(find.byKey(const Key('legendLongestStreak')), findsNothing);
      await unmount(tester);
    });

    testWidgets('lists the longest-streak band only while it is drawn', (
      tester,
    ) async {
      await pumpStreakDetails(
        tester,
        seed: (stats) async {
          for (final d in ['2026-10-01', '2026-10-02', '2026-10-03']) {
            await practice(stats, d);
          }
          await practice(stats, today);
          await stats.setStreak(streakCount: 1, lastActiveDay: today);
        },
      );
      expect(find.byKey(const Key('legendLongestStreak')), findsOneWidget);
      expect(
        find.byKey(const Key('activityCalendarBand-2026-10-01')),
        findsOneWidget,
      );
      await unmount(tester);
    });
  });

  group('day popup', () {
    Future<void> tapDay(WidgetTester tester, String day) async {
      await tester.tap(find.byKey(Key('activityCalendarCell-$day')));
      await pumpFor(tester, 300);
    }

    Future<void> seed(StatsRepository stats) async {
      await practice(stats, '2026-10-08', xp: 35);
      await freezeDay(stats, '2026-10-09');
      await stats.setStreak(streakCount: 2, lastActiveDay: '2026-10-09');
    }

    testWidgets('a practiced day shows its date and the XP earned', (
      tester,
    ) async {
      await pumpStreakDetails(tester, seed: seed);
      await tapDay(tester, '2026-10-08');
      expect(find.text('Thu, Oct 8, 2026'), findsOneWidget);
      expect(find.text('35 XP earned'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a freeze day says it was saved by a streak freeze', (
      tester,
    ) async {
      await pumpStreakDetails(tester, seed: seed);
      await tapDay(tester, '2026-10-09');
      expect(find.text('Saved by a streak freeze ❄️'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a past day without practice says so', (tester) async {
      await pumpStreakDetails(tester, seed: seed);
      await tapDay(tester, '2026-10-07');
      expect(find.text('No practice'), findsNWidgets(2)); // + legend
      expect(
        find.descendant(
          of: find.byKey(const Key('activityCalendarDayPopup')),
          matching: find.text('No practice'),
        ),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('today without practice says not practiced yet today', (
      tester,
    ) async {
      await pumpStreakDetails(tester, seed: seed);
      await tapDay(tester, today);
      expect(find.text('Not practiced yet today'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('per-day screen-reader labels stay on the cells', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpStreakDetails(tester, seed: seed);
      String label(String day) => tester
          .getSemantics(find.byKey(Key('activityCalendarCell-$day')))
          .label;
      expect(label('2026-10-08'), 'Oct 8, 2026: 35 XP earned');
      expect(label('2026-10-09'), 'Oct 9, 2026: saved by a streak freeze');
      expect(label('2026-10-07'), 'Oct 7, 2026: no practice');
      expect(label(today), 'Oct 11, 2026: not practiced yet today');
      handle.dispose();
      await unmount(tester);
    });
  });

  group('animations', () {
    Future<void> seed(StatsRepository stats) async {
      for (var d = 1; d <= 10; d++) {
        await practice(stats, '2026-10-${d.toString().padLeft(2, '0')}');
      }
      // A live 10-day streak, today (Oct 11) not practiced yet: all three
      // steps apply.
      await stats.setStreak(streakCount: 10, lastActiveDay: '2026-10-10');
    }

    testWidgets('plays count-up (~1.5 s) -> band draw-in (~2 s) -> today '
        'pulse, one after the other; the flame flickers from the start', (
      tester,
    ) async {
      await pumpStreakDetails(tester, seed: seed, settleAnimations: false);
      // Count-up: the number climbs, the flame flickers, the band and the
      // today pulse wait.
      await pumpFor(tester, 700);
      expect(int.parse(heroCount(tester)), inExclusiveRange(0, 10));
      expect(bandReveal(tester, '2026-10-05'), 0);
      expect(todayScale(tester), 1);
      expect(flameScale(tester), greaterThan(1));
      await pumpFor(tester, 900); // 1.6 s
      expect(heroCount(tester), '10');

      // Band draw-in: grows back from today, the today pulse still waits.
      await pumpFor(tester, 700);
      expect(bandReveal(tester, '2026-10-05'), greaterThan(0));
      expect(bandReveal(tester, '2026-10-01'), 0);
      expect(todayScale(tester), 1);
      await pumpFor(tester, 1400); // 3.7 s
      expect(bandReveal(tester, '2026-10-01'), 1);

      // Today pulse.
      final peaks = await peakScales(tester, 1000);
      expect(peaks.today, greaterThan(1));
      await unmount(tester);
    });

    testWidgets('a 0 streak skips count-up and band: the today pulse comes '
        'first, the dimmed flame stays still', (tester) async {
      await pumpStreakDetails(tester, settleAnimations: false);
      final peaks = await peakScales(tester, 1000);
      expect(peaks.today, greaterThan(1));
      expect(peaks.flame, 1);
      await unmount(tester);
    });

    testWidgets('afterwards the flame and the today pulse keep coming back '
        'in bursts with rests in between', (tester) async {
      await pumpStreakDetails(tester, seed: seed);
      // 4 s in: today pulse burst (3 s) then rest (3 s); flame bursts
      // every 5 s from the start.
      var burst = await peakScales(tester, 3000);
      expect(burst.today, greaterThan(1));
      final rest = await peakScales(tester, 2500, withToday: true);
      expect(rest.today, 1);
      burst = await peakScales(tester, 4000);
      expect(burst.today, greaterThan(1));
      expect(burst.flame, greaterThan(1));
      await unmount(tester);
    });

    testWidgets('the sequence starts only once the page transition is '
        'finished', (tester) async {
      final clock = FakeClock(kTestToday);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async => db.close());
      await seed(StatsRepository(db, clock));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(clock),
          ],
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StreakDetailsScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await waitForHero(tester);
      final route = ModalRoute.of(
        tester.element(find.byKey(const Key('streakHero'))),
      )!;
      // Mid-transition: nothing has started yet.
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.isCompleted, isFalse);
      expect(heroCount(tester), '0');
      expect(flameScale(tester), 1);
      // Transition over, then the full count-up.
      while (!route.animation!.isCompleted) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(heroCount(tester), '0');
      await pumpFor(tester, 700);
      expect(int.parse(heroCount(tester)), inExclusiveRange(0, 10));
      await pumpFor(tester, 900);
      expect(heroCount(tester), '10');
      await unmount(tester);
    });

    testWidgets('everything pauses while another screen covers it and '
        'continues afterwards without replaying', (tester) async {
      await pumpStreakDetails(tester, seed: seed, settleAnimations: false);
      // Count-up done, band draw-in just started: its later column (Oct
      // 5..10, 6 of 10 days) grows first, the earlier one (Oct 1..4) last.
      await pumpFor(tester, 1600);
      expect(heroCount(tester), '10');
      expect(bandReveal(tester, '2026-10-01'), 0);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ),
      );
      await pumpFor(tester, 1000); // transition over: covered
      await pumpFor(tester, 3000);
      expect(tester.binding.hasScheduledFrame, isFalse);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Continued from where it was held: neither replayed from 0 nor
      // jumped ahead by the time it was covered.
      expect(heroCount(tester), '10');
      expect(bandReveal(tester, '2026-10-05'), greaterThan(0));
      expect(bandReveal(tester, '2026-10-01'), lessThan(1));
      await pumpFor(tester, 2000);
      expect(bandReveal(tester, '2026-10-01'), 1);
      await unmount(tester);
    });

    testWidgets('everything pauses while the app is hidden and continues '
        'when it is back', (tester) async {
      await pumpStreakDetails(tester, seed: seed, settleAnimations: false);
      await pumpFor(tester, 500);
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(() {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });
      final String heldCount = heroCount(tester);
      await pumpFor(tester, 3000);
      expect(heroCount(tester), heldCount);
      expect(int.parse(heldCount), inExclusiveRange(0, 10));

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpFor(tester, 1200);
      expect(heroCount(tester), '10');
      await unmount(tester);
    });

    testWidgets('tapping a day during the sequence neither stops nor '
        'restarts it', (tester) async {
      await pumpStreakDetails(tester, seed: seed, settleAnimations: false);
      await pumpFor(tester, 700);
      final int before = int.parse(heroCount(tester));
      await tester.tap(
        find.byKey(const Key('activityCalendarCell-2026-10-08')),
      );
      await tester.pump();
      expect(int.parse(heroCount(tester)), greaterThanOrEqualTo(before));
      await pumpFor(tester, 900);
      expect(heroCount(tester), '10');
      expect(find.byKey(const Key('activityCalendarDayPopup')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('with reduce motion the final state shows immediately and '
        'nothing loops', (tester) async {
      await pumpStreakDetails(
        tester,
        seed: seed,
        reduceMotion: true,
        settleAnimations: false,
      );
      expect(heroCount(tester), '10');
      expect(flameScale(tester), 1);
      expect(bandReveal(tester, '2026-10-01'), 1);
      expect(todayScale(tester), 1);
      await pumpFor(tester, 300);
      expect(tester.binding.hasScheduledFrame, isFalse);
      final peaks = await peakScales(tester, 6000);
      expect(peaks.flame, 1);
      expect(peaks.today, 1);
      await unmount(tester);
    });
  });

  testWidgets('at large font sizes the stat tiles stack instead of '
      'clipping', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpStreakDetails(tester, textScale: 2);
    expect(find.byKey(const Key('streakStatTilesStacked')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('at the default font size the stat tiles sit side by side on '
      'a 360dp phone', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpStreakDetails(tester);
    expect(find.byKey(const Key('streakStatTilesRow')), findsOneWidget);
    await unmount(tester);
  });
}
