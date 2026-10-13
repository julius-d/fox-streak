// Widget tests for the multiple-choice exercise card (issue #006; type
// renamed vocab -> choice and grading switched to isCorrect-flag by #026).
//
// Pumps the real `MultipleChoiceCard` widget and drives it with real taps to
// verify the #005 `ExerciseCard` contract: tap-to-select, CHECK gating,
// grading via the selected option's isCorrect flag (never a string
// re-comparison), and that distractor fallback still produces 4 options.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/lesson/multiple_choice_card.dart';

Item _item({
  List<String>? choices,
  String answer = 'dog',
  String prompt = 'Hund',
}) {
  return Item(
    id: 1,
    setId: 1,
    type: 'choice',
    prompt: prompt,
    answer: answer,
    direction: 'deEn',
    choices: choices == null ? null : '["${choices.join('","')}"]',
    hint: '',
    position: 0,
  );
}

class _Harness extends StatelessWidget {
  final Item item;
  final void Function(ExerciseDraft) onDraft;

  const _Harness({required this.item, required this.onDraft});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return MultipleChoiceCard(
              item: item,
              onStateChanged: onDraft,
              l10n: l10n,
            );
          },
        ),
      ),
    );
  }
}

void main() {
  group('MultipleChoiceCard', () {
    testWidgets('renders 4 options (answer + stored distractors)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          item: _item(choices: ['cat', 'mouse', 'bird']),
          onDraft: (_) {},
        ),
      );
      await tester.pump();

      expect(find.text('dog'), findsOneWidget);
      expect(find.text('cat'), findsOneWidget);
      expect(find.text('mouse'), findsOneWidget);
      expect(find.text('bird'), findsOneWidget);
    });

    testWidgets('pads with placeholder distractors when choices are missing', (
      tester,
    ) async {
      await tester.pumpWidget(_Harness(item: _item(), onDraft: (_) {}));
      await tester.pump();

      expect(find.text('dog'), findsOneWidget);
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);
      expect(find.text('Option 3'), findsOneWidget);
    });

    testWidgets('tapping the correct option: hasAnswer true, grade() true', (
      tester,
    ) async {
      ExerciseDraft? draft;
      await tester.pumpWidget(
        _Harness(
          item: _item(choices: ['cat', 'mouse', 'bird']),
          onDraft: (d) => draft = d,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('dog'));
      await tester.pump();

      expect(draft, isNotNull);
      expect(draft!.hasAnswer, isTrue);
      expect(draft!.grade(), isTrue);
      expect(draft!.correctAnswerLabel, 'dog');
      expect(draft!.hintUsed, isFalse);
    });

    testWidgets(
      'tapping a distractor: grade() reads isCorrect, not a string match',
      (tester) async {
        ExerciseDraft? draft;
        await tester.pumpWidget(
          _Harness(
            item: _item(choices: ['cat', 'mouse', 'bird']),
            onDraft: (d) => draft = d,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('cat'));
        await tester.pump();

        expect(draft!.grade(), isFalse);
      },
    );

    testWidgets('options are locked after an answer is selected', (
      tester,
    ) async {
      ExerciseDraft? draft;
      await tester.pumpWidget(
        _Harness(
          item: _item(choices: ['cat', 'mouse', 'bird']),
          onDraft: (d) => draft = d,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('cat'));
      await tester.pump();
      expect(draft!.grade(), isFalse);

      // Tapping a different option post-answer must not change the
      // already-reported (wrong) selection.
      await tester.tap(find.text('dog'));
      await tester.pump();
      expect(draft!.grade(), isFalse);
    });
  });
}
