// Owned-pets repository (issue #059), separate from [ProfileStats]
// (progress/XP/streak/equipped-pet, see `StatsRepository`) — mirrors
// `SettingsRepository`'s one-table-per-repository shape.

import 'package:drift/drift.dart';

import '../pet/pet_catalog.dart' show kDefaultPetId;
import 'clock.dart';
import 'database.dart';

/// Repository for the `owned_pets` table.
///
/// Sole writer of `owned_pets`: #059 `PetService`, via
/// [addOwnedPet].
class PetRepository {
  final AppDatabase _db;
  final Clock _clock;

  PetRepository(AppDatabase db, [Clock? clock])
    : _db = db,
      _clock = clock ?? SystemClock();

  /// The catalog IDs of every pet this profile has unlocked, seeding the
  /// default fox as owned on first use (fresh profiles start owning it).
  Future<List<String>> getOwnedPetIds() async {
    await _ensureDefaultOwned();
    final rows = await _db.select(_db.ownedPets).get();
    return rows.map((row) => row.petId).toList();
  }

  /// Live view of [getOwnedPetIds], for the collection screen.
  ///
  /// Seeds the default fox *before* subscribing (not inside a per-emission
  /// `asyncMap`) so the very first emission already includes it, rather
  /// than briefly emitting the pre-seed row set.
  Stream<List<String>> watchOwnedPetIds() async* {
    await _ensureDefaultOwned();
    yield* _db
        .select(_db.ownedPets)
        .watch()
        .map((rows) => rows.map((row) => row.petId).toList());
  }

  /// Live view of every owned pet's catalog ID mapped to its
  /// [OwnedPets.count] (issue #069's collection-screen "×N" badge) — a
  /// superset of [watchOwnedPetIds]'s ids, since every owned id is a key
  /// here too. Seeding behaves the same as [watchOwnedPetIds].
  Stream<Map<String, int>> watchOwnedPetCounts() async* {
    await _ensureDefaultOwned();
    yield* _db
        .select(_db.ownedPets)
        .watch()
        .map((rows) => {for (final row in rows) row.petId: row.count});
  }

  /// Records a win of [petId]: inserts a new row (`firstAcquiredAt` =
  /// now, `count` = 1) the first time it's drawn, or bumps `count` by one on
  /// every later draw — `firstAcquiredAt` stays pinned to the first win
  /// (issue #064). Sole caller: #059 `PetService.recordLessonCompletion`.
  Future<void> addOwnedPet(String petId, {DateTime? now}) async {
    await _db
        .into(_db.ownedPets)
        .insert(
          OwnedPetsCompanion.insert(
            petId: petId,
            firstAcquiredAt: (now ?? _clock.now()).millisecondsSinceEpoch,
          ),
          onConflict: DoUpdate(
            (old) =>
                OwnedPetsCompanion.custom(count: old.count + const Constant(1)),
          ),
        );
  }

  /// Seeds the default fox as owned on first use (idempotent) — fresh
  /// profiles start owning exactly this pet (issue #059's decisions).
  Future<void> _ensureDefaultOwned() async {
    final existing = await (_db.select(
      _db.ownedPets,
    )..where((t) => t.petId.equals(kDefaultPetId))).getSingleOrNull();
    if (existing != null) return;
    await addOwnedPet(kDefaultPetId, now: _clock.now());
  }
}
