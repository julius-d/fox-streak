// Integration test for the multiple-choice exercise card's refined spec
// (issue #006): same-set distractor fallback, direction-aware prompt
// framing, and stable choiceOption0..3 keys, all driven through the real
// `LessonScreen` -> `MultipleChoiceCard` dispatch (no synthetic card
// builder, no draft injection).

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
  DateTime now() => DateTime(2026, 10, 13, 12);
}

/// Inserts a `choice` set with 3 deEn items, none carrying stored
/// `choices` — so every option a learner sees must come from the #006
/// fallback chain (same-set siblings, then a localized placeholder).
Future<List<Item>> _persistSet(AppDatabase db) async {
  final setId = await db
      .into(db.questionSets)
      .insert(
        QuestionSetsCompanion.insert(
          title: 'Animals',
          createdBy: 'tester',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  final specs = [('Hund', 'dog'), ('Katze', 'cat'), ('Maus', 'mouse')];
  final items = <Item>[];
  for (var i = 0; i < specs.length; i++) {
    final (prompt, answer) = specs[i];
    final itemId = await db
        .into(db.items)
        .insert(
          ItemsCompanion.insert(
            setId: setId,
            type: 'choice',
            prompt: prompt,
            answer: answer,
            promptLang: const Value('de'),
            answerLang: const Value('en'),
            position: i,
          ),
        );
    items.add(
      Item(
        id: itemId,
        setId: setId,
        type: 'choice',
        prompt: prompt,
        answer: answer,
        promptLang: 'de',
        answerLang: 'en',
        position: i,
      ),
    );
  }
  return items;
}

Widget _lesson(AppDatabase db, List<Item> items) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      systemClockProvider.overrideWithValue(_FixedClock()),
    ],
    child: MaterialApp(
      theme: FoxStreakTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LessonScreen(setId: items.first.setId, items: items),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'shows direction framing, 4 stable-keyed options sourced from the '
    'set (not just placeholders), and completes CHECK -> CONTINUE',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final items = await _persistSet(db);

      await tester.pumpWidget(_lesson(db, items));
      await tester.pumpAndSettle();

      // Direction framing is shown (mirrors #007's free-text framing).
      expect(find.text('German → English'), findsOneWidget);

      // All 4 stable #016 keys are present, fixed by rendered position.
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('choiceOption$i')), findsOneWidget);
      }

      // LessonController shuffles the queue, so work out which item is
      // showing first by its (unique) prompt — unlike answers, prompts
      // never double as another item's distractor, so this is unambiguous
      // even though every answer is visible at once (see below).
      final shownItem = items.firstWhere(
        (i) => find.text(i.prompt).evaluate().isNotEmpty,
      );
      final shownAnswer = shownItem.answer;
      final siblingAnswers = items
          .where((i) => i.id != shownItem.id)
          .map((i) => i.answer)
          .toList();

      // With only 3 items in the set and 3 distractor slots needed, both
      // other items' answers are pulled in as distractors (#006 same-set
      // fallback) — never just a generic placeholder.
      for (final sibling in siblingAnswers) {
        expect(find.text(sibling), findsOneWidget);
      }

      await tester.tap(find.text(shownAnswer));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);
      expect(find.text('Correct!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pumpAndSettle();

      // Advances to the next question (still a choice card) rather than
      // getting stuck re-showing the just-answered item. Checks the prompt,
      // not the answer: the answer may legitimately reappear as a same-set
      // fallback distractor on the next question.
      expect(find.text(shownItem.prompt), findsNothing);
    },
  );
}
