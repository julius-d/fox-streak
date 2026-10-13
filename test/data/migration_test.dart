// Schema v1 -> v2 migration test (issue #026).
//
// Simulates a pre-migration (schemaVersion 1) database on disk with a
// 'vocab' item (plus a 'phone' control row), then reopens it with the real
// (schemaVersion 2) `AppDatabase` and asserts the `onUpgrade` step rewrote
// 'vocab' -> 'choice' exactly once, leaving direction/choices and the
// unrelated 'phone' row untouched.
//
// Uses a temp-file-backed `NativeDatabase` (not `.memory()`): drift tracks
// schema version via SQLite's `user_version` pragma, which only persists
// across separate connections when backed by a real file.

import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';

/// A schemaVersion-1 view of [AppDatabase], used only to seed a pre-migration
/// file: creates the (identical) table structure and stamps `user_version`
/// at 1 instead of the real schema's 2.
class _LegacyV1Database extends AppDatabase {
  _LegacyV1Database(QueryExecutor executor) : super.forTesting(executor); // ignore: use_super_parameters — must forward to the named forTesting() ctor, not the default unnamed one

  @override
  int get schemaVersion => 1;
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
}

extension on AppDatabase {
  Future<Item?> getItemById(int id) =>
      (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
}
