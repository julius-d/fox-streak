// Shared test helpers for the data layer (issue #002).

import 'package:drift/native.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';

/// Controllable clock for tests.
class FakeClock extends Clock {
  DateTime _now;
  FakeClock(DateTime now) : _now = now;

  @override
  DateTime now() => _now;

  void setNow(DateTime value) {
    _now = value;
  }
}

/// In-memory database for repository tests.
///
/// Callers must `await db.close()` in `tearDown` (see usage in
/// `sets_repository_test.dart`).
AppDatabase makeTestDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Fixed "today" used across codec/repository tests (local noon, safely
/// inside range so seed/demo dates validate).
final DateTime kTestToday = DateTime(2026, 10, 11, 12);
