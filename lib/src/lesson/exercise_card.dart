// Exercise card contract + types (issue #005).
//
// This file defines the contract that all exercise cards (#006–#009) must
// implement. The shell (LessonController + LessonScreen) owns the session
// lifecycle; each card only reports its draft state and grades on demand.
//
// Prose contract (also see issue #005 Decisions):
//
//   // Card reports draft state; shell calls grade() only on CHECK.
//   // correctAnswerLabel feeds the wrong-banner; hintLabel (optional,
//   // e.g. #007 first-letter hint) shows alongside it.
//   onStateChanged(ExerciseDraft(
//     hasAnswer: true,
//     grade: () => typed == item.answer, // card-owned grading
//     correctAnswerLabel: item.answer,   // date cards: formatDateForDisplay
//     hintLabel: null,
//   ));
//
// The shell enables CHECK iff hasAnswer. After CHECK:
//   - Shell calls grade() once and records the outcome.
//   - Shell shows FoxFeedbackBanner (success/error) with correctAnswerLabel.
//   - Button flips to CONTINUE; Skip is hidden/disabled.
//   - CONTINUE advances to next item (or result screen).
//   - Quit-X is always available (pre- and post-check).
//
// No in-card retry; one shot per item. Cards do not write attempts or
// advance the queue — the shell does that.

import 'package:flutter/material.dart';
import 'package:fox_streak_app/src/data/database.dart';

/// Draft state reported by an exercise card while the user is answering.
///
/// [hasAnswer] — whether the user has provided an answer (enables CHECK).
/// [grade] — synchronous grading function called by the shell exactly once on CHECK.
/// [correctAnswerLabel] — human-readable correct answer shown in the error banner.
///   For date items this must be a formatted display string (e.g. via
///   formatDateForDisplay from #004), never a raw ISO string.
/// [hintLabel] — optional hint shown alongside the correct answer in the error
///   banner (e.g. first-letter hint from #007). Null if not applicable.
class ExerciseDraft {
  final bool hasAnswer;
  final bool Function() grade;
  final String correctAnswerLabel;
  final String? hintLabel;

  const ExerciseDraft({
    required this.hasAnswer,
    required this.grade,
    required this.correctAnswerLabel,
    this.hintLabel,
  });
}

/// Widget signature that all exercise cards (#006–#009) must match.
///
/// The shell instantiates the appropriate card based on [item.type]
/// (vocab/phone/date) and passes the [item] plus an [onStateChanged] callback.
/// Cards must call [onStateChanged] whenever their draft state changes so the
/// shell can enable/disable CHECK and capture the grade function.
///
/// Example (pseudo-implementation for a vocab choice card):
/// ```dart
/// class VocabChoiceCard extends StatelessWidget {
///   final Item item;
///   final void Function(ExerciseDraft) onStateChanged;
///
///   const VocabChoiceCard({super.key, required this.item, required this.onStateChanged});
///
///   @override
///   Widget build(BuildContext context) {
///     String? selected;
///     return Column(
///       children: [
///         Text(item.prompt),
///         ..._buildChoices(item),
///       ],
///     );
///   }
///
///   void _onChoiceSelected(String choice) {
///     selected = choice;
///     onStateChanged(ExerciseDraft(
///       hasAnswer: true,
///       grade: () => selected == item.answer,
///       correctAnswerLabel: item.answer,
///       hintLabel: null,
///     ));
///   }
/// }
/// ```
typedef ExerciseCardBuilder = Widget Function({
  required Item item,
  required void Function(ExerciseDraft draft) onStateChanged,
});

/// Per-item outcome recorded by the shell after CHECK or SKIP.
///
/// [itemId] — the item that was answered.
/// [correct] — true if the user's answer was correct.
/// [skipped] — true if the user pressed SKIP (counts as wrong).
/// [firstTry] — always true in v1 (reserved for #010 second-try XP tier).
/// [hintUsed] — always false in v1 (reserved for #008 reveal-hint → #010 5-XP tier).
class LessonItemOutcome {
  final int itemId;
  final bool correct;
  final bool skipped;
  final bool firstTry;
  final bool hintUsed;

  const LessonItemOutcome({
    required this.itemId,
    required this.correct,
    required this.skipped,
    this.firstTry = true,
    this.hintUsed = false,
  });

  LessonItemOutcome copyWith({
    int? itemId,
    bool? correct,
    bool? skipped,
    bool? firstTry,
    bool? hintUsed,
  }) {
    return LessonItemOutcome(
      itemId: itemId ?? this.itemId,
      correct: correct ?? this.correct,
      skipped: skipped ?? this.skipped,
      firstTry: firstTry ?? this.firstTry,
      hintUsed: hintUsed ?? this.hintUsed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonItemOutcome &&
          other.itemId == itemId &&
          other.correct == correct &&
          other.skipped == skipped &&
          other.firstTry == firstTry &&
          other.hintUsed == hintUsed);

  @override
  int get hashCode => Object.hash(itemId, correct, skipped, firstTry, hintUsed);

  @override
  String toString() =>
      'LessonItemOutcome(itemId: $itemId, correct: $correct, skipped: $skipped, firstTry: $firstTry, hintUsed: $hintUsed)';
}

/// Phase of the current question in the lesson flow.
enum LessonPhase {
  /// User is answering; CHECK is enabled when hasAnswer.
  answering,

  /// Feedback banner is shown; CONTINUE advances.
  feedback,

  /// All items processed; result screen is shown.
  done,
}

/// Value object representing the completed lesson result.
///
/// Exposed via a Riverpod provider AND as the Navigator return value so
/// #010 (XP) and #011 (streak) can consume it.
class LessonResult {
  final int setId;
  final List<int> itemIds;
  final List<LessonItemOutcome> outcomes;
  final int correctCount;
  final int scorePct; // 0..100

  const LessonResult({
    required this.setId,
    required this.itemIds,
    required this.outcomes,
    required this.correctCount,
    required this.scorePct,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonResult &&
          other.setId == setId &&
          other.itemIds.length == itemIds.length &&
          other.itemIds.every((id) => itemIds.contains(id)) &&
          other.outcomes.length == outcomes.length &&
          other.outcomes.every((o) => outcomes.contains(o)) &&
          other.correctCount == correctCount &&
          other.scorePct == scorePct);

  @override
  int get hashCode =>
      Object.hash(setId, itemIds, outcomes, correctCount, scorePct);

  @override
  String toString() =>
      'LessonResult(setId: $setId, correct: $correctCount/${itemIds.length}, score: $scorePct%)';
}
