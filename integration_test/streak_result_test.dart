// Integration test for streak display on the streak-saved completion
// screen (issue #011; moved from the combined lesson result screen onto
// its own dedicated `StreakSavedScreen` by issue #078).
//
// Drives the real `LessonScreen` with the real `MultipleChoiceCard` (no
// test card builder) through a lesson that lands on a streak milestone,
// proving the streak headline and `StreakBadge` genuinely render with the
// right numbers — and that the underlying `streak_count`/`last_active_day`
// columns were actually written exactly once. Also proves the equipped
// pet now appears on both `StreakSavedScreen` and `XpUpScreen` for this
// milestone completion (issue #081 — #059 had retired the old on-fire/lit/
// empty-state painter without replacing it with anything streak-aware).

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/data/stats_repository.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/pet/pet_catalog.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completing a lesson the day after a 2-day streak hits the 3-day '
      'milestone: on-fire pet, streak headline, and StreakBadge render, '
      'and streak_count/last_active_day are written exactly once', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 10, 13, 9));
    final statsRepo = StatsRepository(db, clock);

    // Pre-seed a 2-day streak, last active yesterday — today's completed
    // lesson should bump it to 3, a milestone.
    await statsRepo.setStreak(streakCount: 2, lastActiveDay: '2026-10-12');

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
    final itemsByAnswer = <String, Item>{};
    for (final (prompt, answer, position) in [
      ('der Hund', 'dog', 0),
      ('die Katze', 'cat', 1),
    ]) {
      final id = await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              setId: setId,
              type: 'choice',
              prompt: prompt,
              answer: answer,
              position: position,
            ),
          );
      itemsByAnswer[answer] = Item(
        id: id,
        setId: setId,
        type: 'choice',
        prompt: prompt,
        answer: answer,
        position: position,
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemClockProvider.overrideWithValue(clock),
          integrationTestSilentSound,
        ],
        child: MaterialApp(
          theme: FoxStreakTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LessonScreen(
            setId: setId,
            items: itemsByAnswer.values.toList(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      final shown = itemsByAnswer.keys.firstWhere(
        (a) => find.text(a).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(shown));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
      if (i == 1) {
        // The final CONTINUE completes the lesson, mounting the
        // confetti-bearing `StreakSavedScreen` (#083): its
        // `ConfettiController` drives particle physics off real
        // wall-clock time rather than this binding's fake clock, so
        // `pumpAndSettle()` would spin until it times out (see
        // `level_up_result_test.dart`'s file doc for the same issue with
        // `XpUpScreen`'s own confetti) — `settle()` (`helpers.dart`)
        // absorbs that.
        await settle(tester);
      } else {
        await tester.pumpAndSettle();
      }
    }

    // This fresh profile's completion also advances the streak, so the
    // streak-saved screen appears automatically (the loop above's final
    // CONTINUE tap already settled its push): milestone hit -> streak
    // headline and the StreakBadge both showing "3", plus the equipped
    // pet (issue #081) and a denser/longer confetti burst than a plain
    // streak-saved screen's.
    expect(find.byKey(const Key('streakSavedScreen')), findsOneWidget);
    expect(find.text('3-day streak!'), findsOneWidget);
    expect(find.byKey(const Key('streakBadge')), findsOneWidget);
    expect(find.byKey(const Key('streakCountLabel')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('streakSavedScreen')),
        matching: find.byKey(const Key('foxPet-$kDefaultPetId')),
      ),
      findsOneWidget,
    );

    // Continue through to XP-up (#081: the pet shows there too).
    await tester.tap(find.byKey(const Key('streakSavedContinueButton')));
    await settle(tester);

    expect(find.byKey(const Key('xpUpScreen')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('xpUpScreen')),
        matching: find.byKey(const Key('foxPet-$kDefaultPetId')),
      ),
      findsOneWidget,
    );
    // Unlike `StreakSavedScreen`'s decorative pet (justified by its own
    // heading/streak text), `XpUpScreen` has no such text, so its pet
    // carries its own milestone a11y announcement (issue #111).
    expect(find.bySemanticsLabel('Streak milestone!'), findsOneWidget);

    // The write actually landed exactly once (no double-apply).
    final profile = await statsRepo.getProfile();
    expect(profile.streakCount, 3);
    expect(profile.lastActiveDay, '2026-10-13');
  });
}
