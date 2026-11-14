// Widget tests for StreakDetailsScreen (#084, glow-up #128): the three hero
// states, the all-time stat tiles (freeze days excluded from practice
// days), the day popup copy, the legend, reduce motion, large fonts, and
// that everything reflects real repository state.
//
// NOTE on pumping: bounded `settle()` instead of `pumpAndSettle()` — same
// drift `watch()`-under-fake-async caveat as `test/home/home_screen_test.dart`
// (this screen watches `profileProvider` transitively via
// `activityCalendarProvider`).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/stats/streak_details_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import '../data/test_helpers.dart';

Future<void> settle(WidgetTester tester, {int cap = 50}) async {
  for (var i = 0; i < cap; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('UI did not settle after $cap frames');
}

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
/// [settleAnimations] is off, until the opening animations have rested).
Future<void> pumpStreakDetails(
  WidgetTester tester, {
  Future<void> Function(StatsRepository stats)? seed,
  bool reduceMotion = false,
  double textScale = 1,
  bool settleAnimations = true,
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
  if (settleAnimations) {
    await settle(tester);
  } else {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
      if (find.byKey(const Key('streakHero')).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }
}

String heroCount(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('streakHeroCount'))).data!;

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

  group('legend', () {
    testWidgets('explains the three cell states and the current band', (
      tester,
    ) async {
      await pumpStreakDetails(tester);
      expect(find.text('Practiced'), findsOneWidget);
      expect(find.text('Saved by a streak freeze'), findsOneWidget);
      expect(find.text('No practice'), findsOneWidget);
      expect(find.text('Current streak'), findsOneWidget);
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
      await settle(tester);
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
      for (var d = 1; d <= 11; d++) {
        await practice(stats, '2026-10-${d.toString().padLeft(2, '0')}');
      }
      await stats.setStreak(streakCount: 11, lastActiveDay: today);
    }

    testWidgets('the streak number counts up from 0 to the current value '
        'within ~1 s', (tester) async {
      await pumpStreakDetails(tester, seed: seed, settleAnimations: false);
      expect(int.parse(heroCount(tester)), lessThan(11));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(heroCount(tester), '11');
      await settle(tester);
      await unmount(tester);
    });

    testWidgets('with reduce motion the final state shows immediately', (
      tester,
    ) async {
      await pumpStreakDetails(
        tester,
        seed: seed,
        reduceMotion: true,
        settleAnimations: false,
      );
      expect(heroCount(tester), '11');
      final flameScale = tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byKey(const Key('streakHeroFlame')),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getMaxScaleOnAxis();
      expect(flameScale, 1);
      await settle(tester, cap: 3);
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
