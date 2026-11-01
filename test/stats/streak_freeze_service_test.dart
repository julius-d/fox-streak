// Unit tests for StreakFreezeService's app-launch auto-apply (issue #087).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/stats/streak_freeze_service.dart';

import '../data/test_helpers.dart';

void main() {
  late AppDatabase db;
  late StatsRepository statsRepo;
  late FakeClock clock;
  late StreakFreezeService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(kTestToday);
    statsRepo = StatsRepository(db, clock);
    service = StreakFreezeService(statsRepo, clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('checkAndApplyOnLaunch', () {
    test('exactly one missed day + a freeze available: consumes one '
        'freeze, writes the missed day as streakOnIce/0xp, and bridges '
        'lastActiveDay to it, leaving streakCount unchanged', () async {
      final twoDaysAgo = kTestToday.subtract(const Duration(days: 2));
      final yesterday = kTestToday.subtract(const Duration(days: 1));
      await statsRepo.setStreak(
        streakCount: 5,
        lastActiveDay: FakeClock(twoDaysAgo).todayDayString(),
      );
      await statsRepo.addStreakFreezes(1);

      final applied = await service.checkAndApplyOnLaunch();
      expect(applied, isTrue);

      final profile = await statsRepo.getProfile();
      expect(profile.streakFreezesAvailable, 0);
      expect(profile.streakCount, 5);
      final yesterdayString = FakeClock(yesterday).todayDayString();
      expect(profile.lastActiveDay, yesterdayString);

      final row = await (db.select(
        db.dailyActivity,
      )..where((t) => t.day.equals(yesterdayString))).getSingle();
      expect(row.activitySource, DailyActivitySource.streakOnIce.name);
      expect(row.xpEarned, 0);
    });

    test(
      'no freeze available: no-op even with exactly one missed day',
      () async {
        final twoDaysAgo = kTestToday.subtract(const Duration(days: 2));
        await statsRepo.setStreak(
          streakCount: 5,
          lastActiveDay: FakeClock(twoDaysAgo).todayDayString(),
        );

        final applied = await service.checkAndApplyOnLaunch();
        expect(applied, isFalse);

        final profile = await statsRepo.getProfile();
        expect(profile.streakCount, 5);
        expect(profile.lastActiveDay, FakeClock(twoDaysAgo).todayDayString());
      },
    );

    test('a gap of 2+ full missed days: no-op, no freeze spent, even with '
        'one available (multi-day bridging is out of scope)', () async {
      final threeDaysAgo = kTestToday.subtract(const Duration(days: 3));
      await statsRepo.setStreak(
        streakCount: 5,
        lastActiveDay: FakeClock(threeDaysAgo).todayDayString(),
      );
      await statsRepo.addStreakFreezes(1);

      final applied = await service.checkAndApplyOnLaunch();
      expect(applied, isFalse);

      final profile = await statsRepo.getProfile();
      expect(profile.streakFreezesAvailable, 1);
      expect(profile.streakCount, 5);
      expect(profile.lastActiveDay, FakeClock(threeDaysAgo).todayDayString());
    });

    test('lastActiveDay is today: no-op (no gap to bridge)', () async {
      await statsRepo.setStreak(
        streakCount: 3,
        lastActiveDay: clock.todayDayString(),
      );
      await statsRepo.addStreakFreezes(1);

      expect(await service.checkAndApplyOnLaunch(), isFalse);
      expect((await statsRepo.getProfile()).streakFreezesAvailable, 1);
    });

    test('lastActiveDay is yesterday: no-op (an ordinary one-day gap, not '
        'a missed day)', () async {
      final yesterday = kTestToday.subtract(const Duration(days: 1));
      await statsRepo.setStreak(
        streakCount: 3,
        lastActiveDay: FakeClock(yesterday).todayDayString(),
      );
      await statsRepo.addStreakFreezes(1);

      expect(await service.checkAndApplyOnLaunch(), isFalse);
      expect((await statsRepo.getProfile()).streakFreezesAvailable, 1);
    });

    test('no prior activity (lastActiveDay null): no-op', () async {
      await statsRepo.addStreakFreezes(1);
      expect(await service.checkAndApplyOnLaunch(), isFalse);
      expect((await statsRepo.getProfile()).streakFreezesAvailable, 1);
    });

    test(
      'a second call on the same launch is safe/idempotent: the first '
      'call already bridged lastActiveDay, so the second finds no gap',
      () async {
        final twoDaysAgo = kTestToday.subtract(const Duration(days: 2));
        await statsRepo.setStreak(
          streakCount: 1,
          lastActiveDay: FakeClock(twoDaysAgo).todayDayString(),
        );
        await statsRepo.addStreakFreezes(2);

        expect(await service.checkAndApplyOnLaunch(), isTrue);
        expect(await service.checkAndApplyOnLaunch(), isFalse);
        expect((await statsRepo.getProfile()).streakFreezesAvailable, 1);
      },
    );
  });
}
