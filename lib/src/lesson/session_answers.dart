// Derives the session knowledge that steers multiple-choice distractors
// (issues #120, #126) from the lesson outcomes.

import '../data/database.dart';
import '../exercises/choice_options.dart';
import 'exercise_card.dart';

/// Answers (as [normalizeChoiceAnswer] produces them) of [items] whose
/// latest outcome in [outcomes] (oldest first) is correct. Missed, skipped
/// and unanswered items don't count. In a redo round [LessonState] hands
/// over the earlier rounds' outcomes too, so the first round's correct
/// answers stay included. An answer shared by a correct and a missed item
/// counts as correct.
Set<String> sessionCorrectAnswers({
  required List<Item> items,
  required List<LessonItemOutcome> outcomes,
}) {
  final latest = <int, bool>{
    for (final outcome in outcomes) outcome.itemId: outcome.correct,
  };
  return {
    for (final item in items)
      if (latest[item.id] ?? false) normalizeChoiceAnswer(item.answer),
  };
}
