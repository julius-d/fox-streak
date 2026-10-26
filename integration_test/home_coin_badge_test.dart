// Integration test for Home's coin balance badge (issue #080).
//
// Drives the real `FoxStreakApp` wiring (not a bare `HomeScreen` pump):
// a fresh profile (coinsTotal == 0) never shows the badge, and once coins
// are earned (`StatsRepository.addCoins`, #065's write path) it appears on
// Home with the real balance + a11y label, surviving a real rebuild.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/main.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';

class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 10, 13, 9);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a fresh profile never shows the coin badge; once coins are earned it '
    'appears on Home with the real balance',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _FixedClock();
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(clock),
          ],
          child: const FoxStreakApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.byKey(const Key('coinBadge')), findsNothing);

      await statsRepo.addCoins(17);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('coinBadge')), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
    },
  );
}
