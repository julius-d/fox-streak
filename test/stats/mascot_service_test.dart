// Unit tests for MascotService's lootbox-trigger algorithm + equip wiring
// (issue #059).

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/mascot_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/mascot/mascot_catalog.dart';
import 'package:fox_streak_app/src/stats/mascot_service.dart';

import '../data/test_helpers.dart';

/// A fixed, non-random "random" for deterministic reward selection in tests
/// — always picks the first candidate `nextInt` is asked to range over.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

final List<MascotEntry> _threeMascotCatalog = [
  MascotCatalog.defaultEntry,
  const MascotEntry(id: 'b', assetPath: 'b.json', emoji: '🐝'),
  const MascotEntry(id: 'c', assetPath: 'c.json', emoji: '🦀'),
];

/// Fixture catalog pairing the default (always owned in these tests) with
/// one seasonal mascot (#063's snowman, `emoji_u2603_lottie`, Dec 6-26) and
/// one ordinary mascot — isolates the seasonal filter from the "is the pool
/// non-empty" check.
final List<MascotEntry> _seasonalFixtureCatalog = [
  MascotCatalog.defaultEntry,
  const MascotEntry(
    id: 'emoji_u2603_lottie',
    assetPath: 'snowman.json',
    emoji: '☃️',
  ),
  const MascotEntry(id: 'c', assetPath: 'c.json', emoji: '🦀'),
];

