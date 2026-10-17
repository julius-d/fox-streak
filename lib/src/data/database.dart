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

import '../mascot/mascot_catalog.dart' show kDefaultMascotId;

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
  // v6 (#045): one of `kSetCategories` (validation.dart), drives the
  // choice/freeText icon (item_type_icons.dart). NULL on pre-#045 rows and
  // treated as `vocab` everywhere category is read — no backfill.
  TextColumn get category => text().nullable()();
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
  // ISO 639-1 codes (e.g. de/en): optional for choice/freeText (set/unset
  // together), NULL otherwise. Replaces the v3 `direction` enum (#022) so
  // adding a language is just adding a code to `kSupportedLanguages`.
  TextColumn get promptLang => text().nullable()();
  TextColumn get answerLang => text().nullable()();
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
/// - `xpTotal` / `todayXp` — written exclusively by #010 `XpService`, via
///   `StatsRepository.addXp` (same call site, same done-guard). `todayXp`
///   resets to the lesson's earned XP on a day change (vs. `lastActiveDay`)
///   and accumulates otherwise; #012's `FoxGoalRing` reads it read-only.
/// - `streakCount` / `lastActiveDay` — written exclusively by #011
///   `StreakService`. [StatsRepository.recordAttempt] must NOT touch them.
/// - `dailyGoalXp` — editable (see #012), written by [StatsRepository].
/// - `displayName` / `hasOnboarded` — written exclusively by #012's
///   [StatsRepository.setDisplayName]/[StatsRepository.setOnboarded].
/// - `equippedMascotId` / `lessonsCompletedToday` / `lessonsCompletedDay` —
///   written exclusively by #059 `MascotService`, via
///   [StatsRepository.setEquippedMascot]/
///   [StatsRepository.setMascotLessonCounter]. `lessonsCompletedToday`
///   resets on a new local day (vs. `lessonsCompletedDay`), mirroring
///   `todayXp`'s own day-scoped reset — it cannot reuse `lastActiveDay`
///   (StreakService-owned-write, see above).
class ProfileStats extends Table {
  IntColumn get id => integer()();
  IntColumn get xpTotal => integer().withDefault(const Constant(0))();
  IntColumn get streakCount => integer().withDefault(const Constant(0))();
  // YYYY-MM-DD in local tz, NULL until first activity.
  TextColumn get lastActiveDay => text().nullable()();
  IntColumn get dailyGoalXp => integer().withDefault(const Constant(100))();
  // v3 (#010): XP earned on the current `lastActiveDay`, day-scoped.
  IntColumn get todayXp => integer().withDefault(const Constant(0))();
  // v5 (#012): optional display name, settable via onboarding/tap-to-rename.
  TextColumn get displayName => text().nullable()();
  // v5 (#012): true once first-run onboarding has completed/been skipped.
  BoolColumn get hasOnboarded => boolean().withDefault(const Constant(false))();
  // v8 (#059): the currently-equipped mascot's catalog ID.
  TextColumn get equippedMascotId =>
      text().withDefault(const Constant(kDefaultMascotId))();
  // v8 (#059): lesson-completion counter for the current
  // `lessonsCompletedDay`, driving the twice-a-day lootbox trigger.
  IntColumn get lessonsCompletedToday =>
      integer().withDefault(const Constant(0))();
  // v8 (#059): YYYY-MM-DD in local tz the counter above is scoped to, NULL
  // until the first lesson completion.
  TextColumn get lessonsCompletedDay => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mascots the profile has unlocked (issue #059). One row per owned mascot,
/// keyed by its stable catalog ID — never an array index, so the catalog
/// surviving new files being added later never invalidates existing rows.
///
/// Sole writer: `MascotService`, via `MascotRepository.addOwnedMascot`.
class OwnedMascots extends Table {
  TextColumn get mascotId => text()();
  // Epoch millis.
  IntColumn get acquiredAt => integer()();

  @override
  Set<Column> get primaryKey => {mascotId};
}

/// Single-row app preferences (id fixed to 0), separate from [ProfileStats]
/// (progress/XP/streak) — see issue #055.
///
/// v7 (#055): both `hapticsEnabled` and `soundEnabled` are read/written via
/// [SettingsRepository] and surfaced by `SettingsScreen`'s two switches.
class AppSettings extends Table {
  IntColumn get id => integer()();
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    QuestionSets,
    Items,
    Attempts,
    ProfileStats,
    AppSettings,
    OwnedMascots,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production constructor backed by `drift_flutter`.
  AppDatabase() : super(_openConnection());

  /// Test / tooling constructor (e.g. `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

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
      // v3 (#010): adds the day-scoped `todayXp` counter.
      if (from < 3) {
        await m.addColumn(profileStats, profileStats.todayXp);
      }
      // v4 (#022): replaces `direction` (deEn|enDe) with the generic
      // `promptLang`/`answerLang` ISO 639-1 pair, then drops `direction`.
      if (from < 4) {
        await m.addColumn(items, items.promptLang);
        await m.addColumn(items, items.answerLang);
        await customStatement(
          'UPDATE items SET '
          "prompt_lang = CASE direction WHEN 'deEn' THEN 'de' WHEN 'enDe' "
          "THEN 'en' END, "
          "answer_lang = CASE direction WHEN 'deEn' THEN 'en' WHEN 'enDe' "
          "THEN 'de' END "
          "WHERE direction IN ('deEn', 'enDe')",
        );
        await m.dropColumn(items, 'direction');
      }
      // v5 (#012): adds optional display name + the onboarding-shown gate.
      if (from < 5) {
        await m.addColumn(profileStats, profileStats.displayName);
        await m.addColumn(profileStats, profileStats.hasOnboarded);
      }
      // v6 (#045): adds the optional set category; existing rows stay NULL
      // (treated as `vocab` everywhere category is read), no backfill.
      if (from < 6) {
        await m.addColumn(questionSets, questionSets.category);
      }
      // v7 (#055): adds the single-row app-preferences table (haptics/sound
      // toggles), separate from profileStats.
      if (from < 7) {
        await m.createTable(appSettings);
      }
      // v8 (#059): adds the owned-mascots table + profileStats's
      // mascot-collection columns. `addColumn` applies each column's Dart
      // default (the fox for `equippedMascotId`, 0/NULL for the
      // no-activity-yet lesson counter) to existing rows too.
      if (from < 8) {
        await m.createTable(ownedMascots);
        await m.addColumn(profileStats, profileStats.equippedMascotId);
        await m.addColumn(profileStats, profileStats.lessonsCompletedToday);
        await m.addColumn(profileStats, profileStats.lessonsCompletedDay);
      }
    },
    beforeOpen: (details) async {
      // SQLite disables FK enforcement by default; without this,
      // ON DELETE CASCADE on items/attempts is silently ignored.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // v1 had no migrations; v2 (#026) added the vocab->choice rewrite above;
  // v3 (#010) added `profileStats.todayXp`; v4 (#022) replaced
  // `items.direction` with `promptLang`/`answerLang`; v5 (#012) added
  // `profileStats.displayName`/`hasOnboarded`; v6 (#045) added
  // `questionSets.category`; v7 (#055) added the `appSettings` table; v8
  // (#059) added the `ownedMascots` table + `profileStats.equippedMascotId`/
  // `lessonsCompletedToday`/`lessonsCompletedDay`.
}

DatabaseConnection _openConnection() => driftDatabase(name: 'fox_streak');
