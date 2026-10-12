# Issue 007: Vocab exercise — free text input

Status: done | Priority: P0 | Type: feature | Refined-at: 2026-10-12 | Completed-at: 2026-10-12

## Goal
Type-the-answer mode: learner sees a prompt and types the full answer into a text field, graded tolerantly on whitespace/case/trailing punctuation but strictly on umlauts and ß. Originally vocab-only (DE<->EN); generified per the Decisions below so the same `freeText` exercise type can host non-vocab recall prompts later, not just translations.

## Decisions (2026-10-12, with repo owner)
- **Type split (supersedes #002's `vocab` type — needs its own schema follow-up, see Dependencies):** `items.type` generifies from content-domain names (`vocab|phone|date`) to interaction-mode names. The `vocab` slot splits into two: `choice` (multiple-choice, owned by #006) and `freeText` (this issue). `phone`/`date` keep their current type names for now. This issue only *specifies* the new `freeText` type and its contract; it does **not** implement the #002 migration or touch #002/#005/#006 files — those need their own follow-up pass before `freeText` can actually land (#002 is `Status: done`, so this is a breaking schema change, not an in-place edit).
  - `direction` (`deEn|enDe`) stays meaningful for vocab-flavored `freeText` items but becomes optional/nullable: non-vocab `freeText` items (future use) omit it and the card just shows `prompt` → compares typed text to `answer` with no language-direction framing.
  - `choices` (JSON distractor array, used by #006/`choice`) is never populated for `freeText` items.
- ß/ss: **strict** — ß and ss are different characters, same treatment as umlauts (ä ≠ a); `gradeText` never normalizes between them.
- Reveal-hint: mirrors #008 (dial pad) / #009 (date)'s eye-icon pattern — a pre-check button reveals the first letter of the expected answer and sets `hintUsed: true` on the outcome, for the future #010 5-XP hint tier (not merely a passive label shown after a wrong answer).
- Punctuation tolerance: trim whitespace, then strip at most one trailing sentence-ending mark (`. , ! ?`) before comparing case-insensitively. Internal punctuation (apostrophes, hyphens, etc.) must match exactly.
- Keyboard locale hint: dropped. Flutter's `TextField` can't force IME locale without extra plugins (would violate #015's no-new-deps spirit); the prompt text already signals the expected answer language via `direction` when present.

## Acceptance criteria
- [x] `TextField` with autocorrect OFF; CHECK enabled only when the field is non-empty (`hasAnswer`)
- [x] Tolerant grading via `gradeText(expected, actual)`: trim, case-insensitive, strip at most one trailing `. , ! ?`; umlauts (ä/ö/ü) and ß must match exactly, no normalization
- [x] Reveal-hint: eye-icon button (pre-check, available regardless of `hasAnswer`) shows the first letter of the expected answer, sets `hintUsed: true` via the `ExerciseDraft` outcome hook (future #010 5-XP tier), same affordance as #008/#009
- [x] On wrong: feedback banner shows `correctAnswerLabel = item.answer` (full expected answer)
- [x] Vocab-flavored items (`direction` present) work both directions (DE→EN and EN→DE); non-vocab items (`direction` null) just show `prompt` with no direction framing
- [x] Follows #015: kit tokens only, min 48dp target, no ad-hoc styling, all strings via `lib/l10n` arb params (DE + EN)

## Tasks
1. schema migration: split `vocab` into `choice`/`freeText` type values, make `direction` nullable-and-optional-for-non-vocab, migration + test for existing data
2. `FreeTextExercise` widget (`lib/src/exercises/free_text_exercise.dart`)
3. `gradeText(expected, actual)` pure function in `lib/src/data/validation.dart` + unit tests (umlauts, ß, case, trailing punctuation, whitespace, direction-null generic case)
4. Reveal-hint eye-icon wired to the `ExerciseDraft` contract (`hintLabel` = first letter, outcome `hintUsed: true` on use), mirroring #008/#009
5. l10n: arb keys for the text-field placeholder, reveal-hint label/tooltip (reuse #008/#009 wording where identical)
6. Stable keys for #016: text field, reveal-hint button (card-internal; shell keys stay in #005)

## Out of scope
- The actual #002 schema migration (`vocab` → `choice`/`freeText` type values, schema version bump + migration test) — flagged as a Dependency below, not implemented here.
- #005's shell dispatch update (routing `item.type == 'freeText'` to this card) and #006's rename/regenerification to `choice` — separate follow-up passes on those issues.
- XP math (#010), streak (#011).

## Dependencies
- Implements the #005 `ExerciseCard` contract (`ExerciseDraft(hasAnswer, grade(), correctAnswerLabel, hintLabel?)`); reveal-hint sets `hintUsed: true` in the #005 outcome hook, consumed later by #010's 5-XP tier (same pattern #008/#009 already established).
- Follows #015 (kit reuse).

## Follow-up (from #005 review 2026-10-11, updated 2026-10-12)
- Implements the #005 `ExerciseCard` contract; `gradeText` is the card's `grade()` body, `correctAnswerLabel` = expected answer, `hintLabel` = first-letter hint shown via the reveal-hint button (not merely a passive wrong-banner label).
- Owns card-internal stable keys for #016 (text field, reveal-hint button).
- **New (2026-10-12): item-type generification.** This issue now specifies the `freeText` item type that supersedes vocab's half of #002's `vocab|phone|date` enum. #002 (done), #005 (dispatch-by-type), and #006 (multiple-choice, becomes `choice` type) all need their own follow-up refinement before this can be implemented end-to-end — intentionally not done in this pass per repo-owner instruction.

## Verify
```powershell
flutter analyze        # must be clean (includes riverpod_lint)
dart format --output=none --set-exit-if-changed .  # must be clean
flutter test           # new free-text exercise tests + all existing green
```

## Summary (2026-10-12)
- **New widget**: `lib/src/exercises/free_text_exercise.dart` (`FreeTextExercise` / `buildFreeTextExercise`), standalone — not wired into `LessonScreen`'s `item.type` dispatch, since that needs #002's `vocab`→`choice`/`freeText` schema migration (out of scope here, see Dependencies).
- **Grading**: `gradeText(expected, actual)` added to `lib/src/data/validation.dart` (trim, strip ≤1 trailing `. , ! ?`, case-insensitive; umlauts/ß never normalized), with unit tests in `test/data/validation_test.dart`.
- **Reveal-hint**: eye icon sets `hintLabel` (first letter) on `ExerciseDraft` — the contract's actual hook for this (`ExerciseDraft` has no separate `hintUsed` bool; `exercise_card.dart`'s own doc comment already names this as "#007 first-letter hint").
- **l10n**: 3 new keys (`exerciseFreeTextPlaceholder`, `exerciseFreeTextRevealHintAria`, `exerciseFreeTextHintLabel`) in `app_en.arb`/`app_de.arb` + hand-written delegate; direction framing reuses existing `directionDeEn`/`directionEnDe`.
- **Tests**: `test/exercises/free_text_exercise_test.dart` — 7 widget tests pumping the real widget (hasAnswer gating, grading, autocorrect-off, reveal-hint, direction framing deEn/enDe/null). All 151 repo tests pass; `flutter analyze` and `dart format` clean.
- **Stable keys** (#016): `freeTextAnswerField`, `freeTextRevealHintButton`, `freeTextHintLabel`.
- **Code review fixes applied**: first-letter hint now uses `answer.runes.first` (Unicode code point) instead of `answer[0]` (UTF-16 code unit, breaks on surrogate pairs); layout now uses the same `ConstrainedBox`+`IntrinsicHeight` centering pattern as #008 so it actually centers in a scroll view. Filed #027 for two cross-cutting cleanups found during review (not fixed here): per-item exercise-card state reset, and de-duplicating the reveal-hint button into a shared #015 kit widget.