const String _kSnowmanId = 'emoji_u2603_lottie';
const String _kSpiderId = 'emoji_u1f577_lottie';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late StatsRepository statsRepo;
  late MascotRepository mascotRepo;

  MascotService buildService({List<MascotEntry>? catalog}) {
    final resolvedCatalog = catalog ?? _threeMascotCatalog;
    return MascotService(
      statsRepo,
      mascotRepo,
      clock,
      () async => resolvedCatalog,
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(kTestToday);
    statsRepo = StatsRepository(db, clock);
    mascotRepo = MascotRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('recordLessonCompletion', () {
    test('the 1st completion of the day bumps the counter to 1 but never '
        'shows a lootbox', () async {
      final service = buildService();
      final update = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );
      expect(update.wonMascot, isNull);
      expect(update.equippedMascotId, kDefaultMascotId);

      final profile = await statsRepo.getProfile();
      expect(profile.lessonsCompletedToday, 1);
      expect(profile.lessonsCompletedDay, clock.todayDayString());
    });

    test('the 2nd completion of the day wins a uniformly-random unowned '
        'mascot and persists it as owned', () async {
      final service = buildService();
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );

      final reward = update.wonMascot;
      expect(reward, isNotNull);
      expect(reward!.id, isNot(kDefaultMascotId)); // default is already owned

      final owned = await mascotRepo.getOwnedMascotIds();
      expect(owned, containsAll(<String>[kDefaultMascotId, reward.id]));
      expect(owned, hasLength(2));

      final profile = await statsRepo.getProfile();
      expect(profile.lessonsCompletedToday, 2);
    });

    test(
      'the 3rd+ completion of the day never retriggers the lootbox',
      () async {
        final service = buildService();
        await service.recordLessonCompletion();
        await service.recordLessonCompletion(random: _ZeroRandom());
        final third = await service.recordLessonCompletion(
          random: _ZeroRandom(),
        );

        expect(third.wonMascot, isNull);
        final profile = await statsRepo.getProfile();
        expect(profile.lessonsCompletedToday, 3);
      },
    );

    test('a new local day resets the counter to 1, re-arming the trigger '
        'for that day\'s 2nd completion', () async {
      final service = buildService();
      await service.recordLessonCompletion();
      await service.recordLessonCompletion(random: _ZeroRandom());

      clock.setNow(kTestToday.add(const Duration(days: 1)));
      final firstOfNewDay = await service.recordLessonCompletion();
      expect(firstOfNewDay.wonMascot, isNull);
      expect((await statsRepo.getProfile()).lessonsCompletedToday, 1);

      final secondOfNewDay = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );
      expect(secondOfNewDay.wonMascot, isNotNull);
    });

    test('the lootbox is skipped when the full catalog is already owned, '
        'but the counter still advances', () async {
      final service = buildService(catalog: [MascotCatalog.defaultEntry]);
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion();

      expect(update.wonMascot, isNull);
      expect((await statsRepo.getProfile()).lessonsCompletedToday, 2);
    });

    test('never re-wins a mascot already owned from a prior lootbox', () async {
      final service = buildService();
      await mascotRepo.addOwnedMascot('b', now: clock.now());

      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );

      expect(update.wonMascot!.id, 'c'); // only unowned entry left
    });

    test('equippedMascotId in the return value matches the profile row, '
        'even on completions that skip the lootbox', () async {
      final service = buildService();
      await service.equip('b');
      final update = await service.recordLessonCompletion();
      expect(update.equippedMascotId, 'b');
    });
  });

  group('equip', () {
    test('sets equippedMascotId and nothing else', () async {
      final service = buildService();
      await service.equip('b');

      final profile = await statsRepo.getProfile();
      expect(profile.equippedMascotId, 'b');
      expect(profile.lessonsCompletedToday, 0);
      expect(profile.lessonsCompletedDay, isNull);
    });
  });

  group('recordLessonCompletion seasonal exclusion (#063)', () {
    Future<MascotEntry?> winOnDate(DateTime date) async {
      clock.setNow(date);
      final service = buildService(catalog: _seasonalFixtureCatalog);
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );
      return update.wonMascot;
    }

    test('in-window: the snowman is eligible and can be won (pool is '
        '[snowman, c], _ZeroRandom picks the first)', () async {
      final reward = await winOnDate(DateTime(2026, 12, 15));
      expect(reward?.id, _kSnowmanId);
    });

    test('out-of-window: the snowman is excluded from the pool, leaving only '
        'the ordinary mascot winnable', () async {
      final reward = await winOnDate(DateTime(2026, 11, 1));
      expect(reward?.id, 'c');
    });

    test('boundary: Dec 5 excludes the snowman', () async {
      expect((await winOnDate(DateTime(2026, 12, 5)))?.id, 'c');
    });

    test('boundary: Dec 6 includes the snowman', () async {
      expect((await winOnDate(DateTime(2026, 12, 6)))?.id, _kSnowmanId);
    });

    test('boundary: Dec 26 includes the snowman', () async {
      expect((await winOnDate(DateTime(2026, 12, 26)))?.id, _kSnowmanId);
    });

    test('boundary: Dec 27 excludes the snowman', () async {
      expect((await winOnDate(DateTime(2026, 12, 27)))?.id, 'c');
    });

    test('the lootbox is skipped entirely (no win, counter still advances) '
        "when the only unowned mascot is a seasonal one that's out of "
        'window', () async {
      clock.setNow(DateTime(2026, 6, 1));
      final service = buildService(
        catalog: [
          MascotCatalog.defaultEntry,
          const MascotEntry(
            id: _kSnowmanId,
            assetPath: 'snowman.json',
            emoji: '☃️',
          ),
        ],
      );
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );
      expect(update.wonMascot, isNull);
      expect((await statsRepo.getProfile()).lessonsCompletedToday, 2);
    });
  });

  group('recordLessonCompletion spider seasonal exclusion (#063)', () {
    Future<MascotEntry?> winOnDate(DateTime date) async {
      clock.setNow(date);
      final service = buildService(
        catalog: [
          MascotCatalog.defaultEntry,
          const MascotEntry(
            id: _kSpiderId,
            assetPath: 'spider.json',
            emoji: '🕷️',
          ),
          const MascotEntry(id: 'c', assetPath: 'c.json', emoji: '🦀'),
        ],
      );
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );
      return update.wonMascot;
    }

    test('boundary: Oct 24 excludes the spider', () async {
      expect((await winOnDate(DateTime(2026, 10, 24)))?.id, 'c');
    });

    test('boundary: Oct 25 includes the spider', () async {
      expect((await winOnDate(DateTime(2026, 10, 25)))?.id, _kSpiderId);
    });

    test('boundary: Nov 1 includes the spider', () async {
      expect((await winOnDate(DateTime(2026, 11, 1)))?.id, _kSpiderId);
    });

    test('boundary: Nov 2 excludes the spider', () async {
      expect((await winOnDate(DateTime(2026, 11, 2)))?.id, 'c');
    });
  });
}
