// Schema v1 -> v2 (issue #026), v2 -> v3 (issue #010), v3 -> v4 (issue
// #022), and v4 -> v5 (issue #012) migration tests.
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

/// A schemaVersion-5 view of [AppDatabase], used only to seed a pre-#045
/// file at the exact version #045's migration upgrades from: `items` and
/// `profile_stats` are already in their current (post-#012) shape, but
/// `question_sets` still lacks `category`.
class _LegacyV5Database extends AppDatabase {
  _LegacyV5Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await _createQuestionSetsWithoutCategory(m);
      final db = m.database as AppDatabase;
      await m.createTable(db.items);
      await m.createTable(db.attempts);
      await m.createTable(db.profileStats);
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
}

extension on AppDatabase {
  Future<Item?> getItemById(int id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
}
