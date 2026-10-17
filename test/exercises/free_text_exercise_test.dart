// Widget tests for the free-text exercise (issue #007).
//
// Pumps the real `FreeTextExercise` widget (no fakes/mocks) through a thin
// harness that captures the `ExerciseDraft` reported via `onStateChanged`,
// then drives it with real `WidgetTester` text entry / taps to verify the
// #005 `ExerciseCard` contract end to end: hasAnswer gating, grading via
// `gradeText`, reveal-hint wiring, and direction framing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/l10n/app_localizations.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/exercises/free_text_exercise.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';

Item _item({
  String? promptLang,
  String? answerLang,
  String answer = 'Hund',
  String prompt = 'dog',
}) {
  return Item(
    id: 1,
    setId: 1,
    type: 'freeText',
    prompt: prompt,
    answer: answer,
    promptLang: promptLang,
    answerLang: answerLang,
    choices: null,
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
            return buildFreeTextExercise(
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
  group('FreeTextExercise', () {
    testWidgets('hasAnswer is false until text is entered', (tester) async {
      ExerciseDraft? draft;
      await tester.pumpWidget(
        _Harness(item: _item(), onDraft: (d) => draft = d),
      );
      await tester.pump();

      expect(draft, isNotNull);
      expect(draft!.hasAnswer, isFalse);

      await tester.enterText(
        find.byKey(const Key('freeTextAnswerField')),
        'Hund',
      );
      await tester.pump();
      expect(draft!.hasAnswer, isTrue);

      await tester.enterText(
        find.byKey(const Key('freeTextAnswerField')),
        '   ',
      );
      await tester.pump();
      expect(draft!.hasAnswer, isFalse);
    });

    testWidgets(
      'grade() uses gradeText: tolerant case/whitespace, strict umlauts',
      (tester) async {
        ExerciseDraft? draft;
        await tester.pumpWidget(
          _Harness(
            item: _item(answer: 'Mädchen'),
            onDraft: (d) => draft = d,
          ),
        );
        await tester.pump();

        await tester.enterText(
          find.byKey(const Key('freeTextAnswerField')),
          '  MÄDCHEN  ',
        );
        await tester.pump();
        expect(draft!.grade(), isTrue);
        expect(draft!.correctAnswerLabel, 'Mädchen');

        await tester.enterText(
          find.byKey(const Key('freeTextAnswerField')),
          'Madchen',
        );
        await tester.pump();
        expect(draft!.grade(), isFalse);
      },
    );

    testWidgets('autocorrect is off on the answer field', (tester) async {
      await tester.pumpWidget(_Harness(item: _item(), onDraft: (_) {}));
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('freeTextAnswerField')),
      );
      expect(field.autocorrect, isFalse);
    });

    testWidgets(
      'all-digit answers (e.g. math facts, #045) get the numeric keyboard',
      (tester) async {
        await tester.pumpWidget(
          _Harness(
            item: _item(answer: '42'),
            onDraft: (_) {},
          ),
        );
        await tester.pump();

        final field = tester.widget<TextField>(
          find.byKey(const Key('freeTextAnswerField')),
        );
        expect(field.keyboardType, TextInputType.number);
      },
    );

    testWidgets('a non-digit answer keeps the default keyboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          item: _item(answer: 'Hund'),
          onDraft: (_) {},
        ),
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('freeTextAnswerField')),
      );
      expect(field.keyboardType, isNot(TextInputType.number));
    });

    testWidgets(
      'reveal-hint works pre-check (no answer needed) and sets hintLabel',
      (tester) async {
        ExerciseDraft? draft;
        await tester.pumpWidget(
          _Harness(
            item: _item(answer: 'Hund'),
            onDraft: (d) => draft = d,
          ),
        );
        await tester.pump();

        expect(draft!.hasAnswer, isFalse);
        expect(draft!.hintLabel, isNull);
        expect(draft!.hintUsed, isFalse);

        await tester.tap(find.byKey(const Key('freeTextRevealHintButton')));
        await tester.pump();

        expect(draft!.hintLabel, isNotNull);
        expect(draft!.hintLabel, contains('H'));
        expect(draft!.hintUsed, isTrue);
        expect(find.byKey(const Key('freeTextHintLabel')), findsOneWidget);
      },
    );

    testWidgets(
      'reveal-hint uses a full Unicode code point, not a UTF-16 code unit',
      (tester) async {
        // '😀' is a surrogate pair in UTF-16; answer[0] would split it.
        ExerciseDraft? draft;
        await tester.pumpWidget(
          _Harness(
            item: _item(answer: '😀 Hallo'),
            onDraft: (d) => draft = d,
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('freeTextRevealHintButton')));
        await tester.pump();

        expect(draft!.hintLabel, contains('😀'));
      },
    );

    testWidgets('vocab-flavored item shows direction framing (de->en)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          item: _item(promptLang: 'de', answerLang: 'en'),
          onDraft: (_) {},
        ),
      );
      await tester.pump();

      final resolved = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(resolved.exerciseDirectionLabel('German', 'English')),
        findsOneWidget,
      );
    });

    testWidgets('vocab-flavored item shows direction framing (en->de)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          item: _item(promptLang: 'en', answerLang: 'de'),
          onDraft: (_) {},
        ),
      );
      await tester.pump();

      final resolved = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(resolved.exerciseDirectionLabel('English', 'German')),
        findsOneWidget,
      );
    });

    testWidgets(
      'non-vocab item (no language pair) shows no direction framing',
      (tester) async {
        await tester.pumpWidget(
          _Harness(
            item: _item(promptLang: null, answerLang: null),
            onDraft: (_) {},
          ),
        );
        await tester.pump();

        final resolved = await AppLocalizations.delegate.load(
          const Locale('en'),
        );
        expect(
          find.text(resolved.exerciseDirectionLabel('German', 'English')),
          findsNothing,
        );
        expect(
          find.text(resolved.exerciseDirectionLabel('English', 'German')),
          findsNothing,
        );
        expect(find.text('dog'), findsOneWidget);
      },
    );
  });
}
