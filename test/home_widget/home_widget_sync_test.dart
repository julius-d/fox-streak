// Verifies the widget is re-pushed when profile data or the equipped pet
// change in the app (issue #115), against an in-memory database.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/home_widget/home_widget_bridge.dart';
import 'package:fox_streak_app/src/home_widget/home_widget_payload.dart';
import 'package:fox_streak_app/src/home_widget/home_widget_providers.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/stats/pet_service.dart';

import '../data/test_helpers.dart';

class _RecordingBridge implements HomeWidgetBridge {
  final List<HomeWidgetPayload> payloads = <HomeWidgetPayload>[];

  @override
  Future<void> update(HomeWidgetPayload payload) async => payloads.add(payload);
}

Future<void> _pumpEvents() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late StatsRepository stats;
  late _RecordingBridge bridge;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = FakeClock(DateTime(2026, 11, 8, 12));
    stats = StatsRepository(db, clock);
    bridge = _RecordingBridge();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        systemClockProvider.overrideWithValue(clock),
        homeWidgetBridgeProvider.overrideWithValue(bridge),
        homeWidgetLocaleProvider.overrideWithValue(const Locale('en')),
        petCatalogLoaderProvider.overrideWithValue(
          () async => PetCatalog.entries,
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.close();
    });
    container.listen(homeWidgetSyncProvider, (_, _) {});
    await _pumpEvents();
  });

  test('pushes the initial profile', () {
    expect(bridge.payloads, isNotEmpty);
    expect(bridge.payloads.last.current.streakCount, 0);
    expect(bridge.payloads.last.petEmoji, '🦊');
  });

  test('pushes again after XP and streak change', () async {
    await stats.addXp(30);
    await stats.setStreak(streakCount: 4, lastActiveDay: '2026-11-08');
    await _pumpEvents();

    final last = bridge.payloads.last;
    expect(last.current.todayXp, 30);
    expect(last.current.streakCount, 4);
    expect(last.current.ringFill, 0.3);
  });

  test('pushes again after the daily goal changes', () async {
    await stats.addXp(30);
    await stats.setStreak(streakCount: 1, lastActiveDay: '2026-11-08');
    await stats.updateDailyGoal(60);
    await _pumpEvents();

    expect(bridge.payloads.last.current.dailyGoalXp, 60);
    expect(bridge.payloads.last.current.ringFill, 0.5);
  });

  test('pushes again after a different pet is equipped', () async {
    final other = PetCatalog.entries[1];
    await stats.setEquippedPet(other.id);
    await _pumpEvents();

    expect(bridge.payloads.last.petEmoji, other.emoji);
  });
}
