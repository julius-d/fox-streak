// Unit tests for PetService's lootbox-trigger algorithm + equip wiring
// (issue #059; #064 removed the owned-pet pool filter, making duplicate
// draws possible; #065 added the 50/50 coin-flip alternative outcome; #067
// made the trigger repeat every 3rd completion after the first, uncapped).

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/pet_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/lootbox_reward.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/stats/pet_service.dart';

import '../data/test_helpers.dart';

/// Unwraps a [PetReward]'s entry, or null for any other outcome (no
/// reward or a [CoinsReward]) — lets pre-#065 assertions written against
/// the old `wonPet` field keep reading as "the won pet, if any".
PetEntry? _wonPet(LootboxReward? reward) =>
    reward is PetReward ? reward.entry : null;

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

/// A fixed, non-random "random" that always picks the given [index] —
/// lets a test target a specific pool entry regardless of pool size.
class _FixedIndexRandom implements Random {
  _FixedIndexRandom(this.index);

  final int index;

  @override
  int nextInt(int max) => index;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

/// A fully scripted "random": [boolValue] answers every `nextBool()` call
/// (issue #065's coin-flip branch pick) and [intValue] answers every
/// `nextInt(max)` call regardless of [max] (the pet-pool index or the
/// coin-amount cumulative-weight draw) — lets a test force both the branch
/// and its sub-pick deterministically.
class _ScriptedRandom implements Random {
  _ScriptedRandom({this.boolValue = false, this.intValue = 0});

  final bool boolValue;
  final int intValue;

  @override
  bool nextBool() => boolValue;

  @override
  int nextInt(int max) => intValue;

  @override
  double nextDouble() => 0;
}

final List<PetEntry> _threePetCatalog = [
  PetCatalog.defaultEntry,
  const PetEntry(id: 'b', assetPath: 'b.json', emoji: '🐝'),
  const PetEntry(id: 'c', assetPath: 'c.json', emoji: '🦀'),
];

/// Fixture catalog pairing one seasonal pet (#063's snowman,
/// `emoji_u2603_lottie`, Dec 6-26) with one ordinary pet — isolates the
/// seasonal filter: with `_ZeroRandom`, index 0 of the season-filtered pool
/// is the snowman when in-window (pool `[snowman, c]`) and `c` when
/// out-of-window (pool `[c]`), so the same `_ZeroRandom` pick proves the
/// filter either way. No default-fox entry here — #064 made ownership
/// irrelevant to the pool, so it would otherwise just be a 3rd pool slot.
final List<PetEntry> _seasonalFixtureCatalog = [
  const PetEntry(
    id: 'emoji_u2603_lottie',
    assetPath: 'snowman.json',
    emoji: '☃️',
  ),
  const PetEntry(id: 'c', assetPath: 'c.json', emoji: '🦀'),
];

const String _kSnowmanId = 'emoji_u2603_lottie';
const String _kSpiderId = 'emoji_u1f577_lottie';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late StatsRepository statsRepo;
  late PetRepository petRepo;

