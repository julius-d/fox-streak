# Issue 026: Migrate items.type `vocab` → `choice`/`freeText`

Status: done | Priority: P0 | Type: core | Completed-at: 2026-10-13

## Goal
Execute the schema/data/dispatch migration that #006 and #007 both flagged as a shared dependency but explicitly deferred: split the single `vocab` item type into `choice` (multiple-choice, #006) and `freeText` (#007), so #007 can be implemented end-to-end and #006's already-shipped MCQ card can be reconciled with its refined spec (type `choice`, `isCorrect`-flag grading instead of string comparison).

## Decisions (2026-10-12, with repo owner)
- Existing data mapping: **all existing `vocab` rows become `choice`** on migration (matches what's actually been practiced via #006's MCQ card to date, the only vocab exercise type ever implemented); `freeText` is purely additive for items created after this migration lands — no automatic reclassification.
- `direction`: stays **required** for `choice` items; becomes **optional/nullable** for `freeText` items (per #007) — non-vocab-flavored `freeText` items may omit it.
- `choices`: unchanged (optional, up to 3) for `choice` items; **never populated** for `freeText` items.
- No DB column/structural change is needed (`items.type` is a plain TEXT column enforced in Dart, no CHECK constraint) — but still bump `schemaVersion` to 2 with a Drift `onUpgrade` step (`UPDATE items SET type = 'choice' WHERE type = 'vocab'`) + migration test, per #002's existing convention ("Later versions add migrations + migration test"), so the rewrite runs exactly once and is verifiable.

## Acceptance criteria
- [x] `validation.dart`: `kItemTypes` becomes `{'choice', 'freeText', 'phone', 'date'}` (no more `'vocab'`); `direction` required for `choice`, optional/nullable for `freeText`, forbidden for `phone`/`date`; `choices` allowed (optional) for `choice` only, forbidden for `freeText`/`phone`/`date`.
- [x] `database.dart`: `schemaVersion` bumped to 2; `onUpgrade` step rewrites existing `type = 'vocab'` rows to `type = 'choice'`; migration test (`test/data/`) verifies pre-migration seed data lands as `choice` with `direction`/`choices` untouched.
- [x] `lesson_screen.dart` dispatch: `item.type == 'choice'` routes to `MultipleChoiceCard` (renamed from `'vocab'`); `item.type == 'freeText'` routes to the **real** `FreeTextExercise` card (deviation from plan: #007's card had already landed by the time this issue was implemented, so it was wired directly instead of a placeholder).
- [x] `multiple_choice_card.dart`: internal `'vocab'` references/comments renamed to `choice`; grading switches to the `isCorrect`-flag approach from #006's refined spec (replacing the current case/whitespace-insensitive string comparison), since nothing is typed in this card.
- [x] `item_editor.dart` (#004 editor): type picker gains `choice`/`freeText` as the two vocab-flavored options (replacing the single `vocab` entry); existing fields (prompt/answer/direction/choices) stay as-is for `choice`. `freeText` gets a minimal non-rejecting path (answer + optional direction, no distractors) — full freeText-authoring UX stays a future refinement.
- [x] `set_json_codec.dart` / `sets_repository.dart`: import/export "known type" validation accepts `choice`/`freeText` (not `vocab`); `direction` required for `choice`, optional for `freeText` on import.
- [x] `item_type_icons.dart` / `set_detail_screen.dart`: icon map covers `choice`/`freeText` (reusing the existing vocab-style icon for both is fine — no new art required).
- [x] Seed content (`assets/seed/demo_family.foxstreak.json`, `assets/seed/demo_animals.foxstreak.json`, `assets/seed/README.md`): `type: "vocab"` renamed to `type: "choice"`.
- [x] `lib/test/lesson/helpers/placeholder_exercise_card.dart` and all existing tests referencing `'vocab'` updated to `'choice'`; full suite green.
- [x] `flutter analyze` clean, `dart format` clean, `flutter test` green (incl. the new migration test).

## Tasks
1. `validation.dart`: rename the `kItemTypes` entry, update `validateDirection`/`validateChoices` branching for the 4-way split.
2. `database.dart`: bump `schemaVersion` to 2, add the `onUpgrade` rewrite step + migration test.
3. Rename `'vocab'` → `'choice'` across `lesson_screen.dart`, `multiple_choice_card.dart`, `item_editor.dart`, `set_detail_screen.dart`, `item_type_icons.dart`, `sets_repository.dart`, `set_json_codec.dart`, the seed JSON + README, and test helpers.
4. Add `'freeText'` as a recognized type everywhere the same switch/validation lives (editor type-picker option, dispatch placeholder, import/export validation) — the actual card UI stays #007's job.
5. Update `multiple_choice_card.dart` grading to the `isCorrect`-flag approach (drop string comparison) per #006's refined Decisions.
6. Tests: migration test (old `vocab` seed data → `choice` post-upgrade), update every existing test asserting `'vocab'` to `'choice'`, add a case asserting `freeText` passes type validation.

## Out of scope
- #007's actual `FreeTextExercise` card/widget and its grading (`gradeText`) — this issue only makes `freeText` a valid, dispatchable (placeholder-carded) type.
- #006's distractor-fallback rework (same-set pool + placeholder chain) beyond the type rename + grading-approach fix called out above.
- Any `freeText`-specific editor UI (hint reveal, etc.) — #007's job.

## Dependencies
- Unblocks #007 (can't implement `freeText` end-to-end without this).
- Reconciles #006 (already shipped against the old `vocab` type and string-based grading — this issue renames its dispatch/type and simplifies its grading).
- Builds on #002 (schema), #004 (editor), #005 (dispatch).

## Verify
```powershell
flutter analyze        # must be clean (includes riverpod_lint)
dart format --output=none --set-exit-if-changed .  # must be clean
flutter test           # migration test + all existing green
```

## Summary (2026-10-13)
- Migration landed as planned: `schemaVersion` 2, `onUpgrade` rewrites `vocab`→`choice`, verified by `test/data/migration_test.dart` (seeds a real on-disk v1 db, reopens it with the real schema, asserts the rewrite + untouched sibling row).
- **Deviation from plan**: `freeText` dispatches to the real `FreeTextExercise` card (built by #007 in the meantime), not a placeholder — the plan's assumption ("until #007's real card lands") was already stale by the time this landed, so the lesson is now genuinely end-to-end for both `choice` and `freeText`.
- `multiple_choice_card.dart` grading now uses an `isCorrect` flag assigned once per option at build time (no more string re-comparison); covered by new `test/lesson/multiple_choice_card_test.dart` (previously had zero dedicated tests).
- `item_editor.dart`: type picker now offers "Word (choice)" / "Word (type answer)"; `freeText` gets answer + optional direction, no distractor fields (choices stay forbidden for it).
- Added `integration_test/choice_freetext_dispatch_test.dart`: drives the real `LessonScreen` (no card-builder override) through one `choice` item and one `freeText` item end-to-end — the first live-app proof that `freeText` is actually reachable from a lesson. Passes individually; running the whole `integration_test/` dir in one invocation hits a pre-existing macOS-relaunch flakiness unrelated to this change (confirmed `date_exercise_test.dart` also only passes standalone).
- Found + fixed as drive-by cleanup: deleted `test/lesson/helpers/placeholder_exercise_card.dart`, a byte-identical dead duplicate of `lib/test/lesson/helpers/placeholder_exercise_card.dart` (only the `lib/test/...` copy was ever imported).
- `flutter analyze` / `dart format` clean; full suite green (179 `flutter test` + 2 integration tests, run individually).

### Code review fixes (2026-10-13)
- Fixed: `validateDirection('freeText', '')` was falling through to a confusing "unknown direction" error instead of being treated as "no direction" (consistent with `null`) — now matches `choice`'s empty-string handling.
- Fixed: `item_editor.dart`'s `_choiceFields`/`_freeTextFields` had copy-pasted the identical answer-field widget; extracted a shared `_answerField(l10n)`.
- Fixed stale doc comments naming the old `vocab` type (`exercise_card.dart`'s `ExerciseCardBuilder` contract doc + example, `library_screen.dart`'s header).
- Added missing test coverage for `item_type_icons.dart` (`iconForItemType`/`colorForItemType` had zero tests before this review).
- Filed #029 for two pre-existing gaps the review surfaced but that aren't #026 regressions: `SetDetailScreen` has zero test coverage (predates #026), and the "is this type choice-or-freeText" grouping is hand-duplicated across `item_editor.dart`/`sets_repository.dart`/`validation.dart`.
