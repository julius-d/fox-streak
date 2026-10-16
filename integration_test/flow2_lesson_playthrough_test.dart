// Flow 2 — Lesson play-through (issue #016, builds on #005-#009).
//
// Drives the real `LessonScreen` through one item of each exercise type
// (choice, freeText, phone, date) via CHECK -> feedback -> CONTINUE, reaches
// the result screen, and separately proves quitting via the overflow menu's
// confirm leaves no dead-end (pops back to whatever pushed the lesson).

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

import 'helpers.dart';

Future<int> _insertMixedTypeSet(AppDatabase db) async {
  final setId = await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          title: 'Mixed',
          description: const Value(''),
          createdBy: 'test',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  await db
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
  await db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: 'freeText',
          prompt: 'Capital of France',
          answer: 'Paris',
          position: 1,
        ),
      );
  await db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: 'phone',
          prompt: 'Mama',
          answer: '01711234567',
          position: 2,
        ),
      );
  await db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: 'date',
          prompt: 'Omas Geburtstag',
          answer: '1950-01-01',
          position: 3,
        ),
      );
  return setId;
}

/// Answers whichever exercise card is currently showing, correctly, then
/// drives CHECK -> feedback -> CONTINUE. The queue is shuffled, so the test
/// dispatches on which type's distinguishing finder is present rather than
/// assuming an order.
Future<void> _answerCurrentItemCorrectly(WidgetTester tester) async {
  if (find.byKey(const Key('choiceOption0')).evaluate().isNotEmpty) {
    await tester.tap(find.text('dog'));
  } else if (find
      .byKey(const Key('freeTextAnswerField'))
      .evaluate()
      .isNotEmpty) {
    await tester.enterText(
      find.byKey(const Key('freeTextAnswerField')),
      'Paris',
    );
  } else if (find.byKey(const Key('dialPadDisplay')).evaluate().isNotEmpty) {
    for (final digit in '01711234567'.split('')) {
      final key = find.byKey(Key('dialPadKey$digit'));
      // The keypad is taller than the test window and lives in a
      // SingleChildScrollView, so a key can be laid out below the visible
      // viewport — scroll it into view first, or the computed tap offset
      // falls outside the rendered area and misses every key the same way.
      await tester.ensureVisible(key);
      await tester.pump();
      await tester.tap(key);
      await tester.pump(const Duration(milliseconds: 100));
    }
  } else if (find
      .byKey(const Key('dateExerciseDayField'))
      .evaluate()
      .isNotEmpty) {
    await tester.enterText(find.byKey(const Key('dateExerciseDayField')), '01');
    await tester.enterText(
      find.byKey(const Key('dateExerciseMonthField')),
      '01',
    );
    await tester.enterText(
      find.byKey(const Key('dateExerciseYearField')),
      '1950',
    );
  } else {
    fail('no known exercise card is showing');
  }
  await tester.pump();
  await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
  await settle(tester);
  await tester.tap(find.byKey(const Key('checkButton'))); // CONTINUE
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'one choice + freeText + phone + date item each answered correctly '
    'reaches the result screen with a perfect score',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 14, 9));

      final setId = await _insertMixedTypeSet(db);
      final items = await db.select(db.items).get();

      await pumpLessonScreen(
        tester,
        db: db,
        clock: clock,
        setId: setId,
        items: items,
      );

      for (var i = 0; i < items.length; i++) {
        expect(find.byKey(const Key('lessonProgressBar')), findsOneWidget);
        await _answerCurrentItemCorrectly(tester);
      }

      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
      final l10n = AppLocalizationsEn();
      expect(
        find.text(l10n.lessonScoreSummary(items.length, items.length, 100)),
        findsOneWidget,
      );
      expect(find.text('${items.length} / ${items.length}'), findsOneWidget);
    },
  );

  testWidgets(
    'quitting via the overflow menu confirm pops back to whatever pushed '
    'the lesson, leaving no dead-end',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 14, 9));

      final setId = await _insertMixedTypeSet(db);
      final items = await db.select(db.items).get();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            systemClockProvider.overrideWithValue(clock),
          ],
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              key: Key('placeholderHome'),
              body: Center(child: Text('placeholder')),
            ),
          ),
        ),
      );

      // Push the real LessonScreen the way SetDetailScreen/HomeScreen do.
      // Deliberately not awaited: `Navigator.push`'s future only resolves
      // when the pushed route is later popped (by the quit below), so
      // awaiting it here would hang forever.
      await settle(tester);
      final context = tester.element(find.byKey(const Key('placeholderHome')));
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LessonScreen(setId: setId, items: items),
          ),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('lessonProgressBar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lessonOverflowMenu')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('quitLessonMenuItem')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirmQuitLessonButton')));
      await settle(tester);

      expect(find.byKey(const Key('placeholderHome')), findsOneWidget);
      expect(find.byKey(const Key('lessonProgressBar')), findsNothing);
    },
  );
}
