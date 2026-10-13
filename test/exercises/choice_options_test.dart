// Unit tests for the multiple-choice distractor fallback chain (#006).
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
  String? direction = 'deEn',
  String? choices,
  String type = 'choice',
}) {
  return Item(
    id: id,
    setId: 1,
    type: type,
    prompt: 'prompt',
    answer: answer,
    direction: direction,
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

    test('fills remaining slots from same-set/same-direction items', () {
      final options = buildChoiceOptions(
        item: _item(id: 1, answer: 'dog', direction: 'deEn'),
        otherSetItems: [
          _item(id: 2, answer: 'cat', direction: 'deEn'),
          _item(id: 3, answer: 'mouse', direction: 'deEn'),
          // Excluded: different direction.
          _item(id: 4, answer: 'bird', direction: 'enDe'),
          // Excluded: same item (by id).
          _item(id: 1, answer: 'ignored', direction: 'deEn'),
        ],
        placeholderDistractor: _placeholder,
        random: Random(1),
      );

      final labels = options.map((o) => o.label).toSet();
      expect(labels, {'dog', 'cat', 'mouse', 'Placeholder 1'});
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
        item: _item(answer: 'dog', direction: 'deEn', choices: '["cat"]'),
        otherSetItems: [_item(id: 2, answer: 'mouse', direction: 'deEn')],
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
        item: _item(answer: 'dog', direction: 'deEn', choices: '["cat"]'),
        otherSetItems: [
          _item(id: 2, answer: 'cat', direction: 'deEn'),
          _item(id: 3, answer: 'mouse', direction: 'deEn'),
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
