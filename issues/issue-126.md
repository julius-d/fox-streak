# Issue 126: Multiple-choice distractors give away the answer after a few misses

Status: open | Priority: P3 | Type: enhancement | Refined-at: 2026-11-14

## Goal

Multiple-choice options must not hint at the right answer. After a few
missed cards, the learner should still have to know the answer, not spot
the one option that changed.

Related: #120 (session-aware distractor selection, which introduced this),
#006 (choice options), #078 / #116 (redo missed items).

## Problem

Since #120, answers of missed items are always picked first as distractors.
Once a learner has missed 3 items in a set, every later card shows those same
3 wrong answers plus the correct one. The only option that changes from card
to card is the correct answer, so it is easy to guess.

## Desired behavior

- Answers of missed (or skipped) items get **no priority** as distractors.
  Missed answers and answers of items not asked yet form one group. Distractors
  are drawn from it at random, with equal chances for every answer in it.
- Answers the learner already answered correctly this session stay
  deprioritized: they are only used when that group has fewer than 3
  candidates (unchanged from #120).
- There are still always 3 distractors whenever the set allows it.
- Same rules in normal lessons and in "Redo missed items" rounds; no special
  case for redo rounds.
- Unchanged: authored choices of an item still take priority, the correct
  answer is never offered as a distractor, and there are no duplicate options.
- No visible UI change and no new copy.

This supersedes #120's rule "answers of missed or skipped items are chosen
before other answers". #120's other rules stay.

## Out of scope

- **Known limitation:** near the end of a session, when few items are left
  unasked, the missed answers can again make up most or all distractors
  (correct answers are still used last). Accepted for now. A possible
  follow-up: answers used as distractors on the previous card are used last
  on the next card.
- Weighted randomness between groups (discussed; not done).
- Small sets where the pool can't supply enough distractors (placeholder
  fallback unchanged).
- Changes to the question format (no `docs/` update needed).

## Acceptance Criteria

- Missed and not-yet-asked answers are one group with equal chances. Test
  with a seeded `Random`: a pool of 3 missed and at least 3 unasked answers
  gives distractors that include unasked answers across seeds, not just the
  missed ones.
- Already-correct answers are only used as distractors when the group of
  missed + not-yet-asked candidates is smaller than 3. If it is smaller, they
  fill the remaining slots, so there are still 3 distractors.
- Redo rounds follow the same rules.
- Authored choices, correct-answer exclusion and de-duplication behave as
  before. Without session data, behaviour is still a plain uniform shuffle.
- The test for #120's missed-first ordering is replaced by the new rule.
  #120's widget test still passes: after a correct card, the next card does
  not show that answer as a distractor.
- Dead code is removed: the code no longer needs to know which items were
  missed. That input to distractor selection, and the code that derives and
  passes it, are removed.
- `flutter analyze`, `dart format` and `flutter test` are clean.
