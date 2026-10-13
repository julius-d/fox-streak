// Drift + SQLite schema v1 (issue #002).
//
// Tables mirror the issue spec exactly. Validation of *values* lives in
// `validation.dart` / `set_json_codec.dart` and the repositories — the DB
// only enforces structure (PKs, FK cascades, defaults).
//
// Code generation: `dart run build_runner build --delete-conflicting-outputs`
// produces `database.g.dart` (committed).

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Question sets (lesson packs).
class QuestionSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  // Free-text creator name (trimmed, non-empty, max 50 chars — validated in
  // Dart via `validateCreatorName` in validation.dart).
  TextColumn get createdBy => text()();
  // Epoch millis.
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// Items belonging to a set, ordered by [position].
class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId =>
      integer().references(QuestionSets, #id, onDelete: KeyAction.cascade)();
  // choice|freeText|phone|date — enforced in Dart. `choice`/`freeText` are
  // the #026 split of #002's original `vocab` type.
  TextColumn get type => text()();
  TextColumn get prompt => text()();
  TextColumn get answer => text()();
  // deEn|enDe: required for choice, optional for freeText, NULL otherwise.
  TextColumn get direction => text().nullable()();
  // JSON array of distractors, choice only, NULL otherwise.
  TextColumn get choices => text().nullable()();
  TextColumn get hint => text().nullable().withDefault(const Constant(''))();
  IntColumn get position => integer()();
}

/// One row per graded answer. No per-attempt XP column (see #010).
class Attempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId =>
      integer().references(Items, #id, onDelete: KeyAction.cascade)();
  BoolColumn get ok => boolean()();
  // Epoch millis.
  IntColumn get at => integer()();
}

/// Single-row profile (id fixed to 0).
///
/// Column ownership (do not cross-write):
/// - `xpTotal` — written exclusively by #010 `XpService`.
/// - `streakCount` / `lastActiveDay` — written exclusively by #011
///   `StreakService`. [StatsRepository.recordAttempt] must NOT touch them.
/// - `dailyGoalXp` — editable (see #012), written by [StatsRepository].
class ProfileStats extends Table {
  IntColumn get id => integer()();
  IntColumn get xpTotal => integer().withDefault(const Constant(0))();
  IntColumn get streakCount => integer().withDefault(const Constant(0))();
  // YYYY-MM-DD in local tz, NULL until first activity.
  TextColumn get lastActiveDay => text().nullable()();
  IntColumn get dailyGoalXp => integer().withDefault(const Constant(30))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [QuestionSets, Items, Attempts, ProfileStats])
class AppDatabase extends _$AppDatabase {
  /// Production constructor backed by `drift_flutter`.
  AppDatabase() : super(_openConnection());

  /// Test / tooling constructor (e.g. `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 (#026): vocab's multiple-choice half becomes `choice` (the only
      // vocab exercise ever practiced via #006's MCQ card to date);
      // `freeText` is purely additive for items created after this lands.
      if (from < 2) {
        await customStatement(
          "UPDATE items SET type = 'choice' WHERE type = 'vocab'",
        );
      }
    },
    beforeOpen: (details) async {
      // SQLite disables FK enforcement by default; without this,
      // ON DELETE CASCADE on items/attempts is silently ignored.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // v1 had no migrations; v2 (#026) added the vocab->choice rewrite above.
}

DatabaseConnection _openConnection() => driftDatabase(name: 'fox_streak');
