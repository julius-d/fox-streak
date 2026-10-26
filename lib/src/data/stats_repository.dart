// Profile + attempts repository (issue #002).

import 'package:drift/drift.dart';

import '../mascot/mascot_catalog.dart' show kDefaultMascotId;
import 'clock.dart';
import 'database.dart';

/// Fixed id of the single per-device profile row.
const int kProfileId = 0;

/// Default daily XP goal for fresh profiles.
const int kDefaultDailyGoalXp = 100;

/// Repository for `profile_stats` + `attempts`.
///
/// Ownership rules (see #010/#011):
/// - `xpTotal`/`todayXp` are written exclusively by #010 `XpService` (sole
///   caller of [addXp]).
/// - `streakCount` / `lastActiveDay` are written exclusively by #011
///   `StreakService`.
/// - [recordAttempt] writes an `attempts` row only (+ ensures the profile row
///   exists) and MUST NOT touch `streakCount`/`lastActiveDay` — or `xpTotal`.
/// - This repository owns `dailyGoalXp`, `displayName` and `hasOnboarded`
///   (see #012).
/// - `equippedMascotId`/`lessonsCompletedToday`/`lessonsCompletedDay` are
///   written exclusively by #059 `MascotService`, via
///   [setEquippedMascot]/[setMascotLessonCounter].
/// - `coinsTotal` is written exclusively by #065 `MascotService`'s
///   coin-reward branch, via [addCoins].
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
            todayXp: Value(0),
            displayName: Value(null),
            hasOnboarded: Value(false),
            equippedMascotId: Value(kDefaultMascotId),
            lessonsCompletedToday: Value(0),
            lessonsCompletedDay: Value(null),
            coinsTotal: Value(0),
          ),
        );
    return const ProfileStat(
      id: kProfileId,
      xpTotal: 0,
      streakCount: 0,
      lastActiveDay: null,
      dailyGoalXp: kDefaultDailyGoalXp,
      todayXp: 0,
      displayName: null,
      hasOnboarded: false,
      equippedMascotId: kDefaultMascotId,
      lessonsCompletedToday: 0,
      lessonsCompletedDay: null,
      coinsTotal: 0,
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
            todayXp: 0,
            displayName: null,
            hasOnboarded: false,
            equippedMascotId: kDefaultMascotId,
            lessonsCompletedToday: 0,
            lessonsCompletedDay: null,
            coinsTotal: 0,
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

  /// Adds [delta] XP to the lifetime `xpTotal` and the day-scoped `todayXp`,
  /// returning the lifetime total both before and after the write — #053's
  /// level-up detection needs both, and returning `xpTotalBefore` here (read
  /// as part of this same [getProfile] call) saves callers a second query.
  ///
  /// `todayXp` resets to [delta] when `lastActiveDay` isn't today's day
  /// (fresh day or first-ever lesson), otherwise accumulates. Sole caller:
  /// #010 `XpService.applyLessonResult`.
  Future<({int xpTotalBefore, int xpTotal})> addXp(
    int delta, {
    DateTime? now,
  }) async {
    final profile = await getProfile();
    final today = toLocalDayString(now ?? _clock.now());
    final sameDay = profile.lastActiveDay == today;
    final newXpTotal = profile.xpTotal + delta;
    await (_db.update(
      _db.profileStats,
    )..where((t) => t.id.equals(kProfileId))).write(
      ProfileStatsCompanion(
        xpTotal: Value(newXpTotal),
        todayXp: Value(sameDay ? profile.todayXp + delta : delta),
      ),
    );
    return (xpTotalBefore: profile.xpTotal, xpTotal: newXpTotal);
  }

  /// Overwrites `streak_count`/`last_active_day` with [streakCount] /
  /// [lastActiveDay]. Sole caller: #011 `StreakService.recordActivity`.
  Future<void> setStreak({
    required int streakCount,
    required String lastActiveDay,
  }) async {
    await getProfile();
    await (_db.update(
      _db.profileStats,
    )..where((t) => t.id.equals(kProfileId))).write(
      ProfileStatsCompanion(
        streakCount: Value(streakCount),
        lastActiveDay: Value(lastActiveDay),
      ),
    );
  }

  /// Sets the optional display name shown in Home's greeting (#012).
  ///
  /// Trims [name]; blank/null stores `NULL` so Home falls back to the
  /// generic time-of-day greeting.
  Future<void> setDisplayName(String? name) async {
    await getProfile();
    final trimmed = name?.trim();
    await (_db.update(
      _db.profileStats,
    )..where((t) => t.id.equals(kProfileId))).write(
      ProfileStatsCompanion(
        displayName: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  /// Marks first-run onboarding as shown (completed or skipped), so Home
  /// never shows it again (#012).
  Future<void> setOnboarded() async {
    await getProfile();
    await (_db.update(_db.profileStats)..where((t) => t.id.equals(kProfileId)))
        .write(const ProfileStatsCompanion(hasOnboarded: Value(true)));
  }

  /// Sets the equipped mascot shown on Home/lesson result/onboarding/
  /// `FoxEmptyState` (issue #059). Sole caller: #059 `MascotService.equip`.
  Future<void> setEquippedMascot(String mascotId) async {
    await getProfile();
    await (_db.update(_db.profileStats)..where((t) => t.id.equals(kProfileId)))
        .write(ProfileStatsCompanion(equippedMascotId: Value(mascotId)));
  }

  /// Overwrites the day-scoped lesson-completion counter driving #059's
  /// twice-a-day lootbox trigger. Sole caller:
  /// #059 `MascotService.recordLessonCompletion`.
  Future<void> setMascotLessonCounter({
    required int count,
    required String day,
  }) async {
    await getProfile();
    await (_db.update(
      _db.profileStats,
    )..where((t) => t.id.equals(kProfileId))).write(
      ProfileStatsCompanion(
        lessonsCompletedToday: Value(count),
        lessonsCompletedDay: Value(day),
      ),
    );
  }

  /// Adds [amount] coins to the lifetime `coinsTotal` balance (issue #065).
  /// Sole caller: #065 `MascotService.recordLessonCompletion`'s coin-reward
  /// branch.
  Future<void> addCoins(int amount) async {
    final profile = await getProfile();
    await (_db.update(
      _db.profileStats,
    )..where((t) => t.id.equals(kProfileId))).write(
      ProfileStatsCompanion(coinsTotal: Value(profile.coinsTotal + amount)),
    );
  }

  /// The `setId` of the most recently attempted item, or `null` if no
  /// lesson has ever been completed (#012's Home "Continue" button).
  ///
  /// Derived from `attempts` (latest by [Attempts.at]) joined to `items` —
  /// no dedicated column. Deleting a set/item cascades its attempts away,
  /// so this never points at stale data.
  Future<int?> getLastPracticedSetId() async {
    final query =
        _db.select(_db.attempts).join([
            innerJoin(_db.items, _db.items.id.equalsExp(_db.attempts.itemId)),
          ])
          ..orderBy([OrderingTerm.desc(_db.attempts.at)])
          ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.readTable(_db.items).setId;
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
