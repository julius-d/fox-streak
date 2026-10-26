// Unit tests for PetRepository's `owned_pets` table wiring
// (issue #059, duplicate-draw counting added in #064).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/pet_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late PetRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(kTestToday);
    repo = PetRepository(db, clock);
  });

  tearDown(() async {
    await db.close();
  });

  group('getOwnedPetIds', () {
    test('seeds the default fox as owned on first use', () async {
      final owned = await repo.getOwnedPetIds();
      expect(owned, [kDefaultPetId]);
    });

    test('seeding is idempotent across repeated calls', () async {
      await repo.getOwnedPetIds();
      final owned = await repo.getOwnedPetIds();
      expect(owned, [kDefaultPetId]);
    });
  });

  group('addOwnedPet', () {
    test('persists a new pet as owned', () async {
      await repo.addOwnedPet('emoji_u1f980_lottie', now: clock.now());
      final owned = await repo.getOwnedPetIds();
      expect(
        owned,
        containsAll(<String>[kDefaultPetId, 'emoji_u1f980_lottie']),
      );
      expect(owned, hasLength(2));
    });

    test('recording the same pet twice does not duplicate the row, but '
        'increments its count (issue #064)', () async {
      await repo.addOwnedPet('emoji_u1f980_lottie', now: clock.now());
      await repo.addOwnedPet('emoji_u1f980_lottie', now: clock.now());
      final owned = await repo.getOwnedPetIds();
      expect(owned.where((id) => id == 'emoji_u1f980_lottie'), hasLength(1));

      final row = await (db.select(
        db.ownedPets,
      )..where((t) => t.petId.equals('emoji_u1f980_lottie'))).getSingle();
      expect(row.count, 2);
    });

    test('firstAcquiredAt stays pinned to the first win across repeat draws '
        '(issue #064)', () async {
      final firstWin = clock.now();
      await repo.addOwnedPet('emoji_u1f980_lottie', now: firstWin);
      await repo.addOwnedPet(
        'emoji_u1f980_lottie',
        now: firstWin.add(const Duration(days: 1)),
      );

      final row = await (db.select(
        db.ownedPets,
      )..where((t) => t.petId.equals('emoji_u1f980_lottie'))).getSingle();
      expect(row.firstAcquiredAt, firstWin.millisecondsSinceEpoch);
      expect(row.count, 2);
    });
  });

  group('watchOwnedPetIds', () {
    test('emits the seeded default, then the newly-won pet', () async {
      final emissions = <List<String>>[];
      final subscription = repo.watchOwnedPetIds().listen(emissions.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions.last, [kDefaultPetId]);

      await repo.addOwnedPet('emoji_u1f989_lottie', now: clock.now());
      await pumpEventQueue();
      expect(
        emissions.last,
        containsAll(<String>[kDefaultPetId, 'emoji_u1f989_lottie']),
      );
    });
  });
}
