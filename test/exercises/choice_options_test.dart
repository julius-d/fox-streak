// Unit tests for the multiple-choice distractor fallback chain (#006; #022
// generalized the fallback filter from `direction` to `type` +
// `promptLang`/`answerLang`).
//
// buildChoiceOptions has no widget/BuildContext dependency, so these tests
// drive it directly rather than through a pumped widget.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/exercises/choice_options.dart';

Item _item({
  int id = 1,
  String answer = 'dog',
  String? promptLang = 'de',
  String? answerLang = 'en',
  String? choices,
  String type = 'choice',
}) {
  return Item(
    id: id,
    setId: 1,
    type: type,
    prompt: 'prompt',
    answer: answer,
    promptLang: promptLang,
    answerLang: answerLang,
    choices: choices,
    hint: '',
    position: 0,
  );
}

String _placeholder(int index) => 'Placeholder $index';

void main() {
  group('buildChoiceOptions', () {
    test('uses stored item.choices as distractors, blank-tolerant', () {
      final options = buildChoiceOptions(
        item: _item(choices: '["cat","","mouse"," "]'),
        otherSetItems: const [],
        placeholderDistractor: _placeholder,
        random: Random(1),
      );

      final labels = options.map((o) => o.label).toSet();
      expect(labels, {'dog', 'cat', 'mouse', 'Placeholder 1'});
      expect(options.length, 4);
      expect(options.where((o) => o.isCorrect).single.label, 'dog');
    });

    test('fills remaining slots from same-set/same-language-pair items', () {
      final options = buildChoiceOptions(
        item: _item(id: 1, answer: 'dog', promptLang: 'de', answerLang: 'en'),
        otherSetItems: [
          _item(id: 2, answer: 'cat', promptLang: 'de', answerLang: 'en'),
          _item(id: 3, answer: 'mouse', promptLang: 'de', answerLang: 'en'),
          // Excluded: different language pair.
          _item(id: 4, answer: 'bird', promptLang: 'en', answerLang: 'de'),
          // Excluded: same item (by id).
          _item(id: 1, answer: 'ignored', promptLang: 'de', answerLang: 'en'),
        ],
        placeholderDistractor: _placeholder,
        random: Random(1),
      );

      final labels = options.map((o) => o.label).toSet();
      expect(labels, {'dog', 'cat', 'mouse', 'Placeholder 1'});
    });

    test('excludes same-set items of a different type even with no language '
        'pair (#022: non-vocab choice vs. phone/date, both null/null)', () {
      final options = buildChoiceOptions(
        item: _item(id: 1, answer: 'Kiel', promptLang: null, answerLang: null),
        otherSetItems: [
          _item(id: 2, answer: 'Hamburg', promptLang: null, answerLang: null),
          const Item(
            id: 3,
            setId: 1,
            type: 'phone',
            prompt: 'Mama',
            answer: '0171',
            promptLang: null,
            answerLang: null,
            choices: null,
            hint: '',
            position: 0,
          ),
        ],
        placeholderDistractor: _placeholder,
        random: Random(1),
      );

      final labels = options.map((o) => o.label).toSet();
      expect(labels, {'Kiel', 'Hamburg', 'Placeholder 1', 'Placeholder 2'});
    });

    test('falls back to placeholders when no choices or set items', () {
      final options = buildChoiceOptions(
        item: _item(choices: null),
        otherSetItems: const [],
        placeholderDistractor: _placeholder,
        random: Random(1),
      );

      final labels = options.map((o) => o.label).toSet();
      expect(labels, {
        'dog',
        'Placeholder 1',
        'Placeholder 2',
        'Placeholder 3',
      });
    });

    test('mixes choices, same-set fallback, and placeholders', () {
      final options = buildChoiceOptions(
        item: _item(
          answer: 'dog',
          promptLang: 'de',
          answerLang: 'en',
          choices: '["cat"]',
        ),
        otherSetItems: [
          _item(id: 2, answer: 'mouse', promptLang: 'de', answerLang: 'en'),
        ],
        placeholderDistractor: _placeholder,
        random: Random(1),
      );

      final labels = options.map((o) => o.label).toSet();
      expect(labels, {'dog', 'cat', 'mouse', 'Placeholder 1'});
    });

    test(
      'never duplicates the correct answer (case/whitespace-insensitive)',
      () {
        final options = buildChoiceOptions(
          item: _item(answer: 'dog', choices: '[" Dog ","cat","mouse","bird"]'),
          otherSetItems: const [],
          placeholderDistractor: _placeholder,
          random: Random(1),
        );

        expect(options.where((o) => o.label.toLowerCase() == 'dog').length, 1);
        expect(options.length, 4);
        final labels = options.map((o) => o.label).toSet();
        expect(labels, {'dog', 'cat', 'mouse', 'bird'});
      },
    );

    test('excludes duplicate same-set answers already picked', () {
      final options = buildChoiceOptions(
        item: _item(
          answer: 'dog',
          promptLang: 'de',
          answerLang: 'en',
          choices: '["cat"]',
        ),
        otherSetItems: [
          _item(id: 2, answer: 'cat', promptLang: 'de', answerLang: 'en'),
          _item(id: 3, answer: 'mouse', promptLang: 'de', answerLang: 'en'),
        ],
        placeholderDistractor: _placeholder,
        random: Random(1),
      );

      final labels = options.map((o) => o.label).toList();
      expect(labels.toSet().length, 4); // No duplicates.
      expect(labels.contains('mouse'), isTrue);
    });

    test('builds exactly 4 options even with an empty pool', () {
      final options = buildChoiceOptions(
        item: _item(),
        otherSetItems: const [],
        placeholderDistractor: _placeholder,
        random: Random(1),
      );

      expect(options.length, 4);
      expect(options.where((o) => o.isCorrect).length, 1);
    });

    test('shuffles deterministically given the same seeded Random', () {
      final a = buildChoiceOptions(
        item: _item(choices: '["cat","mouse","bird"]'),
        otherSetItems: const [],
        placeholderDistractor: _placeholder,
        random: Random(42),
      );
      final b = buildChoiceOptions(
        item: _item(choices: '["cat","mouse","bird"]'),
        otherSetItems: const [],
        placeholderDistractor: _placeholder,
        random: Random(42),
      );

      expect(a.map((o) => o.label).toList(), b.map((o) => o.label).toList());
    });
  });
}
