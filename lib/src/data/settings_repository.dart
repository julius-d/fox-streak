// App-preferences repository (issue #055).

import 'package:drift/drift.dart';

import 'database.dart';

/// Fixed id of the single per-device settings row.
const int kSettingsId = 0;

/// Repository for `app_settings` (haptics/sound toggles), separate from
/// [ProfileStats] (progress/XP/streak, see `StatsRepository`).
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(AppDatabase db) : _db = db;

  /// Returns the settings row, creating the default (both on) row on first
  /// use.
  Future<AppSetting> getSettings() async {
    final existing = await (_db.select(
      _db.appSettings,
    )..where((t) => t.id.equals(kSettingsId))).getSingleOrNull();
    if (existing != null) return existing;
    await _db
        .into(_db.appSettings)
        .insert(
          const AppSettingsCompanion(
            id: Value(kSettingsId),
            hapticsEnabled: Value(true),
            soundEnabled: Value(true),
          ),
        );
    return const AppSetting(
      id: kSettingsId,
      hapticsEnabled: true,
      soundEnabled: true,
    );
  }

  /// Persists the haptics toggle (mirrors [foxHapticsEnabledProvider]'s
  /// in-memory state; `SettingsScreen` writes both on every change).
  Future<void> setHapticsEnabled({required bool value}) async {
    await getSettings();
    await (_db.update(_db.appSettings)..where((t) => t.id.equals(kSettingsId)))
        .write(AppSettingsCompanion(hapticsEnabled: Value(value)));
  }

  /// Persists the sound toggle (mirrors [foxSoundEnabledProvider]'s
  /// in-memory state; `SettingsScreen` writes both on every change).
  Future<void> setSoundEnabled({required bool value}) async {
    await getSettings();
    await (_db.update(_db.appSettings)..where((t) => t.id.equals(kSettingsId)))
        .write(AppSettingsCompanion(soundEnabled: Value(value)));
  }
}
