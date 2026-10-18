// Owned-mascots repository (issue #059), separate from [ProfileStats]
// (progress/XP/streak/equipped-mascot, see `StatsRepository`) — mirrors
// `SettingsRepository`'s one-table-per-repository shape.

import 'package:drift/drift.dart';

import '../mascot/mascot_catalog.dart' show kDefaultMascotId;
import 'clock.dart';
import 'database.dart';

/// Repository for the `owned_mascots` table.
///
/// Sole writer of `owned_mascots`: #059 `MascotService`, via
/// [addOwnedMascot].
class MascotRepository {
  final AppDatabase _db;
  final Clock _clock;

  MascotRepository(AppDatabase db, [Clock? clock])
    : _db = db,
      _clock = clock ?? SystemClock();

  /// The catalog IDs of every mascot this profile has unlocked, seeding the
  /// default fox as owned on first use (fresh profiles start owning it).
  Future<List<String>> getOwnedMascotIds() async {
    await _ensureDefaultOwned();
    final rows = await _db.select(_db.ownedMascots).get();
    return rows.map((row) => row.mascotId).toList();
  }

  /// Live view of [getOwnedMascotIds], for the collection screen.
  ///
  /// Seeds the default fox *before* subscribing (not inside a per-emission
  /// `asyncMap`) so the very first emission already includes it, rather
  /// than briefly emitting the pre-seed row set.
  Stream<List<String>> watchOwnedMascotIds() async* {
    await _ensureDefaultOwned();
    yield* _db
        .select(_db.ownedMascots)
        .watch()
        .map((rows) => rows.map((row) => row.mascotId).toList());
  }

  /// Records a win of [mascotId]: inserts a new row (`firstAcquiredAt` =
  /// now, `count` = 1) the first time it's drawn, or bumps `count` by one on
  /// every later draw — `firstAcquiredAt` stays pinned to the first win
  /// (issue #064). Sole caller: #059 `MascotService.recordLessonCompletion`.
  Future<void> addOwnedMascot(String mascotId, {DateTime? now}) async {
    await _db
        .into(_db.ownedMascots)
        .insert(
          OwnedMascotsCompanion.insert(
            mascotId: mascotId,
            firstAcquiredAt: (now ?? _clock.now()).millisecondsSinceEpoch,
          ),
          onConflict: DoUpdate(
            (old) => OwnedMascotsCompanion.custom(
              count: old.count + const Constant(1),
            ),
          ),
        );
  }

  /// Seeds the default fox as owned on first use (idempotent) — fresh
  /// profiles start owning exactly this mascot (issue #059's decisions).
  Future<void> _ensureDefaultOwned() async {
    final existing = await (_db.select(
      _db.ownedMascots,
    )..where((t) => t.mascotId.equals(kDefaultMascotId))).getSingleOrNull();
    if (existing != null) return;
    await addOwnedMascot(kDefaultMascotId, now: _clock.now());
  }
}
