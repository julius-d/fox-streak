// Unit tests for XpService's formulas + applyLessonResult wiring (issue #010).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/stats/xp_service.dart';

import '../data/test_helpers.dart';

LessonItemOutcome correctNoHint({int itemId = 1}) =>
    LessonItemOutcome(itemId: itemId, correct: true, skipped: false);

LessonItemOutcome correctWithHint({int itemId = 1}) => LessonItemOutcome(
  itemId: itemId,
  correct: true,
  skipped: false,
  hintUsed: true,
);

LessonItemOutcome wrong({int itemId = 1}) =>
    LessonItemOutcome(itemId: itemId, correct: false, skipped: false);

LessonItemOutcome skipped({int itemId = 1}) =>
    LessonItemOutcome(itemId: itemId, correct: false, skipped: true);

LessonResult resultOf(List<LessonItemOutcome> outcomes, {int setId = 1}) {
  final correctCount = outcomes.where((o) => o.correct).length;
  final scorePct = outcomes.isEmpty
      ? 0
      : ((correctCount / outcomes.length) * 100).round();
  return LessonResult(
    setId: setId,
    itemIds: outcomes.map((o) => o.itemId).toList(),
    outcomes: outcomes,
    correctCount: correctCount,
    scorePct: scorePct,
  );
}

void main() {
  group('xpForOutcome', () {
    test('correct, no hint = 10 XP', () {
      expect(XpService.xpForOutcome(correctNoHint()), 10);
    });

    test('correct, hint used = 5 XP', () {
      expect(XpService.xpForOutcome(correctWithHint()), 5);
    });

    test('wrong = 0 XP', () {
      expect(XpService.xpForOutcome(wrong()), 0);
    });

    test('skipped = 0 XP', () {
      expect(XpService.xpForOutcome(skipped()), 0);
    });
  });

  group('lessonBonus', () {
    test('+5 when scorePct == 100', () {
      final result = resultOf([correctNoHint(), correctNoHint(itemId: 2)]);
      expect(result.scorePct, 100);
      expect(XpService.lessonBonus(result), 5);
    });

    test('0 when scorePct < 100', () {
      final result = resultOf([correctNoHint(), wrong(itemId: 2)]);
      expect(result.scorePct, 50);
      expect(XpService.lessonBonus(result), 0);
    });
  });

  group('xpEarned', () {
    test('sums per-item XP plus the perfect bonus', () {
      final result = resultOf([correctNoHint(), correctWithHint(itemId: 2)]);
      // 10 (no hint) + 5 (hint) + 5 (perfect bonus) = 20
      expect(XpService.xpEarned(result), 20);
    });

    test('mixed outcomes, no bonus', () {
      final result = resultOf([
        correctNoHint(),
        correctWithHint(itemId: 2),
        wrong(itemId: 3),
        skipped(itemId: 4),
      ]);
      // 10 + 5 + 0 + 0 = 15, scorePct=50 so no bonus
      expect(XpService.xpEarned(result), 15);
    });
  });

  group('levelForXp', () {
    test('xp=0 is level 1', () {
      expect(XpService.levelForXp(0), 1);
    });

    test('xp just below a threshold stays at the lower level', () {
      expect(XpService.levelForXp(99), 1);
    });

    test('xp exactly at a threshold reaches the next level', () {
      expect(XpService.levelForXp(100), 2);
      expect(XpService.levelForXp(400), 3);
      expect(XpService.levelForXp(900), 4);
    });

    test('large xp values', () {
      expect(XpService.levelForXp(1000000), XpService.levelForXp(1000000));
      expect(XpService.levelForXp(10000), 11);
    });
  });

  group('xpForLevel', () {
    test('level 1 requires 0 XP', () {
      expect(XpService.xpForLevel(1), 0);
    });

    test('matches (n-1)^2 * 100', () {
      expect(XpService.xpForLevel(2), 100);
      expect(XpService.xpForLevel(3), 400);
      expect(XpService.xpForLevel(11), 10000);
    });
  });

  group('progressToNextLevel', () {
    test('0 progress right at a level threshold', () {
      expect(XpService.progressToNextLevel(0), 0);
      expect(XpService.progressToNextLevel(100), 0);
    });

    test('fractional progress mid-level', () {
      // level 1 spans 0..100; 50 xp is halfway.
      expect(XpService.progressToNextLevel(50), closeTo(0.5, 1e-9));
    });

    test('just below the next threshold', () {
      // level 2 spans 100..400 (300 wide); 400 - 1 => (299/300).
      expect(XpService.progressToNextLevel(399), closeTo(299 / 300, 1e-9));
    });
  });

  group('applyLessonResult', () {
    late AppDatabase db;
    late StatsRepository statsRepo;
    late FakeClock clock;
    late XpService xpService;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      clock = FakeClock(kTestToday);
      statsRepo = StatsRepository(db, clock);
      xpService = XpService(statsRepo, clock);
    });

    tearDown(() async {
      await db.close();
    });

    test('writes earned XP to xpTotal and todayXp, returns both', () async {
      final result = resultOf([correctNoHint(), correctNoHint(itemId: 2)]);
      final application = await xpService.applyLessonResult(result);
      expect(application.earned, 25); // 10 + 10 + 5 perfect bonus
      expect(application.xpTotal, 25);

      final profile = await statsRepo.getProfile();
      expect(profile.xpTotal, 25);
      expect(profile.todayXp, 25);
    });

    test(
      'accumulates xpTotal across multiple applyLessonResult calls',
      () async {
        // One wrong answer each time keeps scorePct < 100 so the perfect
        // bonus doesn't muddy the accumulation math.
        await xpService.applyLessonResult(
          resultOf([correctNoHint(), wrong(itemId: 99)]),
        );
        await xpService.applyLessonResult(
          resultOf([correctWithHint(itemId: 2), wrong(itemId: 99)]),
        );

        final profile = await statsRepo.getProfile();
        expect(profile.xpTotal, 15); // 10 + 5
      },
    );

    test('todayXp resets on a day change, accumulates same-day', () async {
      // Simulate #011 having already recorded today as the active day.
      clock.setNow(kTestToday);
      await statsRepo.addXp(0, now: kTestToday); // ensures profile exists
      Future<void> setLastActiveDay(String? day) =>
          (db.update(db.profileStats)..where((t) => t.id.equals(kProfileId)))
              .write(ProfileStatsCompanion(lastActiveDay: Value(day)));
      await setLastActiveDay(null);

      await xpService.applyLessonResult(
        resultOf([correctNoHint(), wrong(itemId: 99)]),
      );
      var profile = await statsRepo.getProfile();
      expect(profile.todayXp, 10);

      // Pretend #011 marked today as the active day; a same-day lesson
      // should accumulate, not reset.
      await setLastActiveDay(clock.todayDayString());
      await xpService.applyLessonResult(
        resultOf([correctNoHint(itemId: 3), wrong(itemId: 99)]),
      );
      profile = await statsRepo.getProfile();
      expect(profile.todayXp, 20);
      expect(profile.xpTotal, 20);

      // A day later, todayXp resets to just the new lesson's XP.
      clock.setNow(kTestToday.add(const Duration(days: 1)));
      await xpService.applyLessonResult(
        resultOf([correctWithHint(itemId: 5), wrong(itemId: 99)]),
      );
      profile = await statsRepo.getProfile();
      expect(profile.todayXp, 5);
      expect(profile.xpTotal, 25); // lifetime total keeps accumulating
    });
  });
}
