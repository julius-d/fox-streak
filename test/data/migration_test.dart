// Schema v1 -> v2 (issue #026), v2 -> v3 (issue #010), v3 -> v4 (issue
// #022), v4 -> v5 (issue #012), v5 -> v6 (issue #045), v6 -> v7 (issue
// #055), v7 -> v8 (issue #059), v8 -> v9 (issue #064), v9 -> v10 (issue
// #065), v10 -> v11 (issue #068), and v11 -> v12 (issue #084) migration
// tests.
//
// Simulates pre-migration databases on disk, then reopens them with the
// real (current schemaVersion) `AppDatabase` and asserts `onUpgrade` applied
// exactly the expected change.
//
// Uses a temp-file-backed `NativeDatabase` (not `.memory()`): drift tracks
// schema version via SQLite's `user_version` pragma, which only persists
// across separate connections when backed by a real file.

import 'dart:io';

import 'package:drift/drift.dart'
    show MigrationStrategy, Migrator, QueryExecutor, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart' show kDefaultPetId;

/// Creates the pre-#022 `items` shape (`direction` TEXT instead of
/// `promptLang`/`answerLang`) — the current Dart `Items` definition no
/// longer has `direction`, so `m.createTable(db.items)` can't be used for
/// pre-v4 fixtures; this hand-written DDL stands in for it.
Future<void> _createItemsTableWithDirection(Migrator m) async {
  final db = m.database as AppDatabase;
  await db.customStatement('''
    CREATE TABLE items (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      set_id INTEGER NOT NULL REFERENCES question_sets (id) ON DELETE CASCADE,
      type TEXT NOT NULL,
      prompt TEXT NOT NULL,
      answer TEXT NOT NULL,
      direction TEXT NULL,
      choices TEXT NULL,
      hint TEXT NULL DEFAULT '',
      position INTEGER NOT NULL
    )
  ''');
}

/// Inserts an `items` row with a `direction` value via raw SQL, since the
/// pre-v4 `direction` column has no corresponding Dart field to insert
/// through `ItemsCompanion` any more.
Future<int> _insertLegacyItem(
  AppDatabase db, {
  required int setId,
  required String type,
  required String prompt,
  required String answer,
  String? direction,
  String? choices,
  required int position,
}) {
  return db.customInsert(
    'INSERT INTO items (set_id, type, prompt, answer, direction, choices, '
    'position) VALUES (?, ?, ?, ?, ?, ?, ?)',
    variables: [
      Variable.withInt(setId),
      Variable.withString(type),
      Variable.withString(prompt),
      Variable.withString(answer),
      direction == null ? const Variable(null) : Variable.withString(direction),
      choices == null ? const Variable(null) : Variable.withString(choices),
      Variable.withInt(position),
    ],
  );
}

/// Creates the pre-#010 (v1/v2) table shapes: `attempts` matches the
/// current Dart def (no structural diff since v1); `questionSets` is the
/// pre-#045 shape (see [_createQuestionSetsWithoutCategory]); `items` is
/// the pre-#022 shape (see [_createItemsTableWithDirection]); `profile_stats`
/// is hand-written *without* `today_xp` — using `createAll()` here would
/// build it from the current (v4) Dart table definition and mask the
/// `addColumn` migration under test.
Future<void> _createLegacySchema(Migrator m) async {
  final db = m.database as AppDatabase;
  await _createQuestionSetsWithoutCategory(m);
  await _createItemsTableWithDirection(m);
  await m.createTable(db.attempts);
  await db.customStatement('''
    CREATE TABLE profile_stats (
      id INTEGER NOT NULL,
      xp_total INTEGER NOT NULL DEFAULT 0,
      streak_count INTEGER NOT NULL DEFAULT 0,
      last_active_day TEXT NULL,
      daily_goal_xp INTEGER NOT NULL DEFAULT 30,
      PRIMARY KEY (id)
    )
  ''');
}

