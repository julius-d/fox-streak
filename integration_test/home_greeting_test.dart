// Integration test for Home's holiday + funny-rotation greeting layers
// (issue #061), on top of #012's plain time-of-day greeting.
//
// Drives the real `FoxStreakApp` (same pattern as
// `integration_test/home_screen_test.dart`) with a fixed `Clock` override,
// confirming the greeting text rendered on Home end-to-end for a holiday
// date and for a funny-rotation-selected date.

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/main.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';

class _FixedClock extends Clock {
  final DateTime _now;
  _FixedClock(this._now);

  @override
  DateTime now() => _now;
}

Future<void> _pumpOnboardedApp(WidgetTester tester, Clock clock) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await StatsRepository(db, clock).setOnboarded();

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
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a fixed-date holiday overrides Home\'s greeting end-to-end', (
    tester,
  ) async {
    await _pumpOnboardedApp(tester, _FixedClock(DateTime(2026, 12, 25, 8)));

    expect(find.byKey(const Key('homeScreen')), findsOneWidget);
    expect(find.text('Merry Christmas!'), findsOneWidget);
  });

  testWidgets(
    'on a funny-rotation-selected day, Home shows that variant end-to-end',
    (tester) async {
      // Deterministic per-day pick (see test/home/greeting_test.dart):
      // 2026-01-03 is selected, pool index 0.
      await _pumpOnboardedApp(tester, _FixedClock(DateTime(2026, 1, 3, 9)));

      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
      expect(find.text('Ready to level up today?'), findsOneWidget);
      expect(find.text('Good morning!'), findsNothing);
    },
  );
}
