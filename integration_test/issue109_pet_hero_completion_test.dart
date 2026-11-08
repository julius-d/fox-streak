// Issue #109 — the equipped pet flies between the post-lesson completion
// screens (summary <-> streak saved <-> XP up) and on to Home.
//
// A flight is detected by looking for a `FoxPet` that is NOT under a `Hero`
// widget mid-transition: Flutter builds the flying copy directly in the
// navigator overlay, while the two routes' own pets stay wrapped in their
// (placeholder-ed) `Hero`s. Without a flight, every pet sits under a `Hero`.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/stats/streak_service.dart';

import 'helpers.dart';

bool _isFlying() {
  return find.byKey(const Key('foxPet-$kDefaultPetId')).evaluate().any((
    element,
  ) {
    var underHero = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Hero) {
        underHero = true;
        return false;
      }
      return true;
    });
    return !underHero;
  });
}

/// Mid-transition check: a pet flight is in the air and nothing threw.
Future<void> _expectFlightMidTransition(WidgetTester tester, String why) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  expect(tester.takeException(), isNull);
  expect(_isFlying(), isTrue, reason: 'no pet flight: $why');
  await settle(tester);
}

Future<void> _tapAndExpectFlight(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await _expectFlightMidTransition(tester, 'after tapping $key');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'on a milestone completion the pet flies Summary -> StreakSaved -> '
    'Summary -> XpUp -> Summary -> Home (issue #109)',
    (tester) async {
      final db = makeIntegrationTestDb();
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 20, 9));
      final statsRepo = StatsRepository(db, clock);
      await statsRepo.setOnboarded();
      // Yesterday was day 2 -> today's completion makes day 3, a milestone.
      expect(StreakService.isMilestone(3), isTrue);
      await statsRepo.setStreak(
        streakCount: 2,
        lastActiveDay: toLocalDayString(DateTime(2026, 10, 19, 9)),
      );

      final setId = await db
          .into(db.questionSets)
          .insert(
            QuestionSetsCompanion.insert(
              packId: 1,
              title: 'Animals',
              description: const Value(''),
              createdBy: 'test',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      final itemId = await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              setId: setId,
              type: 'choice',
              prompt: 'der Hund',
              answer: 'dog',
              choices: const Value('["cat","mouse","bird"]'),
              position: 0,
            ),
          );
      // Home's Continue button derives its set from the latest attempt.
      await statsRepo.recordAttempt(
        itemId: itemId,
        ok: true,
        now: DateTime(2026, 10, 19, 9),
      );

      await pumpFoxStreakApp(
        tester,
        db: db,
        clock: clock,
        petCatalogLoader: () async => const <PetEntry>[],
      );
      await tester.tap(find.byKey(const Key('homeContinueButton')));
      await settle(tester);
      await tester.tap(find.text('dog'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
      await settle(tester);
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      // Summary -> StreakSaved
      await _expectFlightMidTransition(tester, 'Summary -> StreakSaved');
      expect(find.byKey(const Key('streakSavedScreen')), findsOneWidget);

      // StreakSaved -> Summary (which immediately pushes XpUp on top).
      await _tapAndExpectFlight(tester, 'streakSavedContinueButton');
      expect(find.byKey(const Key('xpUpScreen')), findsOneWidget);

      // XpUp -> Summary.
      await _tapAndExpectFlight(tester, 'xpUpContinueButton');
      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);

      // Summary -> Home (direct entry from Home: a single-route popUntil).
      await _tapAndExpectFlight(tester, 'homeButton');
      expect(find.byKey(const Key('homeScreen')), findsOneWidget);
    },
  );
}
