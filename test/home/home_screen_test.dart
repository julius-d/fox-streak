// Widget tests for the Home dashboard + first-run onboarding (issue #012).
//
// Covers: onboarding gates Home until `has_onboarded` (skip persists it),
// optional name capture during onboarding, generic vs. named greeting +
// tap-to-rename, the Continue-button Continue/Browse-sets duality, and
// that the header widgets (StreakBadge/level-progress/goal ring) render
// with real profile values.
//
// NOTE on pumping: see test/library/library_screen_test.dart — bounded
// `settle()` instead of `pumpAndSettle()` (drift `watch()` streams spin
// under fake async), and the pre-teardown `unmount()` to flush drift's
// stream-close timer.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/home/home_screen.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

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

Future<AppDatabase> pumpHome(WidgetTester tester, FakeClock clock) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
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
        home: const HomeScreen(),
      ),
    ),
  );
  await settle(tester);
  return db;
}

/// Pumps Home with onboarding already marked done, so the dashboard shows
/// immediately. [seed] runs before the pump for additional fixture data.
Future<AppDatabase> pumpOnboardedHome(
  WidgetTester tester,
  FakeClock clock, {
  Future<void> Function(StatsRepository stats, SetsRepository sets)? seed,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async => db.close());
  final statsRepo = StatsRepository(db, clock);
  final setsRepo = SetsRepository(db, clock);
  await statsRepo.setOnboarded();
  if (seed != null) await seed(statsRepo, setsRepo);
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
        home: const HomeScreen(),
      ),
    ),
  );
  await settle(tester);
  return db;
}

