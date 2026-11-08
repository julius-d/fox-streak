// Unit tests for SessionAnswers (issue #120).

import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/data/database.dart';
import 'package:fox_streak_app/src/lesson/exercise_card.dart';
import 'package:fox_streak_app/src/lesson/session_answers.dart';

Item _item(int id, String answer) => Item(
  id: id,
  setId: 1,
  type: 'choice',
  prompt: 'p$id',
  answer: answer,
  hint: '',
  position: id,
);

LessonItemOutcome _outcome(int id, {required bool correct, bool? skipped}) =>
    LessonItemOutcome(itemId: id, correct: correct, skipped: skipped ?? false);

void main() {
  final items = [_item(1, ' Dog '), _item(2, 'cat'), _item(3, 'mouse')];

  test('no outcomes yields empty sets', () {
    final result = SessionAnswers.from(items: items, outcomes: const []);
    expect(result.correct, isEmpty);
    expect(result.missed, isEmpty);
  });

  test('classifies normalised answers by outcome, skips count as missed', () {
    final result = SessionAnswers.from(
      items: items,
      outcomes: [
        _outcome(1, correct: true),
        _outcome(2, correct: false, skipped: true),
      ],
    );
    expect(result.correct, {'dog'});
    expect(result.missed, {'cat'});
  });

  test('a later outcome of the same item supersedes an earlier one', () {
    final result = SessionAnswers.from(
      items: items,
      outcomes: [_outcome(1, correct: false), _outcome(1, correct: true)],
    );
    expect(result.correct, {'dog'});
    expect(result.missed, isEmpty);
  });

  test('an answer that is both correct and missed counts as correct', () {
    final result = SessionAnswers.from(
      items: [_item(1, 'dog'), _item(2, 'Dog')],
      outcomes: [_outcome(1, correct: true), _outcome(2, correct: false)],
    );
    expect(result.correct, {'dog'});
    expect(result.missed, isEmpty);
  });
}
