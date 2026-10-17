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
}
