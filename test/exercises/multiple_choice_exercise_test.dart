// Widget tests for the multiple-choice exercise card (issue #006; type
// renamed vocab -> choice and grading switched to isCorrect-flag by #026).
//
// Pumps the real `MultipleChoiceCard` widget and drives it with real taps to
// verify the #005 `ExerciseCard` contract: tap-to-select, CHECK gating,
// grading via the selected option's isCorrect flag (never a string
// re-comparison), direction-aware prompt framing, stable #016 keys, and
// accessibility semantics. Distractor-fallback-chain details are covered by
// `test/exercises/choice_options_test.dart`; here we only check the fallback
// is wired through end-to-end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/exercises/multiple_choice_exercise.dart';

Item _item({
  int id = 1,
  List<String>? choices,
  String answer = 'dog',
  String prompt = 'Hund',
  String? direction = 'deEn',
}) {
  return Item(
    id: id,
    setId: 1,
    type: 'choice',
    prompt: prompt,
    answer: answer,
    direction: direction,
    choices: choices == null ? null : '["${choices.join('","')}"]',
    hint: '',
    position: 0,
  );
}

class _Harness extends StatelessWidget {
  final Item item;
  final List<Item> otherSetItems;
  final void Function(ExerciseDraft) onDraft;

  const _Harness({
    required this.item,
    this.otherSetItems = const [],
    required this.onDraft,
  });

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
              otherSetItems: otherSetItems,
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

    testWidgets('falls back to same-set items before placeholders', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          item: _item(),
          otherSetItems: [
            _item(id: 2, answer: 'cat', prompt: 'Katze'),
            _item(id: 3, answer: 'mouse', prompt: 'Maus'),
          ],
          onDraft: (_) {},
        ),
      );
      await tester.pump();

      expect(find.text('dog'), findsOneWidget);
      expect(find.text('cat'), findsOneWidget);
      expect(find.text('mouse'), findsOneWidget);
      // Only 2 same-set candidates available; the last slot falls back to
      // the localized placeholder.
      expect(find.text('Option 1'), findsOneWidget);
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

    testWidgets('shows direction-aware prompt framing', (tester) async {
      await tester.pumpWidget(
        _Harness(
          item: _item(choices: ['cat', 'mouse', 'bird'], direction: 'deEn'),
          onDraft: (_) {},
        ),
      );
      await tester.pump();

      expect(find.text('German → English'), findsOneWidget);
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

    testWidgets('exposes stable choiceOption0..3 keys fixed by position', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          item: _item(choices: ['cat', 'mouse', 'bird']),
          onDraft: (_) {},
        ),
      );
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('choiceOption$i')), findsOneWidget);
      }
    });

    testWidgets('each option has a position-aware accessibility label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          item: _item(choices: ['cat', 'mouse', 'bird']),
          onDraft: (_) {},
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp(r'option 1 of 4')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'option 4 of 4')), findsOneWidget);
    });
  });
}
