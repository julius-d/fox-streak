// Derives the session knowledge that steers multiple-choice distractors
// (issue #120) from the lesson outcomes.

import '../data/database.dart';
import '../exercises/choice_options.dart';
import 'exercise_card.dart';

/// Answers (as [normalizeChoiceAnswer] produces them) the learner has
/// answered correctly / missed in this session.
class SessionAnswers {
  final Set<String> correct;
  final Set<String> missed;

  const SessionAnswers({this.correct = const {}, this.missed = const {}});

  /// Classifies each item by its latest outcome in [outcomes] (oldest
  /// first): correct, or missed (incl. skipped). Items without an outcome
  /// are neither — except in a redo round, where [LessonState] hands over
  /// the earlier rounds' outcomes, so still-unanswered missed items count
  /// as missed. An answer shared by a correct and a missed item counts as
  /// correct only.
  factory SessionAnswers.from({
    required List<Item> items,
    required List<LessonItemOutcome> outcomes,
  }) {
    final latest = <int, bool>{
      for (final outcome in outcomes) outcome.itemId: outcome.correct,
    };
    final correct = <String>{};
    final missed = <String>{};
    for (final item in items) {
      final isCorrect = latest[item.id];
      if (isCorrect == null) continue;
      (isCorrect ? correct : missed).add(normalizeChoiceAnswer(item.answer));
    }
    return SessionAnswers(correct: correct, missed: missed.difference(correct));
  }
}
