// Schema v1 -> v2 (issue #026) and v2 -> v3 (issue #010) migration tests.
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
    show MigrationStrategy, Migrator, QueryExecutor, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';

/// Creates the pre-#010 (v1/v2) table shapes: `questionSets`/`items`/
/// `attempts` match the current Dart defs (no structural diff since v1),
/// but `profile_stats` is hand-written *without* `today_xp` — using
/// `createAll()` here would build it from the current (v3) Dart table
/// definition and mask the `addColumn` migration under test.
Future<void> _createLegacySchema(Migrator m) async {
  final db = m.database as AppDatabase;
  await m.createTable(db.questionSets);
  await m.createTable(db.items);
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
    final vocabId = await legacyDb
        .into(legacyDb.items)
        .insert(
          ItemsCompanion.insert(
            setId: setId,
            type: 'vocab',
            prompt: 'Hund',
            answer: 'dog',
            direction: const Value('deEn'),
            choices: const Value('["cat","mouse"]'),
            position: 0,
          ),
        );
    final phoneId = await legacyDb
        .into(legacyDb.items)
        .insert(
          ItemsCompanion.insert(
            setId: setId,
            type: 'phone',
            prompt: 'Mama',
            answer: '01711234567',
            position: 1,
          ),
        );
    await legacyDb.close();

    // 2. Reopen the SAME file with the real (schemaVersion 2) database;
    // drift sees user_version=1 < schemaVersion=2 and runs onUpgrade.
    final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgradedDb.close);

    final vocabRow = await upgradedDb.getItemById(vocabId);
    expect(vocabRow?.type, 'choice');
    expect(vocabRow?.direction, 'deEn');
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
}

extension on AppDatabase {
  Future<Item?> getItemById(int id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
}
