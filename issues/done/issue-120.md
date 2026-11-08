# Issue 120: Smarter multiple-choice distractor selection

Status: done | Priority: P3 | Type: feature | Refined-at: 2026-11-08 | Completed-at: 2026-11-08

## Goal
Choose distractors that help learning: answers the learner already got right
in this session show up less often, and answers of items they missed show up
first. The fallback chain must still always produce 3 distractors.

Depends on #116 (the redo round must keep the full distractor pool).
Related: #006 (choice options), #078 (redo missed items).

## Problem
`buildChoiceOptions` (`lib/src/exercises/choice_options.dart`) fills the
fallback distractors from other items of the set in uniformly random order.
It has no knowledge of the session, so an answer the learner just picked
correctly is as likely to appear as a distractor on the next card as any
other. Nothing steers distractors toward what the learner confuses, not even
in redo rounds.

## Approach
Add optional parameters to `buildChoiceOptions`, e.g.
`Set<String> correctAnswers` and `Set<String> missedAnswers` (normalised
trimmed, lowercase answers). `lesson_screen.dart` derives them from
`LessonState.outcomes` plus the queue/source items and passes them in. The
function stays pure.

Fallback pool (step 2 of the existing chain) is split into 2 tiers and filled
tier 1 first, then tier 2, so the number of distractors never drops:

1. **Preferred:** answers not answered correctly this session. Answers of
   missed items (incl. skipped) come first, then the rest, shuffled.
2. **Fallback:** answers already answered correctly this session, shuffled.

Unchanged: authored `item.choices` still take priority over the pool, the
correct answer is always excluded, duplicates are dropped, placeholders fill
any remaining slot. Applies to normal lessons and redo rounds alike. In a
redo round the missed items' answers are therefore preferred distractors and
the round-1 correct answers are used last.

## Acceptance Criteria

- An answer the learner already answered correctly this session is not used
  as a distractor while enough tier-1 candidates exist.
- When tier 1 has fewer than 3 candidates, tier 2 fills the remaining slots,
  so there are still 3 distractors whenever the pool allows it.
- Answers of missed or skipped items are chosen before other tier-1 answers.
- Redo rounds apply the same rules, so missed items' answers are preferred
  and the first round's correct answers are used last.
- Authored `item.choices` still take priority, and the correct answer is
  never offered as a distractor.
- Without session data (parameters omitted or empty) behaviour is identical
  to today (uniform shuffle), so existing callers and tests keep working.
- `lesson_screen.dart` derives the sets from `LessonState.outcomes` and passes
  them to the choice card.
- Unit tests in `choice_options_test.dart` with a seeded `Random`: tier
  order, tier-2 fallback when tier 1 is too small, missed-first ordering,
  authored choices unaffected, no-session-data equals old behaviour.
- Widget/shell test: after a correct card, the next choice card does not show
  that card's answer as a distractor (given a large enough set).
- Update the distractor fallback description in
  `docs/question-set-format.md` (around the `choices` field) to mention the
  session-aware ordering.

## Out of scope
- Lifetime history from the `attempts` table (possible follow-up).
- Similarity-based distractors (length, first letter, etc.).
- Fallback behaviour for sets too small to supply enough distractors.

## Summary
- `buildChoiceOptions` takes `correctAnswers`/`missedAnswers` (normalised via `normalizeChoiceAnswer`); pool order: missed, neutral, already-correct.
- `LessonState.previousOutcomes` carries earlier rounds through "Redo missed items"; `SessionAnswers.from` derives the sets (latest outcome per item wins), `lesson_screen` passes them to the choice card.
- Renumbered from 117 (number clash with the wheel-of-fortune issue). No new UI, so no integration test/screenshots.

## Code review
- Test imports `package:.../test/data/test_helpers.dart` (claimed uncompilable).
  Not fixed: false positive, same import as `lesson_shell_test.dart`; tests pass.
- "No session data" test compared the new code with itself.
  Fixed: now compares against the pre-#120 shuffle algorithm.
- `SessionAnswers.from` ran on every `build()`.
  Fixed: only computed in the `choice` branch.
- `copyWith` can't change `previousOutcomes`.
  Not fixed: only `_startSession` sets it; no other caller needs it.
- Outcomes of items outside `sourceItems` are ignored.
  Not fixed: redo items are always a subset of `sourceItems`.
- `addIfNew` duplicated the normalisation.
  Fixed: uses `normalizeChoiceAnswer`.
