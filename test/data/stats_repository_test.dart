import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late StatsRepository repo;
  late SetsRepository sets;
  late FakeClock clock;

  setUp(() {
    db = makeTestDb();
    clock = FakeClock(kTestToday);
    repo = StatsRepository(db, clock);
    sets = SetsRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedItem() async {
    final setId = await sets.createSet(title: 'S', createdBy: 'teacher');
    return sets.addItem(
      setId: setId,
      type: 'phone',
      prompt: 'P',
      answer: '0171',
    );
  }

  group('profile', () {
    test('getProfile creates default row once (id 0)', () async {
      final first = await repo.getProfile();
      expect(first.id, kProfileId);
      expect(first.xpTotal, 0);
      expect(first.streakCount, 0);
      expect(first.lastActiveDay, isNull);
      expect(first.dailyGoalXp, kDefaultDailyGoalXp);

      final second = await repo.getProfile();
      expect(second.id, kProfileId);
      final rows = await (db.select(db.profileStats)).get();
      expect(rows, hasLength(1));
    });

    test('watchProfile emits defaults before first write', () async {
      final profile = await repo.watchProfile().first;
      expect(profile.id, kProfileId);
      expect(profile.dailyGoalXp, kDefaultDailyGoalXp);
    });

    test('updateDailyGoal persists; rejects negatives', () async {
      await repo.updateDailyGoal(50);
      expect((await repo.getProfile()).dailyGoalXp, 50);
      expect(() => repo.updateDailyGoal(-1), throwsArgumentError);
    });
  });

  group('recordAttempt', () {
    test('writes one attempts row with ok/at', () async {
      final itemId = await seedItem();
      final at = DateTime(2026, 10, 11, 9, 30);
      final id = await repo.recordAttempt(itemId: itemId, ok: true, now: at);
      expect(id, isPositive);
      final rows = await repo.getAttemptsForItem(itemId);
      expect(rows, hasLength(1));
      expect(rows.single.ok, isTrue);
      expect(rows.single.at, at.millisecondsSinceEpoch);
    });

    test('uses clock when now omitted', () async {
      final itemId = await seedItem();
      clock.setNow(DateTime(2026, 10, 11, 20));
      await repo.recordAttempt(itemId: itemId, ok: false);
      final rows = await repo.getAttemptsForItem(itemId);
      expect(rows.single.at, clock.now().millisecondsSinceEpoch);
    });

    test(
      'MUST NOT touch xp/streak/lastActiveDay (owned by #010/#011)',
      () async {
        final itemId = await seedItem();
        final before = await repo.getProfile();
        await repo.recordAttempt(itemId: itemId, ok: true);
        final after = await repo.getProfile();
        expect(after.xpTotal, before.xpTotal);
        expect(after.streakCount, before.streakCount);
        expect(after.lastActiveDay, before.lastActiveDay);
      },
    );

    test('ensures profile row exists as a side effect', () async {
      final itemId = await seedItem();
      expect(await (db.select(db.profileStats)).get(), isEmpty);
      await repo.recordAttempt(itemId: itemId, ok: true);
      expect(await (db.select(db.profileStats)).get(), hasLength(1));
    });

    test('counts and limits attempts', () async {
      final itemId = await seedItem();
      await repo.recordAttempt(itemId: itemId, ok: true);
      await repo.recordAttempt(itemId: itemId, ok: false);
      await repo.recordAttempt(itemId: itemId, ok: true);
      expect(await repo.countAttempts(), 3);
      expect(await repo.countAttempts(ok: true), 2);
      expect(await repo.countAttempts(ok: false), 1);
      expect(await repo.getAttemptsForItem(itemId, limit: 2), hasLength(2));
    });
  });
}
