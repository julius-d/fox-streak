import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/settings_repository.dart';

import 'test_helpers.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = makeTestDb();
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getSettings', () {
    test('creates the default row once (id 0), both toggles on', () async {
      final first = await repo.getSettings();
      expect(first.id, kSettingsId);
      expect(first.hapticsEnabled, isTrue);
      expect(first.soundEnabled, isTrue);

      final second = await repo.getSettings();
      expect(second.id, kSettingsId);
      final rows = await (db.select(db.appSettings)).get();
      expect(rows, hasLength(1));
    });
  });

  group('setHapticsEnabled', () {
    test('persists false, then true again', () async {
      await repo.setHapticsEnabled(value: false);
      expect((await repo.getSettings()).hapticsEnabled, isFalse);

      await repo.setHapticsEnabled(value: true);
      expect((await repo.getSettings()).hapticsEnabled, isTrue);
    });

    test('creates the default row as a side effect, then updates it', () async {
      expect(await (db.select(db.appSettings)).get(), isEmpty);
      await repo.setHapticsEnabled(value: false);
      final rows = await (db.select(db.appSettings)).get();
      expect(rows, hasLength(1));
      expect(rows.single.hapticsEnabled, isFalse);
    });

    test('never touches soundEnabled', () async {
      await repo.setHapticsEnabled(value: false);
      expect((await repo.getSettings()).soundEnabled, isTrue);
    });
  });

  group('setSoundEnabled', () {
    test('persists false, then true again', () async {
      await repo.setSoundEnabled(value: false);
      expect((await repo.getSettings()).soundEnabled, isFalse);

      await repo.setSoundEnabled(value: true);
      expect((await repo.getSettings()).soundEnabled, isTrue);
    });

    test('never touches hapticsEnabled', () async {
      await repo.setSoundEnabled(value: false);
      expect((await repo.getSettings()).hapticsEnabled, isTrue);
    });
  });
}
