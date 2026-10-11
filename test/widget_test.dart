import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/main.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';

import 'data/test_helpers.dart';

void main() {
  testWidgets('App boots to the set library', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async => db.close());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(FakeClock(kTestToday)),
        ],
        child: const FoxStreakApp(),
      ),
    );
    // Bounded settle: see note in test/library/library_screen_test.dart
    // about pumpAndSettle vs drift watch streams.
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (!tester.binding.hasScheduledFrame) break;
    }
    expect(tester.binding.hasScheduledFrame, isFalse);

    expect(find.text('My Sets'), findsOneWidget);
    expect(find.byKey(const Key('newSetFab')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  });
}
