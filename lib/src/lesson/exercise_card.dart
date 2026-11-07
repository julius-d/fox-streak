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
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Draft state reported by an exercise card while the user is answering.
///
/// [hasAnswer] — whether the user has provided an answer (enables CHECK).
/// [grade] — synchronous grading function called by the shell exactly once on CHECK.
/// [correctAnswerLabel] — human-readable correct answer shown in the error banner.
///   For date items this must be a formatted display string (e.g. via
///   formatDateForDisplay from #004), never a raw ISO string.
/// [hintLabel] — optional hint shown alongside the correct answer in the error
///   banner (e.g. first-letter hint from #007). Null if not applicable.
/// [hintUsed] — whether the card's reveal-hint affordance (#008 phone,
///   #009 date) was used for this item; the shell copies it onto the
///   recorded [LessonItemOutcome] for the future #010 5-XP tier.
class ExerciseDraft {
  final bool hasAnswer;
  final bool Function() grade;
  final String correctAnswerLabel;
  final String? hintLabel;
  final bool hintUsed;

  const ExerciseDraft({
    required this.hasAnswer,
    required this.grade,
    required this.correctAnswerLabel,
    this.hintLabel,
    this.hintUsed = false,
  });
}

/// Minimum height for a card's scrollable content so a short answer (a
/// masked phone display, the multiple-choice options) still centers
/// vertically in the space left by the lesson shell's app bar + bottom
/// button, instead of hugging the top. Shared by #008's dial pad and the
/// multiple-choice card (`IntrinsicHeight` + `ConstrainedBox(minHeight:
/// ...)`). The date and free-text cards (#009/#006) stopped using this for
/// #092: their input anchors to the top instead of centering, so opening
/// the keyboard doesn't push it further up.
double exerciseCardMinHeight(BuildContext context) {
  return MediaQuery.of(context).size.height -
      MediaQuery.of(context).padding.top -
      MediaQuery.of(context).padding.bottom -
      kToolbarHeight -
      FoxButtonMetrics.minSize -
      FoxSpacing.xxl * 2;
}

/// Whether [item] has a `base64`/`url` image — the kinds that can grow
/// into spare space (#112); an `emoji` keeps its small fixed box.
bool hasPhotoImage(Item item) =>
    item.imageContent != null &&
    (item.imageType == 'base64' || item.imageType == 'url');

/// Builds [item]'s shared prompt-side image block (issue #014; copyright
/// caption + tap-to-expand added by #094), already including its own
/// trailing spacer — or an empty, zero-size [SizedBox.shrink] when [item]
/// has none, so every exercise card (#006–#009) can place this
/// unconditionally above its prompt text without each repeating its own
/// null-check + spacer.
///
/// Uses `FoxQuestionImage` (not the small, square, non-interactive
/// `FoxItemImage` used for set-detail/library thumbnails) — the question
/// context gets more room and shows the image at its natural aspect ratio.
/// [l10n] resolves the tap-to-expand a11y hint (#094) — kit widgets never
/// resolve l10n themselves.
///
/// With [expandToFill] (#112) a `base64`/`url` image instead fills the
/// bounded height its parent gives it (floor: the usual 240dp) — see
/// [hasPhotoImage]; callers place the result in an `Expanded`.
Widget buildItemImage(
  Item item, {
  required AppLocalizations l10n,
  bool expandToFill = false,
}) {
  final type = item.imageType;
  final content = item.imageContent;
  if (type == null || content == null) return const SizedBox.shrink();
  final fills = expandToFill && hasPhotoImage(item);
  final image = FoxQuestionImage(
    imageType: type,
    imageContent: content,
    semanticLabel: item.prompt,
    imageCopyright: item.imageCopyright,
    expandHint: l10n.fullScreenImageViewHint,
    closeLabel: l10n.fullScreenImageCloseLabel,
    imageLoadFailedMessage: l10n.questionImageLoadFailed,
    retryButtonLabel: l10n.questionImageRetryButton,
    expandToFill: fills,
  );
  return Column(
    mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
    children: [
      if (fills) Expanded(child: image) else image,
      const SizedBox(height: FoxSpacing.md),
    ],
  );
}

/// Widget signature that all exercise cards (#006–#009) must match.
///
/// The shell instantiates the appropriate card based on [item.type]
/// (choice/freeText/phone/date — #026 split `choice`/`freeText` out of the
/// original `vocab` type) and passes the [item] plus an [onStateChanged]
/// callback. Cards must call [onStateChanged] whenever their draft state
/// changes so the shell can enable/disable CHECK and capture the grade
/// function.
///
/// Example (pseudo-implementation for a multiple-choice card):
/// ```dart
/// class ChoiceCard extends StatelessWidget {
///   final Item item;
///   final void Function(ExerciseDraft) onStateChanged;
///
///   const ChoiceCard({super.key, required this.item, required this.onStateChanged});
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
/// [hintUsed] — true if the card's reveal-hint was used (#008 phone, #009
///   date) before CHECK or SKIP, copied from the card's current
///   [ExerciseDraft.hintUsed] at that moment. Reserved for #010's 5-XP tier.
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
