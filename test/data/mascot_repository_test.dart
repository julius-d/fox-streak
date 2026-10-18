// Unit tests for MascotRepository's `owned_mascots` table wiring
// (issue #059, duplicate-draw counting added in #064).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/mascot_repository.dart';
import 'package:fox_streak_app/src/mascot/mascot_catalog.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late MascotRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(kTestToday);
    repo = MascotRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('getOwnedMascotIds', () {
    test('seeds the default fox as owned on first use', () async {
      final owned = await repo.getOwnedMascotIds();
      expect(owned, [kDefaultMascotId]);
    });

    test('seeding is idempotent across repeated calls', () async {
      await repo.getOwnedMascotIds();
      final owned = await repo.getOwnedMascotIds();
      expect(owned, [kDefaultMascotId]);
    });
  });

  group('addOwnedMascot', () {
    test('persists a new mascot as owned', () async {
      await repo.addOwnedMascot('emoji_u1f980_lottie', now: clock.now());
      final owned = await repo.getOwnedMascotIds();
      expect(
        owned,
        containsAll(<String>[kDefaultMascotId, 'emoji_u1f980_lottie']),
      );
      expect(owned, hasLength(2));
    });

    test('recording the same mascot twice does not duplicate the row, but '
        'increments its count (issue #064)', () async {
      await repo.addOwnedMascot('emoji_u1f980_lottie', now: clock.now());
      await repo.addOwnedMascot('emoji_u1f980_lottie', now: clock.now());
      final owned = await repo.getOwnedMascotIds();
      expect(owned.where((id) => id == 'emoji_u1f980_lottie'), hasLength(1));

      final row = await (db.select(
        db.ownedMascots,
      )..where((t) => t.mascotId.equals('emoji_u1f980_lottie'))).getSingle();
      expect(row.count, 2);
    });

    test('firstAcquiredAt stays pinned to the first win across repeat draws '
        '(issue #064)', () async {
      final firstWin = clock.now();
      await repo.addOwnedMascot('emoji_u1f980_lottie', now: firstWin);
      await repo.addOwnedMascot(
        'emoji_u1f980_lottie',
        now: firstWin.add(const Duration(days: 1)),
      );

      final row = await (db.select(
        db.ownedMascots,
      )..where((t) => t.mascotId.equals('emoji_u1f980_lottie'))).getSingle();
      expect(row.firstAcquiredAt, firstWin.millisecondsSinceEpoch);
      expect(row.count, 2);
    });
  });

  group('watchOwnedMascotIds', () {
    test('emits the seeded default, then the newly-won mascot', () async {
      final emissions = <List<String>>[];
      final subscription = repo.watchOwnedMascotIds().listen(emissions.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions.last, [kDefaultMascotId]);

      await repo.addOwnedMascot('emoji_u1f989_lottie', now: clock.now());
      await pumpEventQueue();
      expect(
        emissions.last,
        containsAll(<String>[kDefaultMascotId, 'emoji_u1f989_lottie']),
      );
    });
  });
}
