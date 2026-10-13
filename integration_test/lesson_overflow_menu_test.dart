// Integration test for the lesson AppBar overflow menu (issue #024).
//
// Drives the real `LessonScreen` with the real `MultipleChoiceCard` — no
// placeholder/test card builder — proving the overflow menu genuinely works:
// Skip is reachable pre-check, disappears once feedback is showing, and Quit
// stays reachable throughout and routes through the existing confirm dialog.

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
import 'package:fox_streak_app/test/data/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'learner skips via the overflow menu, then quits once Skip is gone post-check',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 12, 9));

      final setId = await db
          .into(db.questionSets)
          .insert(
            QuestionSetsCompanion.insert(
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
                type: 'vocab',
                prompt: prompt,
                answer: answer,
                position: position,
              ),
            );
        itemsByAnswer[answer] = Item(
          id: id,
          setId: setId,
          type: 'vocab',
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

      // LessonController.start() shuffles the queue, so determine which
      // item actually renders first rather than assuming insertion order.
      final shownFirst = itemsByAnswer.keys.firstWhere(
        (a) => find.text(a).evaluate().isNotEmpty,
      );
      final shownSecond = itemsByAnswer.keys.firstWhere((a) => a != shownFirst);
      final secondPrompt = itemsByAnswer[shownSecond]!.prompt;

      // Pre-check: opening the overflow menu offers both Quit and Skip.
      await tester.tap(find.byKey(const Key('lessonOverflowMenu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quitLessonMenuItem')), findsOneWidget);
      expect(find.byKey(const Key('skipItemMenuItem')), findsOneWidget);

      // Skip the first item via the menu — advances to the next question.
      await tester.tap(find.byKey(const Key('skipItemMenuItem')));
      await tester.pumpAndSettle();
      expect(find.text(secondPrompt), findsOneWidget);
      expect(find.text(shownSecond), findsOneWidget);

      // Answer the second item correctly, then CHECK into feedback phase.
      await tester.tap(find.text(shownSecond));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lessonFeedbackBanner')), findsOneWidget);

      // Post-check: Skip is gone from the menu, Quit remains.
      await tester.tap(find.byKey(const Key('lessonOverflowMenu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quitLessonMenuItem')), findsOneWidget);
      expect(find.byKey(const Key('skipItemMenuItem')), findsNothing);

      // Quit still routes through the existing confirm dialog.
      await tester.tap(find.byKey(const Key('quitLessonMenuItem')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirmQuitLessonButton')), findsOneWidget);
    },
  );
}