/// A schemaVersion-1 view of [AppDatabase], used only to seed a pre-migration
/// file: creates the pre-#010 table structure and stamps `user_version`
/// at 1 instead of the real schema's current version.
class _LegacyV1Database extends AppDatabase {
  _LegacyV1Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: _createLegacySchema);
}

/// A schemaVersion-2 view of [AppDatabase], used only to seed a pre-#010
/// file at the exact version #010's migration upgrades from.
class _LegacyV2Database extends AppDatabase {
  _LegacyV2Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: _createLegacySchema);
}

/// Pre-#012 `profile_stats` shape: has `today_xp` (added by #010) but not
/// yet `display_name`/`has_onboarded` — using `createAll()` here would
/// build the table from the current (v5) Dart definition and mask the
/// `addColumn` migrations under test.
Future<void> _createProfileStatsWithTodayXpOnly(Migrator m) async {
  final db = m.database as AppDatabase;
  await db.customStatement('''
    CREATE TABLE profile_stats (
      id INTEGER NOT NULL,
      xp_total INTEGER NOT NULL DEFAULT 0,
      streak_count INTEGER NOT NULL DEFAULT 0,
      last_active_day TEXT NULL,
      daily_goal_xp INTEGER NOT NULL DEFAULT 30,
      today_xp INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id)
    )
  ''');
  // `questionSets` is still pre-#045 (no `category`); `attempts` matches
  // the current Dart def, unaffected by #022/#012/#045.
  await _createQuestionSetsWithoutCategory(m);
  await m.createTable(db.attempts);
}

/// A schemaVersion-3 view of [AppDatabase], used only to seed a pre-#022
/// file at the exact version #022's migration upgrades from. `items` still
/// needs the pre-#022 `direction` shape; `profile_stats` already has
/// `today_xp` (added by #010) but not yet #012's `display_name`/
/// `has_onboarded`.
class _LegacyV3Database extends AppDatabase {
  _LegacyV3Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await _createProfileStatsWithTodayXpOnly(m);
      await _createItemsTableWithDirection(m);
    },
  );
}

/// A schemaVersion-4 view of [AppDatabase], used only to seed a pre-#012
/// file at the exact version #012's migration upgrades from: `items` is
/// already in the post-#022 `promptLang`/`answerLang` shape (so
/// `m.createTable(db.items)` can use the current Dart definition
/// directly), but `profile_stats` still lacks `display_name`/
/// `has_onboarded`.
class _LegacyV4Database extends AppDatabase {
  _LegacyV4Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await _createProfileStatsWithTodayXpOnly(m);
      final db = m.database as AppDatabase;
      await m.createTable(db.items);
    },
  );
}

