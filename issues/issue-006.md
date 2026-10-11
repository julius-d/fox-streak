# Issue 006: Vocab exercise — multiple choice

Status: open | Priority: P0 | Type: feature

## Goal
Duolingo-style 1-of-4 choice for DE<->EN vocab.

## Acceptance criteria
- [ ] Shows prompt word + 4 tappable option cards
- [ ] Distractors: from same set, else auto-generated placeholder; never duplicate correct answer
- [ ] Tap selects, CHECK grades; wrong shows correct answer
- [ ] Case/whitespace-insensitive grading, umlauts must match exactly (ä ≠ a)

## Tasks
1. `MultipleChoiceCard` widget
2. Distractor picker: same direction, random, exclude current
3. Accessibility: large text, TalkBack labels

## Follow-up (from #005 review 2026-10-11)
- Implements the #005 `ExerciseCard` contract (`ExerciseDraft(hasAnswer, grade(), correctAnswerLabel, hintLabel?)` + `FakeExerciseCard` example); shell calls `grade()` on CHECK, enables CHECK iff `hasAnswer`.
- Owns card-internal stable keys for #016 (option cards); shell keys (`checkButton`, `lessonFeedbackBanner`) stay in #005.
