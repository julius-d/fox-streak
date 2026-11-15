// Issue #108 — Streak bar shows one flame per streak day.
//
// Drives the real `FoxStreakApp` from a cold launch, proving Home's streak
// badge renders the real per-day icon row — sourced from the same
// `daily_activity` rows #084's Streak Details calendar reads, oldest to
// newest — with a flame for normal practice days and the streak-freeze
// snowflake (#127 replaced #108's ice cube) for a #087 streak-on-ice day,
// and hides entirely at `streakCount == 0`. The coin shop's matching icon
// is covered by `issue127_streak_freeze_snowflake_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    "Home's streak badge renders a flame for each normally-practiced day "
    'and a snowflake for the day a streak freeze saved it, oldest to '
    'newest, next to the still-accurate numeric count',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final today = DateTime(2026, 10, 20, 9);
      final clock = FakeClock(today);
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      final threeDaysAgo = toLocalDayString(DateTime(2026, 10, 17));
      final twoDaysAgo = toLocalDayString(DateTime(2026, 10, 18));
      final yesterday = toLocalDayString(DateTime(2026, 10, 19));
      final todayDay = toLocalDayString(today);

      await statsRepo.recordDailyActivity(
        day: threeDaysAgo,
        xpDelta: 10,
        source: DailyActivitySource.lessonCompleted,
      );
      await statsRepo.recordDailyActivity(
        day: twoDaysAgo,
        xpDelta: 0,
        source: DailyActivitySource.streakOnIce,
      );
      await statsRepo.recordDailyActivity(
        day: yesterday,
        xpDelta: 10,
        source: DailyActivitySource.lessonCompleted,
      );
      await statsRepo.recordDailyActivity(
        day: todayDay,
        xpDelta: 10,
        source: DailyActivitySource.lessonCompleted,
      );
      // A bridged freeze day counts toward streakCount (#132): 3 lessons +
      // 1 freeze is a streak of 4.
      await statsRepo.setStreak(streakCount: 4, lastActiveDay: todayDay);

      await pumpFoxStreakApp(tester, db: db, clock: clock);

      expect(find.byKey(const Key('streakBadge')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsNWidgets(3));
      expect(find.byType(FoxStreakFreezeIcon), findsOneWidget);

      // Oldest -> newest, left -> right: flame (3 days ago), ice (2 days
      // ago), flame (yesterday), flame (today, the rightmost icon).
      final double firstFlameX = tester
          .getTopLeft(find.byIcon(Icons.local_fire_department).at(0))
          .dx;
      final double iceX = tester
          .getTopLeft(find.byType(FoxStreakFreezeIcon))
          .dx;
      final double secondFlameX = tester
          .getTopLeft(find.byIcon(Icons.local_fire_department).at(1))
          .dx;
      final double thirdFlameX = tester
          .getTopLeft(find.byIcon(Icons.local_fire_department).at(2))
          .dx;
      expect(firstFlameX, lessThan(iceX));
      expect(iceX, lessThan(secondFlameX));
      expect(secondFlameX, lessThan(thirdFlameX));
    },
  );

  testWidgets('Home shows no streak badge at all for a brand-new profile '
      '(streakCount == 0)', (tester) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 20, 9));
    await StatsRepository(db, clock).setOnboarded();

    await pumpFoxStreakApp(tester, db: db, clock: clock);

    expect(find.byKey(const Key('streakBadge')), findsNothing);
    expect(find.byKey(const Key('streakBadgeButton')), findsNothing);
  });
}