void main() {
  testWidgets(
    'onboarding gates Home on a fresh install; Skip marks it done and '
    'reveals the dashboard',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final db = await pumpHome(tester, clock);

      expect(find.byKey(const Key('onboardingScreen')), findsOneWidget);
      expect(find.byKey(const Key('homeScreen')), findsNothing);

      await tester.tap(find.byKey(const Key('onboardingSkipButton')));
      await settle(tester);

      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.byKey(const Key('onboardingScreen')), findsNothing);

      final repo = StatsRepository(db, clock);
      expect((await repo.getProfile()).hasOnboarded, isTrue);
      await unmount(tester);
    },
  );

  testWidgets('onboarding never re-shows once has_onboarded is set', (
    tester,
  ) async {
    final clock = FakeClock(kTestToday);
    await pumpOnboardedHome(tester, clock);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);
    expect(find.byKey(const Key('onboardingScreen')), findsNothing);
    await unmount(tester);
  });

  testWidgets(
    'onboarding captures an optional name across its slides, which then '
    'shows up in the Home greeting',
    (tester) async {
      final clock = FakeClock(DateTime(2026, 10, 13, 9));
      await pumpHome(tester, clock);

      // Slide 1 -> 2 -> 3 (name capture) via Next.
      await tester.tap(find.byKey(const Key('onboardingNextButton')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('onboardingNextButton')));
      await settle(tester);

      await tester.enterText(
        find.byKey(const Key('onboardingNameField')),
        'Mia',
      );
      await tester.tap(find.byKey(const Key('onboardingNextButton')));
      await settle(tester);

      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.text('Good morning, Mia!'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'greeting falls back to the generic time-of-day text, and tapping it '
    'opens a rename dialog that updates the greeting',
    (tester) async {
      final clock = FakeClock(DateTime(2026, 10, 13, 9));
      await pumpOnboardedHome(tester, clock);

      expect(find.text('Good morning!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('homeGreeting')));
      await settle(tester);
      expect(find.byKey(const Key('displayNameField')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('displayNameField')), 'Mia');
      await tester.tap(find.byKey(const Key('saveDisplayNameButton')));
      await settle(tester);

      expect(find.text('Good morning, Mia!'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'with no attempts yet, the Continue slot shows a Browse-sets CTA that '
    'opens the library (no dead button)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      await pumpOnboardedHome(tester, clock);

      final button = tester.widget<FoxPrimaryButton>(
        find.byKey(const Key('homeContinueButton')),
      );
      expect(button.label, 'Browse sets');

      await tester.tap(find.byKey(const Key('homeContinueButton')));
      await settle(tester);
      expect(find.text('My Sets'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'Browse sets button always navigates to the unchanged LibraryScreen',
    (tester) async {
      final clock = FakeClock(kTestToday);
      await pumpOnboardedHome(tester, clock);

      await tester.tap(find.byKey(const Key('homeBrowseSetsButton')));
      await settle(tester);
      expect(find.text('My Sets'), findsOneWidget);
      expect(find.byKey(const Key('newSetFab')), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'the parental info button opens the static parental info screen',
    (tester) async {
      final clock = FakeClock(kTestToday);
      await pumpOnboardedHome(tester, clock);

      await tester.tap(find.byKey(const Key('parentalInfoButton')));
      await settle(tester);

      expect(find.byKey(const Key('parentalInfoScreen')), findsOneWidget);
      expect(find.text('For parents'), findsWidgets);
      await unmount(tester);
    },
  );

  testWidgets(
    'with a prior attempt, the Continue button resumes the last practiced '
    'set',
    (tester) async {
      final clock = FakeClock(kTestToday);
      late int setId;
      await pumpOnboardedHome(
        tester,
        clock,
        seed: (stats, sets) async {
          setId = await sets.createSet(title: 'Animals', createdBy: 'Mama');
          final itemId = await sets.addItem(
            setId: setId,
            type: 'phone',
            prompt: 'Mama',
            answer: '0171',
          );
          await stats.recordAttempt(itemId: itemId, ok: true);
        },
      );

      final button = tester.widget<FoxPrimaryButton>(
        find.byKey(const Key('homeContinueButton')),
      );
      expect(button.label, 'Continue practicing');

      await tester.tap(find.byKey(const Key('homeContinueButton')));
      await settle(tester);
      expect(find.byKey(const Key('lessonProgressBar')), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('header widgets render with real profile values: streak badge, '
      'level-progress bar, and goal ring', (tester) async {
    final clock = FakeClock(kTestToday);
    await pumpOnboardedHome(
      tester,
      clock,
      seed: (stats, sets) async {
        await stats.addXp(140, now: kTestToday);
        await stats.setStreak(
          streakCount: 5,
          lastActiveDay: clock.todayDayString(),
        );
      },
    );

    expect(find.byKey(const Key('streakBadge')), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // today done
    expect(find.byKey(const Key('levelProgressBar')), findsOneWidget);
    expect(find.byKey(const Key('goalRing')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'goal ring shows 0 / dailyGoalXp, not a stale prior-day full value, '
    'when lastActiveDay is before today (issue #036)',
    (tester) async {
      final clock = FakeClock(kTestToday);
      final yesterday = kTestToday.subtract(const Duration(days: 1));
      await pumpOnboardedHome(
        tester,
        clock,
        seed: (stats, sets) async {
          // Fills yesterday's todayXp to a full goal via addXp (which never
          // touches lastActiveDay), then sets lastActiveDay to yesterday
          // directly — reproducing the write-time-lazy-reset staleness
          // `StatsRepository.addXp` leaves behind until the next write.
          await stats.addXp(kDefaultDailyGoalXp, now: yesterday);
          await stats.setStreak(
            streakCount: 3,
            lastActiveDay: toLocalDayString(yesterday),
          );
        },
      );

      final ring = tester.widget<FoxGoalRing>(
        find.byKey(const Key('goalRing')),
      );
      expect(ring.value, 0.0);
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const Key('goalRing'))),
      )!;
      expect(ring.centerLabel, l10n.homeGoalRingValue(0, kDefaultDailyGoalXp));
      await unmount(tester);
    },
  );
}
