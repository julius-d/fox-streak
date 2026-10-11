import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/sets_repository.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';

import 'test_helpers.dart';

void main() {
  test('providers wire repositories with overrideable db + clock', () async {
    final db = makeTestDb();
    final clock = FakeClock(kTestToday);
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);

    final sets = container.read(setsRepositoryProvider);
    final stats = container.read(statsRepositoryProvider);
    expect(sets, isA<SetsRepository>());
    expect(stats, isA<StatsRepository>());

    final setId = await sets.createSet(title: 'P', createdBy: 'learner');
    final itemId = await sets.addItem(
      setId: setId,
      type: 'phone',
      prompt: 'P',
      answer: '0171',
    );
    await stats.recordAttempt(itemId: itemId, ok: true);
    expect(await stats.countAttempts(), 1);
  });
}
