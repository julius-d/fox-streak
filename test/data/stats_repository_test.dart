import 'package:drift/drift.dart' show Value;
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
      expect(first.todayXp, 0);

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

    test('getProfile/watchProfile default displayName to null and '
        'hasOnboarded to false', () async {
      final profile = await repo.getProfile();
      expect(profile.displayName, isNull);
      expect(profile.hasOnboarded, isFalse);
      final watched = await repo.watchProfile().first;
      expect(watched.displayName, isNull);
      expect(watched.hasOnboarded, isFalse);
    });
  });

  group('setDisplayName', () {
    test('trims and persists a non-blank name', () async {
      await repo.setDisplayName('  Mia  ');
      expect((await repo.getProfile()).displayName, 'Mia');
    });

    test(
      'null/blank stores null (falls back to the generic greeting)',
      () async {
        await repo.setDisplayName('Mia');
        await repo.setDisplayName(null);
        expect((await repo.getProfile()).displayName, isNull);

        await repo.setDisplayName('Mia');
        await repo.setDisplayName('   ');
        expect((await repo.getProfile()).displayName, isNull);
      },
    );

    test('never touches hasOnboarded/other columns', () async {
      await repo.setOnboarded();
      await repo.addXp(10, now: kTestToday);
      await repo.setDisplayName('Mia');
      final profile = await repo.getProfile();
      expect(profile.hasOnboarded, isTrue);
      expect(profile.xpTotal, 10);
    });
  });

  group('setOnboarded', () {
    test('flips hasOnboarded to true and stays true', () async {
      expect((await repo.getProfile()).hasOnboarded, isFalse);
      await repo.setOnboarded();
      expect((await repo.getProfile()).hasOnboarded, isTrue);
      await repo.setOnboarded();
      expect((await repo.getProfile()).hasOnboarded, isTrue);
    });

    test('never touches displayName/other columns', () async {
      await repo.setDisplayName('Mia');
      await repo.setOnboarded();
      final profile = await repo.getProfile();
      expect(profile.displayName, 'Mia');
    });
  });

  group('getLastPracticedSetId', () {
    test('returns null when no attempts exist yet', () async {
      expect(await repo.getLastPracticedSetId(), isNull);
    });

    test(
      'returns the set of the most recent attempt across multiple sets',
      () async {
        final setA = await sets.createSet(title: 'A', createdBy: 'teacher');
        final itemA = await sets.addItem(
          setId: setA,
          type: 'phone',
          prompt: 'P',
          answer: '0171',
        );
        final setB = await sets.createSet(title: 'B', createdBy: 'teacher');
        final itemB = await sets.addItem(
          setId: setB,
          type: 'phone',
          prompt: 'P',
          answer: '0172',
        );

        await repo.recordAttempt(
          itemId: itemA,
          ok: true,
          now: DateTime(2026, 10, 10),
        );
        await repo.recordAttempt(
          itemId: itemB,
          ok: true,
          now: DateTime(2026, 10, 12),
        );
        expect(await repo.getLastPracticedSetId(), setB);

        // An even later attempt back on set A becomes the new most-recent.
        await repo.recordAttempt(
          itemId: itemA,
          ok: false,
          now: DateTime(2026, 10, 13),
        );
        expect(await repo.getLastPracticedSetId(), setA);
      },
    );

    test('falls back to an earlier set once the most-recently-attempted set '
        'is deleted (its attempts cascade away)', () async {
      final setA = await sets.createSet(title: 'A', createdBy: 'teacher');
      final itemA = await sets.addItem(
        setId: setA,
        type: 'phone',
        prompt: 'P',
        answer: '0171',
      );
      final setB = await sets.createSet(title: 'B', createdBy: 'teacher');
      final itemB = await sets.addItem(
        setId: setB,
        type: 'phone',
        prompt: 'P',
        answer: '0172',
      );
      await repo.recordAttempt(
        itemId: itemA,
        ok: true,
        now: DateTime(2026, 10, 10),
      );
      await repo.recordAttempt(
        itemId: itemB,
        ok: true,
        now: DateTime(2026, 10, 12),
      );
      expect(await repo.getLastPracticedSetId(), setB);

      await sets.deleteSet(setB);
      expect(await repo.getLastPracticedSetId(), setA);

      await sets.deleteSet(setA);
      expect(await repo.getLastPracticedSetId(), isNull);
    });
  });

  group('addXp', () {
    test(
      'adds delta to lifetime xpTotal and sets todayXp on first use',
      () async {
        await repo.addXp(10, now: kTestToday);
        final profile = await repo.getProfile();
        expect(profile.xpTotal, 10);
        expect(profile.todayXp, 10);
      },
    );

    test('resets todayXp when lastActiveDay is not today (e.g. #011 hasn\'t '
        'marked today active yet)', () async {
      await repo.addXp(10, now: kTestToday);
      await repo.addXp(5, now: kTestToday);
      final profile = await repo.getProfile();
      expect(profile.xpTotal, 15); // lifetime total always accumulates
      expect(profile.todayXp, 5); // todayXp resets: lastActiveDay stays null
    });

    test('accumulates todayXp once lastActiveDay is marked as today '
        '(#011 writes it after #010\'s XP write, per the two issues\' '
        'ordering)', () async {
      await repo.addXp(10, now: kTestToday);
      await (db.update(
        db.profileStats,
      )..where((t) => t.id.equals(kProfileId))).write(
        ProfileStatsCompanion(lastActiveDay: Value(clock.todayDayString())),
      );
      await repo.addXp(5, now: kTestToday);
      final profile = await repo.getProfile();
      expect(profile.xpTotal, 15);
      expect(profile.todayXp, 15);
    });

    test('uses clock when now omitted', () async {
      clock.setNow(kTestToday);
      await repo.addXp(10);
      expect((await repo.getProfile()).xpTotal, 10);
    });
  });

  group('setStreak', () {
    test('overwrites streakCount and lastActiveDay', () async {
      await repo.setStreak(streakCount: 3, lastActiveDay: '2026-10-11');
      final profile = await repo.getProfile();
      expect(profile.streakCount, 3);
      expect(profile.lastActiveDay, '2026-10-11');
    });

    test('a later call fully overwrites the prior values', () async {
      await repo.setStreak(streakCount: 3, lastActiveDay: '2026-10-11');
      await repo.setStreak(streakCount: 1, lastActiveDay: '2026-10-20');
      final profile = await repo.getProfile();
      expect(profile.streakCount, 1);
      expect(profile.lastActiveDay, '2026-10-20');
    });

    test('never touches xpTotal/todayXp', () async {
      await repo.addXp(10, now: kTestToday);
      await repo.setStreak(streakCount: 1, lastActiveDay: '2026-10-11');
      final profile = await repo.getProfile();
      expect(profile.xpTotal, 10);
      expect(profile.todayXp, 10);
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
        expect(after.todayXp, before.todayXp);
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
