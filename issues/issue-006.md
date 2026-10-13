# Issue 006: Vocab exercise — multiple choice

Status: done | Priority: P0 | Type: feature | Refined-at: 2026-10-12 | Completed-at: 2026-10-13

## Goal
Duolingo-style 1-of-4 choice for DE<->EN vocab.

## Decisions (2026-10-12, with repo owner)
- **Type split (shared with #007, supersedes #002's `vocab`):** `items.type` splits into `choice` (this issue, multiple-choice) and `freeText` (#007). This issue specifies the `choice` type's contract and card only; the actual schema migration (#002: version bump + migration test renaming existing `vocab` rows) and #005's dispatch update (routing `item.type == 'choice'` here) are **not implemented here** — a shared pending follow-up pass, same deferral #007 already flagged (see Out of scope). Until that lands, this card can't be reached from the live lesson shell.
- `direction` stays **required** for `choice` items (every choice item is a vocab translation by definition) — unlike #007's `freeText`, there is no generified non-vocab use for this type.
- Distractor source & fallback (priority order, always excluding the correct answer, never fewer than 3 distractors): (1) stored `item.choices` (from #004's editor, blank-tolerant, drop empty strings); (2) fill remaining slots by randomly picking other items' `answer` from the same set + same `direction` (exclude current item, exclude exact-match dupes of the correct answer); (3) fill any still-empty slots with a generic localized placeholder distractor string. Options (3 distractors + 1 correct) are built once per item and shuffled once — never reshuffled on rebuild/rotation.
- Grading: **no string comparison.** Each built option carries an `isCorrect` flag assigned at build time; `grade()` just reads the selected option's flag. (The original "case/whitespace-insensitive, umlauts exact" AC was free-text wording copied in by mistake — dropped, since nothing is typed here.)
- Reveal-hint: **omitted** for this type (the correct answer is already visible among the 4 options, so a hint would be meaningless). `hintUsed` stays always `false`, unlike #007/#008/#009's eye-icon pattern.

## Acceptance criteria
- [x] Shows prompt (direction-aware framing, DE→EN / EN→DE, mirrors #007) + 4 tappable option cards from `buildChoiceOptions` (3 distractors + 1 correct, shuffled once per item)
- [x] Distractor fallback chain per Decisions above; never duplicates the correct answer, never fewer than 4 total options
- [x] Tap selects/reselects pre-check; CHECK enabled once a selection exists (`hasAnswer`); grading reads the selected option's `isCorrect` flag, never a string re-comparison
- [x] Wrong shows `correctAnswerLabel = item.answer` in the feedback banner (#005 contract); option taps locked after CHECK
- [x] No reveal-hint; `hintUsed` always `false`
- [x] Accessibility: each option has a screen-reader label (text + position, e.g. "Option 2 of 4"), min 48dp targets, large/bold text via kit type roles
- [x] Follows #015: kit tokens only, no ad-hoc styling, all strings via `lib/l10n` arb params (DE + EN)

## Tasks
1. `MultipleChoiceCard` widget (`lib/src/exercises/multiple_choice_exercise.dart`) implementing the #005 `ExerciseCard` contract: builds options once per item, renders prompt + 4 cards, reports `ExerciseDraft(hasAnswer, grade: () => selected!.isCorrect, correctAnswerLabel: item.answer, hintLabel: null)`.
2. `buildChoiceOptions(item, otherSetItems, {Random?})` pure function (new `lib/src/exercises/choice_options.dart` or `validation.dart`): parses `item.choices`, applies the 3-step fallback, shuffles, returns `List<ChoiceOption{label, isCorrect}>`; unit tests per fallback source + duplicate-exclusion + insufficient-pool case.
3. Tap-select UI: kit-styled option cards (reuse #015 tokens), selected-state styling, locked after CHECK.
4. Accessibility: per-option screen-reader label + position announcement.
5. l10n: arb keys for direction-aware prompt framing (reuse #007 wording where identical) + placeholder distractor string (DE/EN).
6. Stable keys for #016: `choiceOption0`..`choiceOption3` (fixed by rendered position, not content).
7. Tests (`test/exercises/multiple_choice_exercise_test.dart`): distractor fallback chain (choices-only / same-set-fill / placeholder-fill / mixed), shuffle stable across rebuild, grading via `isCorrect` flag, direction-aware prompt both directions, CHECK disabled until selection, input locked post-check, accessibility semantics present.

## Out of scope
- The actual #002 schema migration (`vocab` → `choice`/`freeText`, version bump + migration test) — shared with #007, not implemented here.
- #005's shell dispatch update (routing `item.type == 'choice'` to this card) — separate follow-up pass, blocked on the migration above.
- Reveal-hint eye-icon — not applicable to this type (see Decisions).
- XP math (#010), streak (#011).

## Dependencies
- Builds on #002 (`choices` JSON array, `direction` required for vocab-flavored items) and #004 ("editor provides 3 optional distractor fields... blank-tolerant; lesson-time fallback (same-set pick, placeholder) is owned by #006" — this issue implements that fallback).
- Implements the #005 `ExerciseCard` contract (`ExerciseDraft(hasAnswer, grade(), correctAnswerLabel, hintLabel?)`); `hintLabel`/`hintUsed` unused (always `null`/`false`).
- Shares the pending `vocab`→`choice`/`freeText` type-split migration with #007 — not implemented in this issue (see Out of scope).
- Follows #015 (kit reuse).

## Follow-up (from #005 review 2026-10-11, updated 2026-10-12)
- Implements the #005 `ExerciseCard` contract (`ExerciseDraft(hasAnswer, grade(), correctAnswerLabel, hintLabel?)` + `FakeExerciseCard` example); shell calls `grade()` on CHECK, enables CHECK iff `hasAnswer`.
- Owns card-internal stable keys for #016 (option cards: `choiceOption0`..`choiceOption3`); shell keys (`checkButton`, `lessonFeedbackBanner`) stay in #005.
- **New (2026-10-12): item-type generification.** This issue now specifies the `choice` item type (supersedes vocab's multiple-choice half of #002's `vocab|phone|date` enum, coordinated with #007's `freeText`). #002 (migration) and #005 (dispatch) still need their own follow-up refinement before this lands end-to-end — intentionally deferred, shared with #007's same note.

## Verify
```powershell
flutter analyze        # must be clean (includes riverpod_lint)
dart format --output=none --set-exit-if-changed .  # must be clean
flutter test           # new multiple-choice exercise tests + all existing green
```

## Summary (2026-10-13)
- #026 had already wired `item.type == 'choice'` to a live card with `isCorrect`-flag grading, but it didn't match this issue's refined spec: moved it to `lib/src/exercises/multiple_choice_exercise.dart` (consistent with sibling cards #007–#009), extracted the pure fallback chain into `lib/src/exercises/choice_options.dart` (`buildChoiceOptions`), and added the missing pieces: same-set/same-direction fallback tier, direction-aware prompt framing, position-aware a11y labels, l10n'd placeholder distractors (`exerciseChoicePlaceholderOption`/`exerciseChoiceOptionSemanticLabel`), and stable `choiceOption0..3` keys.
- `lesson_screen.dart` now threads `state.sourceItems` through to the choice card as the same-set fallback pool.
- Guarded the same-set fallback with `item.direction != null` — defensive against malformed data and what surfaced a pre-existing test fixture gap (`setupTestItems` creates items with `direction: null`), fixed by excluding null-direction items from matching each other.
- New tests: `test/exercises/choice_options_test.dart` (pure fallback-chain unit tests), rewrote `test/exercises/multiple_choice_exercise_test.dart` (moved from `test/lesson/`), new `integration_test/multiple_choice_exercise_test.dart` (real device run on macOS, verifies direction framing, stable keys, same-set fallback, and CHECK→CONTINUE end-to-end).
- `flutter analyze` / `dart format` / `dart fix --dry-run` clean; `flutter test` 198/198 green; all 3 integration tests (including the new one) pass on a real macOS desktop build.
- Filed #030 (P3, not fixed here): `lesson_screen.dart`'s `autoAnswer` condition for the `'phone'`/`'date'`/default switch branches is provably always `false` (dead code, no behavioral effect) — found incidentally while editing this dispatch area, out of scope for this issue.

### Code review fix (2026-10-13)
- Fixed: the first tap on any option immediately locked input and revealed correct/wrong coloring, before CHECK was pressed — contradicting this issue's own "Tap selects/reselects pre-check" acceptance criterion (inherited from #026's quick wiring, not caught when this issue completed the card). `MultipleChoiceCard` now takes a `revealed` flag driven by the shell's feedback phase (`lesson_screen.dart` passes `isFeedback`); tapping before `revealed` just updates the selection (freely reselectable), and locking + correct/wrong coloring only happens once `revealed` is true.
- Updated `test/exercises/multiple_choice_exercise_test.dart`: replaced the old "locked after first tap" test with "reselect pre-check changes the selection" and a new "revealed locks input and shows correct/wrong coloring" test.
- `flutter analyze` / `dart format` / `dart fix --dry-run` clean; `flutter test` 199/199 green; all 3 integration tests still pass individually (the known pre-existing macOS cross-test relaunch flakiness noted in #026 reproduces when running the whole `integration_test/` dir in one invocation — unrelated to this change).
- Not fixed (flagged by the same review, lower severity, left as-is): a hypothetical silent-fallback edge case in `choice_options.dart`'s placeholder loop if a future l10n edit ever drops the `{index}` placeholder, and an efficiency nit (shuffling the full same-set answer pool just to pick up to 3 distractors) — both minor/speculative at current content scale.
