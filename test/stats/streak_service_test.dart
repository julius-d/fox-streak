// Unit tests for StreakService's day algorithm + recordActivity wiring
// (issue #011).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/stats/streak_service.dart';

import '../data/test_helpers.dart';

void main() {
  group('computeNext (day-boundary matrix)', () {
    final today = DateTime(2026, 10, 13, 9, 30);

    test('no prior activity -> streak starts at 1', () {
      final update = StreakService.computeNext(
        now: today,
        currentStreak: 0,
        lastActiveDay: null,
      );
      expect(update.streakCount, 1);
      expect(update.lastActiveDay, '2026-10-13');
      expect(update.isNewDay, isTrue);
    });

    test('same local day as last activity -> unchanged, not a new day', () {
      final update = StreakService.computeNext(
        now: today,
        currentStreak: 5,
        lastActiveDay: '2026-10-13',
      );
      expect(update.streakCount, 5);
      expect(update.lastActiveDay, '2026-10-13');
      expect(update.isNewDay, isFalse);
    });

    test('same local day, late-night edge (23:59 vs next-day replay)', () {
      final lateNight = DateTime(2026, 10, 13, 23, 59);
      final update = StreakService.computeNext(
        now: lateNight,
        currentStreak: 2,
        lastActiveDay: '2026-10-13',
      );
      expect(update.streakCount, 2);
      expect(update.isNewDay, isFalse);
    });

    test('consecutive local day -> streak + 1', () {
      final update = StreakService.computeNext(
        now: today,
        currentStreak: 5,
        lastActiveDay: '2026-10-12',
      );
      expect(update.streakCount, 6);
      expect(update.lastActiveDay, '2026-10-13');
      expect(update.isNewDay, isTrue);
    });

    test('consecutive local day, early-morning edge (just past midnight)', () {
      final justAfterMidnight = DateTime(2026, 10, 13, 0, 5);
      final update = StreakService.computeNext(
        now: justAfterMidnight,
        currentStreak: 5,
        lastActiveDay: '2026-10-12',
      );
      expect(update.streakCount, 6);
      expect(update.lastActiveDay, '2026-10-13');
      expect(update.isNewDay, isTrue);
    });

    test('day boundary the day after a DST spring-forward uses calendar-field '
        'subtraction, not a 24h wall-clock duration (regression)', () {
      // 2026-03-29 is the EU spring-forward DST date (clocks skip
      // 02:00->03:00 CEST), so that calendar day is only 23 wall-clock
      // hours long. In a DST-observing zone, `now.subtract(Duration(days:
      // 1))` for an early-morning `now` on the day *after* the transition
      // (2026-03-30) would land one calendar day too far back
      // (2026-03-28 instead of 2026-03-29), wrongly treating a kept
      // streak as a missed day. Calendar-field subtraction always lands
      // on the correct prior date, regardless of the host's DST table.
      final update = StreakService.computeNext(
        now: DateTime(2026, 3, 30, 0, 30),
        currentStreak: 4,
        lastActiveDay: '2026-03-29',
      );
      expect(update.streakCount, 5);
      expect(update.lastActiveDay, '2026-03-30');
      expect(update.isNewDay, isTrue);
    });

    test('gap of exactly 2 days -> resets to 1', () {
      final update = StreakService.computeNext(
        now: today,
        currentStreak: 5,
        lastActiveDay: '2026-10-11',
      );
      expect(update.streakCount, 1);
      expect(update.lastActiveDay, '2026-10-13');
      expect(update.isNewDay, isTrue);
    });

    test('gap of many days -> resets to 1', () {
      final update = StreakService.computeNext(
        now: today,
        currentStreak: 42,
        lastActiveDay: '2026-01-01',
      );
      expect(update.streakCount, 1);
      expect(update.isNewDay, isTrue);
    });

    test('a month boundary counts as consecutive when the dates are '
        'actually adjacent', () {
      final update = StreakService.computeNext(
        now: DateTime(2026, 11, 1, 10),
        currentStreak: 3,
        lastActiveDay: '2026-10-31',
      );
      expect(update.streakCount, 4);
      expect(update.lastActiveDay, '2026-11-01');
      expect(update.isNewDay, isTrue);
    });
  });

  group('isMilestone', () {
    test('all six v1 milestone values are detected', () {
      for (final value in [3, 7, 14, 30, 50, 100]) {
        expect(StreakService.isMilestone(value), isTrue, reason: '$value');
      }
    });

    test('non-milestone values are not detected', () {
      for (final value in [0, 1, 2, 4, 6, 8, 13, 15, 29, 31, 49, 51, 99, 101]) {
        expect(StreakService.isMilestone(value), isFalse, reason: '$value');
      }
    });
  });

  group('recordActivity', () {
    late AppDatabase db;
    late StatsRepository statsRepo;
    late FakeClock clock;
    late StreakService streakService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      clock = FakeClock(kTestToday);
      statsRepo = StatsRepository(db, clock);
      streakService = StreakService(statsRepo, clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('first ever call sets streak_count to 1 and persists today', () async {
      final update = await streakService.recordActivity();
      expect(update.streakCount, 1);
      expect(update.isNewDay, isTrue);

      final profile = await statsRepo.getProfile();
      expect(profile.streakCount, 1);
      expect(profile.lastActiveDay, clock.todayDayString());
    });

    test('a same-day replay never double-counts', () async {
      await streakService.recordActivity();
      final second = await streakService.recordActivity();
      expect(second.streakCount, 1);
      expect(second.isNewDay, isFalse);

      final profile = await statsRepo.getProfile();
      expect(profile.streakCount, 1);
    });

    test('consecutive-day calls increment, and a gap resets', () async {
      await streakService.recordActivity(); // day 1 -> streak 1
      clock.setNow(kTestToday.add(const Duration(days: 1)));
      await streakService.recordActivity(); // day 2 -> streak 2
      clock.setNow(kTestToday.add(const Duration(days: 2)));
      await streakService.recordActivity(); // day 3 -> streak 3

      var profile = await statsRepo.getProfile();
      expect(profile.streakCount, 3);

      // Skip a day entirely -> resets to 1.
      clock.setNow(kTestToday.add(const Duration(days: 5)));
      final afterGap = await streakService.recordActivity();
      expect(afterGap.streakCount, 1);

      profile = await statsRepo.getProfile();
      expect(profile.streakCount, 1);
    });

    test('simulated rebuild (repeated recordActivity call for the same lesson) '
        'does not double-apply when the caller only invokes it once per '
        'completed lesson', () async {
      // StreakService itself has no re-entrancy guard — LessonController's
      // shared xpApplied gate is what prevents a second call per lesson
      // (covered in lesson_controller_streak_test.dart). This test just
      // confirms recordActivity's own same-day idempotence, which is what
      // makes that guard sufficient rather than load-bearing on its own.
      await streakService.recordActivity();
      await streakService.recordActivity();
      await streakService.recordActivity();

      final profile = await statsRepo.getProfile();
      expect(profile.streakCount, 1);
    });
  });
}
