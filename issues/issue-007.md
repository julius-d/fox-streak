# Issue 007: Vocab exercise — free text input

Status: open | Priority: P0 | Type: feature

## Goal
Type-the-translation mode for DE<->EN.

## Acceptance criteria
- [ ] TextField with autocorrect OFF, CHECK enabled only when non-empty
- [ ] Tolerant grading: trim, ignore case, accept minor punctuation; umlaut-strict
- [ ] On wrong: show expected answer + hint (first letter)
- [ ] EN->DE and DE->EN both work, keyboard locale hint shown

## Tasks
1. `FreeTextExercise` widget
2. `gradeText(expected, actual)` pure function + unit tests (umlauts, ß, case)
3. Decide ß/ss policy and document (suggest: accept both, store canonical)

## Follow-up (from #005 review 2026-10-11)
- Implements the #005 `ExerciseCard` contract; `gradeText` is the card's `grade()` body, `correctAnswerLabel` = expected answer, `hintLabel` = first-letter hint.
- Owns card-internal stable keys for #016 (text field).
