// Issue #071 — the pet's Lottie loops with a random pause instead of
// playing once.
//
// Drives the real app to Home (same production wiring/providers as every
// other `FoxPet` call site) and proves `homePetButton`'s pet actually
// loops: play once, go idle, then replay once the pause elapses — not just
// in isolation (see `test/widgets/fox_pet_test.dart` for the seeded-Random
// and reduce-motion unit coverage), but wired into a real screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/widgets/fox_pet.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Home's pet plays once, then loops again after its pause", (
    tester,
  ) async {
    final db = makeIntegrationTestDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 26, 9));
    await StatsRepository(db, clock).setOnboarded();

    await pumpFoxStreakApp(tester, db: db, clock: clock);
    expect(find.byKey(const Key('homeScreen')), findsOneWidget);
    expect(find.byKey(const Key('homePetButton')), findsOneWidget);

    // Composition load + the first play-through: goes idle well before
    // the >=3s pause even starts counting down.
    await settle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);

    // The pause is re-rolled in [3s, 8s] each cycle; the max guarantees
    // a replay has started by then regardless of the random draw.
    await tester.pump(kFoxPetMaxPause);
    expect(tester.binding.hasScheduledFrame, isTrue);

    // Let the replay finish so no timer/animation is left pending at
    // teardown.
    await settle(tester);
  });
}
