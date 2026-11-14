// Unit tests for sessionCorrectAnswers (issues #120, #126).

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

  test('no outcomes yields an empty set', () {
    expect(sessionCorrectAnswers(items: items, outcomes: const []), isEmpty);
  });

  test('keeps normalised correct answers only, not missed or skipped', () {
    final result = sessionCorrectAnswers(
      items: items,
      outcomes: [
        _outcome(1, correct: true),
        _outcome(2, correct: false, skipped: true),
        _outcome(3, correct: false),
      ],
    );
    expect(result, {'dog'});
  });

  test('a later outcome of the same item supersedes an earlier one', () {
    expect(
      sessionCorrectAnswers(
        items: items,
        outcomes: [_outcome(1, correct: false), _outcome(1, correct: true)],
      ),
      {'dog'},
    );
    expect(
      sessionCorrectAnswers(
        items: items,
        outcomes: [_outcome(1, correct: true), _outcome(1, correct: false)],
      ),
      isEmpty,
    );
  });

  test('redo round keeps the first round\'s correct answers', () {
    // First round: 1 correct, 2 and 3 missed; redo round so far: 2 missed
    // again, 3 not asked yet.
    final result = sessionCorrectAnswers(
      items: items,
      outcomes: [
        _outcome(1, correct: true),
        _outcome(2, correct: false),
        _outcome(3, correct: false),
        _outcome(2, correct: false),
      ],
    );
    expect(result, {'dog'});
  });

  test('an answer that is both correct and missed counts as correct', () {
    final result = sessionCorrectAnswers(
      items: [_item(1, 'dog'), _item(2, 'Dog')],
      outcomes: [_outcome(1, correct: true), _outcome(2, correct: false)],
    );
    expect(result, {'dog'});
  });
}
