// Riverpod wiring for the data layer (issue #002).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
import 'database.dart';
import 'seed_loader.dart';
import 'sets_repository.dart';
import 'stats_repository.dart';

/// Production database (drift_flutter, name `fox_streak`).
///
/// Override in tests with `AppDatabase.forTesting(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Clock used for timestamps; override with a fake in tests.
final systemClockProvider = Provider<Clock>((ref) => SystemClock());

final setsRepositoryProvider = Provider<SetsRepository>((ref) {
  return SetsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(systemClockProvider),
  );
});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(systemClockProvider),
  );
});

final seedLoaderProvider = Provider<SeedLoader>((ref) {
  return SeedLoader(ref.watch(setsRepositoryProvider));
});
