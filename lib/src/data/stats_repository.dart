// Profile + attempts repository (issue #002).

import 'package:drift/drift.dart';

import 'clock.dart';
import 'database.dart';

/// Fixed id of the single per-device profile row.
const int kProfileId = 0;

/// Default daily XP goal for fresh profiles.
const int kDefaultDailyGoalXp = 30;

/// Repository for `profile_stats` + `attempts`.
///
/// Ownership rules (see #010/#011):
/// - `xpTotal` is written exclusively by #010 `XpService` (sole writer).
/// - `streakCount` / `lastActiveDay` are written exclusively by #011
///   `StreakService`.
/// - [recordAttempt] writes an `attempts` row only (+ ensures the profile row
///   exists) and MUST NOT touch `streakCount`/`lastActiveDay` — or `xpTotal`.
/// - This repository owns `dailyGoalXp` (editable, see #012).
class StatsRepository {
  final AppDatabase _db;
  final Clock _clock;

  StatsRepository(AppDatabase db, [Clock? clock])
    : _db = db,
      _clock = clock ?? SystemClock();

  /// Returns the profile, creating the default row on first use.
  Future<ProfileStat> getProfile() async {
    final existing = await (_db.select(
      _db.profileStats,
    )..where((t) => t.id.equals(kProfileId))).getSingleOrNull();
    if (existing != null) return existing;
    await _db
        .into(_db.profileStats)
        .insert(
          const ProfileStatsCompanion(
            id: Value(kProfileId),
            xpTotal: Value(0),
            streakCount: Value(0),
            lastActiveDay: Value(null),
            dailyGoalXp: Value(kDefaultDailyGoalXp),
          ),
        );
    return const ProfileStat(
      id: kProfileId,
      xpTotal: 0,
      streakCount: 0,
      lastActiveDay: null,
      dailyGoalXp: kDefaultDailyGoalXp,
    );
  }

  Stream<ProfileStat> watchProfile() {
    return (_db.select(
      _db.profileStats,
    )..where((t) => t.id.equals(kProfileId))).watchSingleOrNull().map(
      (row) =>
          row ??
          const ProfileStat(
            id: kProfileId,
            xpTotal: 0,
            streakCount: 0,
            lastActiveDay: null,
            dailyGoalXp: kDefaultDailyGoalXp,
          ),
    );
  }

  /// Updates the daily XP goal (must be >= 0).
  Future<void> updateDailyGoal(int xp) async {
    if (xp < 0) throw ArgumentError('daily goal must be >= 0');
    await getProfile();
    await (_db.update(_db.profileStats)..where((t) => t.id.equals(kProfileId)))
        .write(ProfileStatsCompanion(dailyGoalXp: Value(xp)));
  }

  /// Records a graded answer.
  ///
  /// Writes exactly one `attempts` row and ensures the profile row exists.
  /// Never modifies `xpTotal`, `streakCount` or `lastActiveDay`.
  Future<int> recordAttempt({
    required int itemId,
    required bool ok,
    DateTime? now,
  }) async {
    await getProfile();
    final atMs = (now ?? _clock.now()).millisecondsSinceEpoch;
    return _db
        .into(_db.attempts)
        .insert(AttemptsCompanion.insert(itemId: itemId, ok: ok, at: atMs));
  }

  Future<List<Attempt>> getAttemptsForItem(int itemId, {int? limit}) async {
    final query = _db.select(_db.attempts)
      ..where((t) => t.itemId.equals(itemId))
      ..orderBy([(t) => OrderingTerm.desc(t.at)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<int> countAttempts({bool? ok}) async {
    final query = _db.selectOnly(_db.attempts)
      ..addColumns([_db.attempts.id.count()]);
    if (ok != null) query.where(_db.attempts.ok.equals(ok));
    final row = await query.getSingle();
    return row.read(_db.attempts.id.count()) ?? 0;
  }
}
