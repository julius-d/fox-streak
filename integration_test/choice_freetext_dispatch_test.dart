// Integration test for the #026 lesson-shell dispatch migration.
//
// Drives the real `LessonScreen` (no synthetic cardBuilder override, no
// draft injection) through a `choice` item (the renamed `vocab` type,
// routed to `MultipleChoiceCard`) and a `freeText` item (routed to the real
// `FreeTextExercise` card for the first time ever in the live app — #007
// built it, but it was unreachable until this issue's dispatch wiring
// landed). Proves the rename + new wiring actually work through the real
// UI, not just that the pure helpers are correct.
//
// Each item runs its own single-item lesson (rather than one two-item
// lesson) because `LessonController.start()` shuffles the queue, so a
// shared lesson can't deterministically assert which card renders first.
// Items are inserted into a real (in-memory) db first — `submitGrade()`
// writes an `attempts` row FK-referencing `items.id`, so a synthetic
// never-persisted `Item` would fail that constraint on CHECK.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/clock.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/data/providers.dart';
import 'package:fox_streak_app/src/lesson/lesson_screen.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

class _FixedClock extends Clock {
  @override
  DateTime now() => DateTime(2026, 10, 12, 12);
}

/// Inserts one set with one item into [db] and returns the persisted [Item].
Future<Item> _persistSingleItem(
  AppDatabase db, {
  required String type,
  required String prompt,
  required String answer,
  String? direction,
}) async {
  final setId = await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          title: 'Test set',
          createdBy: 'tester',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  final itemId = await db
      .into(db.items)
      .insert(
        ItemsCompanion.insert(
          setId: setId,
          type: type,
          prompt: prompt,
          answer: answer,
          direction: direction == null
              ? const Value.absent()
              : Value(direction),
          position: 0,
        ),
      );
  return Item(
    id: itemId,
    setId: setId,
    type: type,
    prompt: prompt,
    answer: answer,
    direction: direction,
    position: 0,
  );
}

Widget _singleItemLesson(AppDatabase db, Item item) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      systemClockProvider.overrideWithValue(_FixedClock()),
    ],
    child: MaterialApp(
      theme: FoxStreakTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LessonScreen(setId: item.setId, items: [item]),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('choice item dispatches to the real MultipleChoiceCard', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final item = await _persistSingleItem(
      db,
      type: 'choice',
      prompt: 'Hund',
      answer: 'dog',
      direction: 'deEn',
    );

    await tester.pumpWidget(_singleItemLesson(db, item));
    await tester.pumpAndSettle();

    expect(find.text('Hund'), findsOneWidget);
    await tester.tap(find.text('dog'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('checkButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('checkButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
  });

  testWidgets(
    'freeText item dispatches to the real FreeTextExercise card (newly wired by #026)',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final item = await _persistSingleItem(
        db,
        type: 'freeText',
        prompt: 'Capital of France',
        answer: 'Paris',
      );

      await tester.pumpWidget(_singleItemLesson(db, item));
      await tester.pumpAndSettle();

      expect(find.text('Capital of France'), findsOneWidget);
      expect(find.byKey(const Key('freeTextAnswerField')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('freeTextAnswerField')),
        'paris',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lessonResultScreen')), findsOneWidget);
    },
  );
}