  PetService buildService({List<PetEntry>? catalog}) {
    final resolvedCatalog = catalog ?? _threePetCatalog;
    return PetService(statsRepo, petRepo, clock, () async => resolvedCatalog);
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(kTestToday);
    statsRepo = StatsRepository(db, clock);
    petRepo = PetRepository(db, clock);
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
      expect(_wonPet(update.reward), isNull);
      expect(update.equippedPetId, kDefaultPetId);

      final profile = await statsRepo.getProfile();
      expect(profile.lessonsCompletedToday, 1);
      expect(profile.lessonsCompletedDay, clock.todayDayString());
    });

    test('the 2nd completion of the day wins a uniformly-random pet from '
        'the full catalog, owned or not, and persists the win', () async {
      final service = buildService();
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _FixedIndexRandom(1), // _threePetCatalog[1] == 'b'
      );

      final reward = _wonPet(update.reward);
      expect(reward, isNotNull);
      expect(reward!.id, 'b');

      final owned = await petRepo.getOwnedPetIds();
      expect(owned, containsAll(<String>[kDefaultPetId, reward.id]));
      expect(owned, hasLength(2));

      final profile = await statsRepo.getProfile();
      expect(profile.lessonsCompletedToday, 2);
    });

    test('the 3rd and 4th completions of the day do not retrigger the lootbox '
        '(issue #067: the next trigger is the 5th)', () async {
      final service = buildService();
      await service.recordLessonCompletion();
      await service.recordLessonCompletion(random: _ZeroRandom());
      final third = await service.recordLessonCompletion(random: _ZeroRandom());
      final fourth = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );

      expect(_wonPet(third.reward), isNull);
      expect(_wonPet(fourth.reward), isNull);
      final profile = await statsRepo.getProfile();
      expect(profile.lessonsCompletedToday, 4);
    });

    test(
      'issue #067: the lootbox retriggers on the 5th, 8th, and 11th '
      'completions of the day, with no trigger on the ones in between',
      () async {
        final service = buildService();
        final triggeredCounts = <int>{};
        for (var count = 1; count <= 11; count++) {
          final update = await service.recordLessonCompletion(
            random: _ZeroRandom(),
          );
          if (_wonPet(update.reward) != null) {
            triggeredCounts.add(count);
          }
        }

        expect(triggeredCounts, {2, 5, 8, 11});
        final profile = await statsRepo.getProfile();
        expect(profile.lessonsCompletedToday, 11);
      },
    );

    test('issue #067: an arbitrarily high count (50) still triggers on its '
        'matching multiple, uncapped', () async {
      final service = buildService();
      // (50 - 2) % 3 == 0, so the 50th completion is a trigger.
      for (var count = 1; count < 50; count++) {
        await service.recordLessonCompletion(random: _ZeroRandom());
      }
      final fiftieth = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );

      expect(_wonPet(fiftieth.reward), isNotNull);
      final profile = await statsRepo.getProfile();
      expect(profile.lessonsCompletedToday, 50);
    });

    test('a new local day resets the counter to 1, re-arming the trigger '
        'for that day\'s 2nd completion', () async {
      final service = buildService();
      await service.recordLessonCompletion();
      await service.recordLessonCompletion(random: _ZeroRandom());

      clock.setNow(kTestToday.add(const Duration(days: 1)));
      final firstOfNewDay = await service.recordLessonCompletion();
      expect(_wonPet(firstOfNewDay.reward), isNull);
      expect((await statsRepo.getProfile()).lessonsCompletedToday, 1);

      final secondOfNewDay = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );
      expect(_wonPet(secondOfNewDay.reward), isNotNull);
    });

    test('a fully-owned catalog still produces a wonPet, since #064 '
        'removed the unowned-only pool filter', () async {
      final service = buildService(catalog: [PetCatalog.defaultEntry]);
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ScriptedRandom(boolValue: false, intValue: 0),
      );

      expect(_wonPet(update.reward)?.id, kDefaultPetId);
      expect((await statsRepo.getProfile()).lessonsCompletedToday, 2);
    });

    test('drawing an already-owned pet is possible, incrementing its '
        'count and leaving firstAcquiredAt unchanged (issue #064)', () async {
      final service = buildService();
      final firstWin = clock.now();
      await petRepo.addOwnedPet('b', now: firstWin);

      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _FixedIndexRandom(1), // _threePetCatalog[1] == 'b'
      );

      expect(_wonPet(update.reward)!.id, 'b');
      final row = await (db.select(
        db.ownedPets,
      )..where((t) => t.petId.equals('b'))).getSingle();
      expect(row.count, 2);
      expect(row.firstAcquiredAt, firstWin.millisecondsSinceEpoch);
    });

    test('equippedPetId in the return value matches the profile row, '
        'even on completions that skip the lootbox', () async {
      final service = buildService();
      await service.equip('b');
      final update = await service.recordLessonCompletion();
      expect(update.equippedPetId, 'b');
    });
  });

  group('recordLessonCompletion coin reward (#065)', () {
    test('the coin-flip branch (nextBool()==true) wins coins, never a '
        'pet, and never touches the pet pool', () async {
      final service = buildService(catalog: const []);
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ScriptedRandom(boolValue: true, intValue: 0),
      );

      expect(update.reward, isA<CoinsReward>());
      expect((update.reward as CoinsReward).amount, 5);
    });

    test('the pet-flip branch (nextBool()==false) wins a pet, never '
        'coins (#064 unchanged)', () async {
      final service = buildService();
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ScriptedRandom(boolValue: false, intValue: 0),
      );

      expect(update.reward, isA<PetReward>());
    });

    test('coinsTotal accumulates across repeated coin wins', () async {
      final service = buildService();
      await service.recordLessonCompletion();
      await service.recordLessonCompletion(
        random: _ScriptedRandom(boolValue: true, intValue: 0), // -> 5 coins
      );
      expect((await statsRepo.getProfile()).coinsTotal, 5);

      clock.setNow(kTestToday.add(const Duration(days: 1)));
      await service.recordLessonCompletion();
      await service.recordLessonCompletion(
        random: _ScriptedRandom(
          boolValue: true,
          intValue: 1049,
        ), // -> 100 coins
      );
      expect((await statsRepo.getProfile()).coinsTotal, 105);
    });
  });

  group('drawCoinAmount (#065)', () {
    test('the cumulative-weight table: boundary draws land on the right '
        'amount', () {
      // weight(5) == 100, so draws 0..99 land on 5.
      expect(drawCoinAmount(_ScriptedRandom(intValue: 0)), 5);
      expect(drawCoinAmount(_ScriptedRandom(intValue: 99)), 5);
      // weight(10) == 95, the next bucket: draws 100..194 land on 10.
      expect(drawCoinAmount(_ScriptedRandom(intValue: 100)), 10);
      // weight(95) == 10, the second-to-last bucket: draws 1035..1044.
      expect(drawCoinAmount(_ScriptedRandom(intValue: 1044)), 95);
      // weight(100) == 5, the last bucket: draws 1045..1049.
      expect(drawCoinAmount(_ScriptedRandom(intValue: 1045)), 100);
      expect(drawCoinAmount(_ScriptedRandom(intValue: 1049)), 100);
    });

    test('distribution sanity: 5 is drawn more often than 100 over many '
        'seeded trials, matching their 20x weight ratio', () {
      final random = Random(42);
      var fiveCount = 0;
      var hundredCount = 0;
      for (var i = 0; i < 5000; i++) {
        final amount = drawCoinAmount(random);
        if (amount == 5) fiveCount++;
        if (amount == 100) hundredCount++;
      }
      expect(fiveCount, greaterThan(hundredCount));
    });
  });

  group('equip', () {
    test('sets equippedPetId and nothing else', () async {
      final service = buildService();
      await service.equip('b');

      final profile = await statsRepo.getProfile();
      expect(profile.equippedPetId, 'b');
      expect(profile.lessonsCompletedToday, 0);
      expect(profile.lessonsCompletedDay, isNull);
    });
  });

  group('recordLessonCompletion seasonal exclusion (#063)', () {
    Future<PetEntry?> winOnDate(DateTime date) async {
      clock.setNow(date);
      final service = buildService(catalog: _seasonalFixtureCatalog);
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );
      return _wonPet(update.reward);
    }

    test('in-window: the snowman is eligible and can be won (pool is '
        '[snowman, c], _ZeroRandom picks the first)', () async {
      final reward = await winOnDate(DateTime(2026, 12, 15));
      expect(reward?.id, _kSnowmanId);
    });

    test('out-of-window: the snowman is excluded from the pool, leaving only '
        'the ordinary pet winnable', () async {
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
        'in the defensive zero-time-eligible-entries edge case — the only '
        "catalog entry is a seasonal one that's out of window", () async {
      clock.setNow(DateTime(2026, 6, 1));
      final service = buildService(
        catalog: [
          const PetEntry(
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
      expect(_wonPet(update.reward), isNull);
      expect((await statsRepo.getProfile()).lessonsCompletedToday, 2);
    });
  });

  group('recordLessonCompletion spider seasonal exclusion (#063)', () {
    // No default-fox entry — see _seasonalFixtureCatalog's doc comment for
    // why: with `_ZeroRandom`, index 0 of the season-filtered pool is the
    // spider when in-window (`[spider, c]`) and `c` when out-of-window
    // (`[c]`).
    Future<PetEntry?> winOnDate(DateTime date) async {
      clock.setNow(date);
      final service = buildService(
        catalog: [
          const PetEntry(
            id: _kSpiderId,
            assetPath: 'spider.json',
            emoji: '🕷️',
          ),
          const PetEntry(id: 'c', assetPath: 'c.json', emoji: '🦀'),
        ],
      );
      await service.recordLessonCompletion();
      final update = await service.recordLessonCompletion(
        random: _ZeroRandom(),
      );
      return _wonPet(update.reward);
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
