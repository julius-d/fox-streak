// Integration test for issue #066 — the lesson progress bar animates its
// growth instead of snapping.
//
// Drives the real `LessonScreen` through a two-item lesson and checks the
// `lessonProgressBar`'s underlying `LinearProgressIndicator` mid-tween after
// the first CHECK: it must be strictly between the old (0) and new (0.5)
// value, not already snapped to either — proving the animation actually
// plays rather than `FoxProgressBar` jumping instantly as it would with
// `animated: false`.

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
    'the lesson progress bar animates its fill between items instead of '
    'snapping',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = FakeClock(DateTime(2026, 10, 26, 9));

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

      Finder progressFill() => find.descendant(
        of: find.byKey(const Key('lessonProgressBar')),
        matching: find.byType(LinearProgressIndicator),
      );

      // Starting bar: nothing answered yet.
      expect(
        progressFill().evaluate().single.widget,
        isA<LinearProgressIndicator>(),
      );
      expect(
        tester.widget<LinearProgressIndicator>(progressFill()).value,
        closeTo(0, 1e-9),
      );

      // `LessonController.start()` shuffles the queue; find whichever item
      // renders first so the correct answer can be tapped.
      final shownFirst = itemsByAnswer.keys.firstWhere(
        (a) => find.text(a).evaluate().isNotEmpty,
      );

      await tester.tap(find.text(shownFirst));
      await tester.pump();
      await tester.tap(find.byKey(const Key('checkButton'))); // CHECK
      // One zero-duration frame: the (fast, in-memory) recordAttempt write
      // resolves via the microtask queue, moving progress from 0 -> 0.5 and
      // starting the tween at its very first frame.
      await tester.pump();
      expect(
        tester.widget<LinearProgressIndicator>(progressFill()).value,
        closeTo(0, 1e-9),
      );

      // Mid-tween: strictly between the old (0) and new (0.5) value.
      await tester.pump(const Duration(milliseconds: 150));
      final double midway = tester
          .widget<LinearProgressIndicator>(progressFill())
          .value!;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(0.5));

      // Tween settles on the new value once ~300ms have elapsed.
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<LinearProgressIndicator>(progressFill()).value,
        closeTo(0.5, 1e-9),
      );

      // Drains the CHECK feedback sound effect's own animation/position
      // polling so none is still scheduled when the widget tree is torn
      // down (same reason every other lesson integration test ends on a
      // settle rather than a fixed-duration pump).
      await tester.pumpAndSettle();
    },
  );
}
