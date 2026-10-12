// Integration test for the date exercise card (issue #009).
//
// Drives the real `DateExercise` widget like a user would: types digits
// into the actual day/month/year fields (auto-advance moves focus for
// them), reveals the hint, and checks the grade. This is a true end-to-end
// smoke test — no synthetic draft injection — proving the UI really works,
// not just that the pure grading/formatting logic is correct (see the
// scenario-by-scenario coverage in test/exercises/date_exercise_test.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/exercises/date_exercise.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'learner types a birthday field-by-field, reveals the hint, and checks correctly',
    (tester) async {
      const item = Item(
        id: 1,
        setId: 1,
        type: 'date',
        prompt: "Mama's birthday",
        answer: '1985-05-14',
        position: 0,
      );

      ExerciseDraft? draft;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: FoxStreakTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: buildDateExercise(
                item: item,
                l10n: AppLocalizationsEn(),
                onStateChanged: (d) => draft = d,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Prompt is shown.
      expect(find.text("Mama's birthday"), findsOneWidget);

      // Type the month: typing 2 digits auto-advances focus to the day field.
      await tester.enterText(
        find.byKey(const Key('dateExerciseMonthField')),
        '05',
      );
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'dateExerciseDay',
      );
      expect(draft!.hasAnswer, isFalse);

      // Type the day: auto-advances to year.
      await tester.enterText(
        find.byKey(const Key('dateExerciseDayField')),
        '14',
      );
      await tester.pumpAndSettle();
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'dateExerciseYear',
      );
      expect(draft!.hasAnswer, isFalse);

      // Reveal the hint before finishing: shows the formatted date and
      // flags hintUsed, mirroring #008's phone reveal-hint.
      await tester.tap(find.byKey(const Key('dateExerciseHintButton')));
      await tester.pump();
      expect(find.text('05/14/1985'), findsOneWidget);
      expect(draft!.hintUsed, isTrue);

      // Type the year: CHECK becomes available.
      await tester.enterText(
        find.byKey(const Key('dateExerciseYearField')),
        '1985',
      );
      await tester.pumpAndSettle();
      expect(draft!.hasAnswer, isTrue);

      // Grading composes the ISO answer and compares it exactly.
      expect(draft!.grade(), isTrue);
      expect(draft!.correctAnswerLabel, '05/14/1985');
    },
  );
}