/// Creates the pre-#045 `question_sets` shape (no `category` column) — the
/// current Dart `QuestionSets` definition already has it, so
/// `m.createTable(db.questionSets)` can't be used for this pre-v6 fixture.
Future<void> _createQuestionSetsWithoutCategory(Migrator m) async {
  final db = m.database as AppDatabase;
  await db.customStatement('''
    CREATE TABLE question_sets (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      created_by TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
}

/// Creates the pre-#059 `profile_stats` shape (`display_name`/
/// `has_onboarded` present, but no `equipped_pet_id`/
/// `lessons_completed_today`/`lessons_completed_day`) — the current Dart
/// `ProfileStats` definition already has those, so `m.createTable(db.
/// profileStats)` can't be used for any pre-v8 fixture, even ones (v5, v6,
/// v7) that predate #059 by several migrations and aren't under test here.
Future<void> _createProfileStatsPrePetColumns(Migrator m) async {
  await m.database.customStatement('''
    CREATE TABLE profile_stats (
      id INTEGER NOT NULL,
      xp_total INTEGER NOT NULL DEFAULT 0,
      streak_count INTEGER NOT NULL DEFAULT 0,
      last_active_day TEXT NULL,
      daily_goal_xp INTEGER NOT NULL DEFAULT 30,
      today_xp INTEGER NOT NULL DEFAULT 0,
      display_name TEXT NULL,
      has_onboarded INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id)
    )
  ''');
}

/// A schemaVersion-5 view of [AppDatabase], used only to seed a pre-#045
/// file at the exact version #045's migration upgrades from: `items` is
/// already in its current (post-#012) shape, but `question_sets` still
/// lacks `category` and `profile_stats` still lacks #059's pet columns
/// (see [_createProfileStatsPrePetColumns]).
class _LegacyV5Database extends AppDatabase {
  _LegacyV5Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await _createQuestionSetsWithoutCategory(m);
      await _createProfileStatsPrePetColumns(m);
      final db = m.database as AppDatabase;
      await m.createTable(db.items);
      await m.createTable(db.attempts);
    },
  );
}

/// A schemaVersion-6 view of [AppDatabase], used only to seed a pre-#055
/// file at the exact version #055's migration upgrades from: every table
/// is already in its current shape except `app_settings` (doesn't exist
/// yet) and `profile_stats` (still lacks #059's pet columns, see
/// [_createProfileStatsPrePetColumns]).
class _LegacyV6Database extends AppDatabase {
  _LegacyV6Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await _createProfileStatsPrePetColumns(m);
      final db = m.database as AppDatabase;
      await m.createTable(db.questionSets);
      await m.createTable(db.items);
      await m.createTable(db.attempts);
    },
  );
}

/// A schemaVersion-7 view of [AppDatabase], used only to seed a pre-#059
/// file at the exact version #059's migration upgrades from: every table
/// is already in its current shape except `profile_stats` (still lacks
/// #059's pet columns, see [_createProfileStatsPrePetColumns]) and
/// `owned_pets`, which doesn't exist yet.
class _LegacyV7Database extends AppDatabase {
  _LegacyV7Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await _createProfileStatsPrePetColumns(m);
      final db = m.database as AppDatabase;
      await m.createTable(db.questionSets);
      await m.createTable(db.items);
      await m.createTable(db.attempts);
      await m.createTable(db.appSettings);
    },
  );
}

/// Creates the pre-#064 `owned_mascots` shape (`acquired_at`, no `count`)
/// under its pre-#068 physical name — the current Dart `OwnedPets`
/// definition already has `first_acquired_at` + `count` under the
/// post-#068 `owned_pets`/`pet_id` names, so `m.createTable(db.ownedPets)`
/// can't be used for this pre-v9 (and pre-v11 rename) fixture.
Future<void> _createOwnedMascotsPreCount(Migrator m) async {
  await m.database.customStatement('''
    CREATE TABLE owned_mascots (
      mascot_id TEXT NOT NULL,
      acquired_at INTEGER NOT NULL,
      PRIMARY KEY (mascot_id)
    )
  ''');
}

/// Creates the pre-#065 `profile_stats` shape (has #059's mascot columns,
/// under their pre-#068 physical names, but not yet `coins_total`) — the
/// current Dart `ProfileStats` definition already has `coinsTotal` and the
/// post-#068 `equippedPetId`, so `m.createTable(db.profileStats)` can't be
/// used for any pre-v10 (and pre-v11 rename) fixture.
Future<void> _createProfileStatsPreCoinsTotal(Migrator m) async {
  await m.database.customStatement('''
    CREATE TABLE profile_stats (
      id INTEGER NOT NULL,
      xp_total INTEGER NOT NULL DEFAULT 0,
      streak_count INTEGER NOT NULL DEFAULT 0,
      last_active_day TEXT NULL,
      daily_goal_xp INTEGER NOT NULL DEFAULT 30,
      today_xp INTEGER NOT NULL DEFAULT 0,
      display_name TEXT NULL,
      has_onboarded INTEGER NOT NULL DEFAULT 0,
      equipped_mascot_id TEXT NOT NULL DEFAULT 'emoji_u1f98a_lottie',
      lessons_completed_today INTEGER NOT NULL DEFAULT 0,
      lessons_completed_day TEXT NULL,
      PRIMARY KEY (id)
    )
  ''');
}

/// A schemaVersion-8 view of [AppDatabase], used only to seed a pre-#064
/// file at the exact version #064's migration upgrades from: every table
/// is already in its current shape except `owned_mascots` (still has
/// `acquired_at`, no `count`, see [_createOwnedMascotsPreCount]) and
/// `profile_stats` (still lacks #065's `coins_total`, see
/// [_createProfileStatsPreCoinsTotal]).
class _LegacyV8Database extends AppDatabase {
  _LegacyV8Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      final db = m.database as AppDatabase;
      await m.createTable(db.questionSets);
      await m.createTable(db.items);
      await m.createTable(db.attempts);
      await _createProfileStatsPreCoinsTotal(m);
      await m.createTable(db.appSettings);
      await _createOwnedMascotsPreCount(m);
    },
  );
}

/// A schemaVersion-9 view of [AppDatabase], used only to seed a pre-#065
/// file at the exact version #065's migration upgrades from: `owned_mascots`
/// is already in its post-#064 (`mascot_id`/`first_acquired_at`/`count`)
/// shape, under its pre-#068 physical name, but `profile_stats` still
/// lacks `coins_total` (see [_createProfileStatsPreCoinsTotal]).
class _LegacyV9Database extends AppDatabase {
  _LegacyV9Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      final db = m.database as AppDatabase;
      await m.createTable(db.questionSets);
      await m.createTable(db.items);
      await m.createTable(db.attempts);
      await _createProfileStatsPreCoinsTotal(m);
      await m.createTable(db.appSettings);
      await m.database.customStatement('''
        CREATE TABLE owned_mascots (
          mascot_id TEXT NOT NULL,
          first_acquired_at INTEGER NOT NULL,
          count INTEGER NOT NULL DEFAULT 1,
          PRIMARY KEY (mascot_id)
        )
      ''');
    },
  );
}

/// A schemaVersion-10 view of [AppDatabase], used only to seed a pre-#068
/// file at the exact version #068's rename migrates from: every table is
/// in its current (post-#065) shape, but still under the pre-#068
/// `owned_mascots`/`mascot_id`/`equipped_mascot_id` physical names.
class _LegacyV10Database extends AppDatabase {
  _LegacyV10Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      final db = m.database as AppDatabase;
      await m.createTable(db.questionSets);
      await m.createTable(db.items);
      await m.createTable(db.attempts);
      await m.database.customStatement('''
        CREATE TABLE profile_stats (
          id INTEGER NOT NULL,
          xp_total INTEGER NOT NULL DEFAULT 0,
          streak_count INTEGER NOT NULL DEFAULT 0,
          last_active_day TEXT NULL,
          daily_goal_xp INTEGER NOT NULL DEFAULT 30,
          today_xp INTEGER NOT NULL DEFAULT 0,
          display_name TEXT NULL,
          has_onboarded INTEGER NOT NULL DEFAULT 0,
          equipped_mascot_id TEXT NOT NULL DEFAULT 'emoji_u1f98a_lottie',
          lessons_completed_today INTEGER NOT NULL DEFAULT 0,
          lessons_completed_day TEXT NULL,
          coins_total INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (id)
        )
      ''');
      await m.createTable(db.appSettings);
      await m.database.customStatement('''
        CREATE TABLE owned_mascots (
          mascot_id TEXT NOT NULL,
          first_acquired_at INTEGER NOT NULL,
          count INTEGER NOT NULL DEFAULT 1,
          PRIMARY KEY (mascot_id)
        )
      ''');
    },
  );
}

/// A schemaVersion-11 view of [AppDatabase], used only to seed a pre-#084
/// file at the exact version #084's migration upgrades from: every table is
/// already in its current (post-#068) shape — including the `owned_pets`/
/// `pet_id`/`equipped_pet_id` rename — except `daily_activity`, which
/// doesn't exist yet.
class _LegacyV11Database extends AppDatabase {
  _LegacyV11Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      final db = m.database as AppDatabase;
      await m.createTable(db.questionSets);
      await m.createTable(db.items);
      await m.createTable(db.attempts);
      await m.createTable(db.profileStats);
      await m.createTable(db.appSettings);
      await m.createTable(db.ownedPets);
    },
  );
}

void main() {
  test('onUpgrade rewrites vocab -> choice exactly once', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v1 database directly on disk with a 'vocab' row.
    final legacyDb = _LegacyV1Database(NativeDatabase(file));
    final setId = await legacyDb
        .into(legacyDb.questionSets)
        .insert(
          QuestionSetsCompanion.insert(
            title: 'Legacy set',
            createdBy: 'teacher',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final vocabId = await _insertLegacyItem(
      legacyDb,
      setId: setId,
      type: 'vocab',
      prompt: 'Hund',
      answer: 'dog',
      direction: 'deEn',
      choices: '["cat","mouse"]',
      position: 0,
    );
    final phoneId = await _insertLegacyItem(
      legacyDb,
      setId: setId,
      type: 'phone',
      prompt: 'Mama',
      answer: '01711234567',
      position: 1,
    );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=1 < schemaVersion and runs every
    // onUpgrade step in order, including #022's direction rewrite.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final vocabRow = await upgradedDb.getItemById(vocabId);
    expect(vocabRow?.type, 'choice');
    expect(vocabRow?.promptLang, 'de');
    expect(vocabRow?.answerLang, 'en');
    expect(vocabRow?.choices, '["cat","mouse"]');

    final phoneRow = await upgradedDb.getItemById(phoneId);
    expect(phoneRow?.type, 'phone');
  });

  test('onUpgrade (v2 -> v3) adds today_xp defaulting to 0, preserving '
      'existing xp_total/streak_count', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v3');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v2 database directly on disk (profile_stats has no
    // today_xp column yet) with a pre-existing profile row.
    final legacyDb = _LegacyV2Database(NativeDatabase(file));
    await legacyDb
        .into(legacyDb.profileStats)
        .insert(
          const ProfileStatsCompanion(
            id: Value(0),
            xpTotal: Value(42),
            streakCount: Value(3),
            lastActiveDay: Value('2026-10-10'),
            dailyGoalXp: Value(30),
          ),
        );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=2 < schemaVersion=3 and runs
    // onUpgrade's `addColumn`.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final profile = await (upgradedDb.select(
      upgradedDb.profileStats,
    )..where((t) => t.id.equals(0))).getSingle();
    expect(profile.todayXp, 0);
    expect(profile.xpTotal, 42);
    expect(profile.streakCount, 3);
    expect(profile.lastActiveDay, '2026-10-10');
  });

  test('onUpgrade (v3 -> v4) rewrites direction into promptLang/answerLang and '
      'drops the direction column', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v4');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v3 database directly on disk with deEn/enDe/no-direction
    // items.
    final legacyDb = _LegacyV3Database(NativeDatabase(file));
    final setId = await legacyDb
        .into(legacyDb.questionSets)
        .insert(
          QuestionSetsCompanion.insert(
            title: 'Legacy set',
            createdBy: 'teacher',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final deEnId = await _insertLegacyItem(
      legacyDb,
      setId: setId,
      type: 'choice',
      prompt: 'Hund',
      answer: 'dog',
      direction: 'deEn',
      choices: '["cat","mouse"]',
      position: 0,
    );
    final enDeId = await _insertLegacyItem(
      legacyDb,
      setId: setId,
      type: 'choice',
      prompt: 'bird',
      answer: 'Vogel',
      direction: 'enDe',
      position: 1,
    );
    final noPairId = await _insertLegacyItem(
      legacyDb,
      setId: setId,
      type: 'phone',
      prompt: 'Mama',
      answer: '01711234567',
      position: 2,
    );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=3 < schemaVersion and runs every
    // onUpgrade step in order, including #022's rewrite + dropColumn.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final deEnRow = await upgradedDb.getItemById(deEnId);
    expect(deEnRow?.promptLang, 'de');
    expect(deEnRow?.answerLang, 'en');
    expect(deEnRow?.choices, '["cat","mouse"]');

    final enDeRow = await upgradedDb.getItemById(enDeId);
    expect(enDeRow?.promptLang, 'en');
    expect(enDeRow?.answerLang, 'de');

    final noPairRow = await upgradedDb.getItemById(noPairId);
    expect(noPairRow?.promptLang, isNull);
    expect(noPairRow?.answerLang, isNull);

    // The old `direction` column is actually dropped, not just unused.
    final columns = await upgradedDb
        .customSelect("PRAGMA table_info('items')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      isNot(contains('direction')),
    );
  });

  test('onUpgrade (v4 -> v5) adds displayName (null) and hasOnboarded '
      '(false), preserving existing xpTotal/streakCount/todayXp', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v5');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v4 database directly on disk (profile_stats has no
    // display_name/has_onboarded columns yet) with a pre-existing row.
    final legacyDb = _LegacyV4Database(NativeDatabase(file));
    await legacyDb
        .into(legacyDb.profileStats)
        .insert(
          const ProfileStatsCompanion(
            id: Value(0),
            xpTotal: Value(42),
            streakCount: Value(3),
            lastActiveDay: Value('2026-10-10'),
            dailyGoalXp: Value(30),
            todayXp: Value(12),
          ),
        );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=4 < schemaVersion and runs
    // onUpgrade's two `addColumn`s.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final profile = await (upgradedDb.select(
      upgradedDb.profileStats,
    )..where((t) => t.id.equals(0))).getSingle();
    expect(profile.displayName, isNull);
    expect(profile.hasOnboarded, isFalse);
    expect(profile.xpTotal, 42);
    expect(profile.streakCount, 3);
    expect(profile.todayXp, 12);
    expect(profile.lastActiveDay, '2026-10-10');
  });

  test('onUpgrade (v5 -> v6) adds category (null), preserving existing set '
      'fields', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v6');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v5 database directly on disk (question_sets has no
    // category column yet) with a pre-existing set row.
    final legacyDb = _LegacyV5Database(NativeDatabase(file));
    final setId = await legacyDb
        .into(legacyDb.questionSets)
        .insert(
          QuestionSetsCompanion.insert(
            title: 'Legacy set',
            createdBy: 'teacher',
            createdAt: 1,
            updatedAt: 2,
          ),
        );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=5 < schemaVersion and runs
    // onUpgrade's `addColumn`.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final set = await (upgradedDb.select(
      upgradedDb.questionSets,
    )..where((t) => t.id.equals(setId))).getSingle();
    expect(set.category, isNull);
    expect(set.title, 'Legacy set');
    expect(set.createdBy, 'teacher');
    expect(set.createdAt, 1);
    expect(set.updatedAt, 2);

    final columns = await upgradedDb
        .customSelect("PRAGMA table_info('question_sets')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('category'),
    );
  });

  test('onUpgrade (v6 -> v7) creates the app_settings table (empty, no default '
      'row — SettingsRepository.getSettings() inserts that lazily)', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v7');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v6 database directly on disk (no app_settings table yet).
    final legacyDb = _LegacyV6Database(NativeDatabase(file));
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=6 < schemaVersion=7 and runs
    // onUpgrade's `createTable`.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final columns = await upgradedDb
        .customSelect("PRAGMA table_info('app_settings')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(<String>['id', 'haptics_enabled', 'sound_enabled']),
    );
    expect(await (upgradedDb.select(upgradedDb.appSettings)).get(), isEmpty);
  });

  test('onUpgrade (v7 -> v8) creates owned_pets + adds profileStats '
      'pet columns, defaulting equippedPetId to the fox and '
      'preserving existing xpTotal/streakCount/todayXp', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v8');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v7 database directly on disk (profile_stats has no pet
    // columns yet, owned_pets doesn't exist) with a pre-existing row.
    final legacyDb = _LegacyV7Database(NativeDatabase(file));
    await legacyDb
        .into(legacyDb.profileStats)
        .insert(
          const ProfileStatsCompanion(
            id: Value(0),
            xpTotal: Value(42),
            streakCount: Value(3),
            lastActiveDay: Value('2026-10-10'),
            dailyGoalXp: Value(30),
            todayXp: Value(12),
            displayName: Value(null),
            hasOnboarded: Value(false),
          ),
        );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=7 < schemaVersion=8 and runs
    // onUpgrade's `createTable`/`addColumn`s.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final profile = await (upgradedDb.select(
      upgradedDb.profileStats,
    )..where((t) => t.id.equals(0))).getSingle();
    expect(profile.equippedPetId, kDefaultPetId);
    expect(profile.lessonsCompletedToday, 0);
    expect(profile.lessonsCompletedDay, isNull);
    expect(profile.xpTotal, 42);
    expect(profile.streakCount, 3);
    expect(profile.todayXp, 12);
    expect(profile.lastActiveDay, '2026-10-10');

    // Reopening at the current (v9) schemaVersion also runs #064's v8->v9
    // step, so `owned_pets` already has `first_acquired_at`/`count`
    // rather than the v8-only `acquired_at` — see the v8->v9 test below for
    // that migration step's own coverage.
    final columns = await upgradedDb
        .customSelect("PRAGMA table_info('owned_pets')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(<String>['pet_id', 'first_acquired_at', 'count']),
    );
    expect(await (upgradedDb.select(upgradedDb.ownedPets)).get(), isEmpty);
  });

  test('onUpgrade (v8 -> v9) renames acquiredAt to firstAcquiredAt and adds '
      'count, defaulting existing rows to 1', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v9');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v8 database directly on disk (owned_mascots has
    // acquired_at but no count yet, under its pre-#068 physical name)
    // with a pre-existing owned-pet row.
    final legacyDb = _LegacyV8Database(NativeDatabase(file));
    await legacyDb.customInsert(
      'INSERT INTO owned_mascots (mascot_id, acquired_at) VALUES (?, ?)',
      variables: [Variable.withString(kDefaultPetId), Variable.withInt(1000)],
    );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=8 < schemaVersion=9 and runs
    // onUpgrade's `renameColumn`/`addColumn`.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final row = await (upgradedDb.select(
      upgradedDb.ownedPets,
    )..where((t) => t.petId.equals(kDefaultPetId))).getSingle();
    expect(row.firstAcquiredAt, 1000);
    expect(row.count, 1);

    final columns = await upgradedDb
        .customSelect("PRAGMA table_info('owned_pets')")
        .get();
    final columnNames = columns.map((row) => row.read<String>('name'));
    expect(
      columnNames,
      containsAll(<String>['pet_id', 'first_acquired_at', 'count']),
    );
    expect(columnNames, isNot(contains('acquired_at')));
  });

  test('onUpgrade (v9 -> v10) adds coinsTotal defaulting to 0, preserving '
      'existing xpTotal/streakCount/todayXp', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v10');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v9 database directly on disk (profile_stats has no
    // coins_total column yet) with a pre-existing profile row.
    final legacyDb = _LegacyV9Database(NativeDatabase(file));
    await legacyDb
        .into(legacyDb.profileStats)
        .insert(
          ProfileStatsCompanion.insert(
            id: const Value(0),
            xpTotal: const Value(42),
            streakCount: const Value(3),
            lastActiveDay: const Value('2026-10-10'),
            todayXp: const Value(12),
          ),
        );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=9 < schemaVersion=10 and runs
    // onUpgrade's `addColumn`.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final profile = await (upgradedDb.select(
      upgradedDb.profileStats,
    )..where((t) => t.id.equals(0))).getSingle();
    expect(profile.coinsTotal, 0);
    expect(profile.xpTotal, 42);
    expect(profile.streakCount, 3);
    expect(profile.todayXp, 12);
    expect(profile.lastActiveDay, '2026-10-10');
  });

  test('onUpgrade (v10 -> v11) renames owned_mascots/mascot_id/ '
      'equipped_mascot_id to owned_pets/pet_id/equipped_pet_id, preserving '
      'existing owned rows and the equipped value unchanged', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v11');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v10 database directly on disk (still under the pre-#068
    // owned_mascots/mascot_id/equipped_mascot_id physical names) with a
    // pre-existing owned-pet row and a non-default equipped choice.
    final legacyDb = _LegacyV10Database(NativeDatabase(file));
    await legacyDb.customInsert(
      'INSERT INTO owned_mascots (mascot_id, first_acquired_at, count) '
      'VALUES (?, ?, ?)',
      variables: [
        Variable.withString('emoji_u1f407_lottie'),
        Variable.withInt(2000),
        Variable.withInt(3),
      ],
    );
    await legacyDb.customInsert(
      'INSERT INTO profile_stats (id, equipped_mascot_id) VALUES (?, ?)',
      variables: [
        Variable.withInt(0),
        Variable.withString('emoji_u1f407_lottie'),
      ],
    );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=10 < schemaVersion=11 and runs
    // onUpgrade's `RENAME TABLE`/`RENAME COLUMN` steps.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    // The owned-pet row survives the rename with its data untouched.
    final ownedRow = await (upgradedDb.select(
      upgradedDb.ownedPets,
    )..where((t) => t.petId.equals('emoji_u1f407_lottie'))).getSingle();
    expect(ownedRow.firstAcquiredAt, 2000);
    expect(ownedRow.count, 3);

    // The equipped choice survives the rename unchanged.
    final profile = await (upgradedDb.select(
      upgradedDb.profileStats,
    )..where((t) => t.id.equals(0))).getSingle();
    expect(profile.equippedPetId, 'emoji_u1f407_lottie');

    // Only the table/column names differ — no leftover old names.
    final ownedPetsColumns = await upgradedDb
        .customSelect("PRAGMA table_info('owned_pets')")
        .get();
    expect(
      ownedPetsColumns.map((row) => row.read<String>('name')),
      containsAll(<String>['pet_id', 'first_acquired_at', 'count']),
    );
    final profileColumns = await upgradedDb
        .customSelect("PRAGMA table_info('profile_stats')")
        .get();
    final profileColumnNames = profileColumns.map(
      (row) => row.read<String>('name'),
    );
    expect(profileColumnNames, contains('equipped_pet_id'));
    expect(profileColumnNames, isNot(contains('equipped_mascot_id')));
    final tableNames = await upgradedDb
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(
      tableNames.map((row) => row.read<String>('name')),
      isNot(contains('owned_mascots')),
    );
  });

  test('onUpgrade (v11 -> v12) creates the daily_activity table (empty, no '
      'backfill), preserving existing tables untouched', () async {
    final dir = Directory.systemTemp.createTempSync('foxstreak_migration_v12');
    final file = File('${dir.path}/test.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // 1. Seed a v11 database directly on disk (no daily_activity table yet)
    // with a pre-existing profile row.
    final legacyDb = _LegacyV11Database(NativeDatabase(file));
    await legacyDb
        .into(legacyDb.profileStats)
        .insert(
          const ProfileStatsCompanion(
            id: Value(0),
            xpTotal: Value(42),
            streakCount: Value(3),
            lastActiveDay: Value('2026-10-10'),
          ),
        );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (current schemaVersion)
    // database; drift sees user_version=11 < schemaVersion=12 and runs
    // onUpgrade's `createTable`.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final columns = await upgradedDb
        .customSelect("PRAGMA table_info('daily_activity')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(<String>['day', 'xp_earned', 'activity_source']),
    );
    expect(await (upgradedDb.select(upgradedDb.dailyActivity)).get(), isEmpty);

    final profile = await (upgradedDb.select(
      upgradedDb.profileStats,
    )..where((t) => t.id.equals(0))).getSingle();
    expect(profile.xpTotal, 42);
    expect(profile.streakCount, 3);
    expect(profile.lastActiveDay, '2026-10-10');
  });
}

extension on AppDatabase {
  Future<Item?> getItemById(int id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
}
