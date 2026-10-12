# Issue 026: Migrate items.type `vocab` → `choice`/`freeText`

Status: open | Priority: P0 | Type: core

## Goal
Execute the schema/data/dispatch migration that #006 and #007 both flagged as a shared dependency but explicitly deferred: split the single `vocab` item type into `choice` (multiple-choice, #006) and `freeText` (#007), so #007 can be implemented end-to-end and #006's already-shipped MCQ card can be reconciled with its refined spec (type `choice`, `isCorrect`-flag grading instead of string comparison).

## Decisions (2026-10-12, with repo owner)
- Existing data mapping: **all existing `vocab` rows become `choice`** on migration (matches what's actually been practiced via #006's MCQ card to date, the only vocab exercise type ever implemented); `freeText` is purely additive for items created after this migration lands — no automatic reclassification.
- `direction`: stays **required** for `choice` items; becomes **optional/nullable** for `freeText` items (per #007) — non-vocab-flavored `freeText` items may omit it.
- `choices`: unchanged (optional, up to 3) for `choice` items; **never populated** for `freeText` items.
- No DB column/structural change is needed (`items.type` is a plain TEXT column enforced in Dart, no CHECK constraint) — but still bump `schemaVersion` to 2 with a Drift `onUpgrade` step (`UPDATE items SET type = 'choice' WHERE type = 'vocab'`) + migration test, per #002's existing convention ("Later versions add migrations + migration test"), so the rewrite runs exactly once and is verifiable.

## Acceptance criteria
- [ ] `validation.dart`: `kItemTypes` becomes `{'choice', 'freeText', 'phone', 'date'}` (no more `'vocab'`); `direction` required for `choice`, optional/nullable for `freeText`, forbidden for `phone`/`date`; `choices` allowed (optional) for `choice` only, forbidden for `freeText`/`phone`/`date`.
- [ ] `database.dart`: `schemaVersion` bumped to 2; `onUpgrade` step rewrites existing `type = 'vocab'` rows to `type = 'choice'`; migration test (`test/data/`) verifies pre-migration seed data lands as `choice` with `direction`/`choices` untouched.
- [ ] `lesson_screen.dart` dispatch: `item.type == 'choice'` routes to `MultipleChoiceCard` (renamed from `'vocab'`); `item.type == 'freeText'` falls back to the existing placeholder card until #007's real card lands (mirrors the `date` placeholder pattern that existed pre-#009).
- [ ] `multiple_choice_card.dart`: internal `'vocab'` references/comments renamed to `choice`; grading switches to the `isCorrect`-flag approach from #006's refined spec (replacing the current case/whitespace-insensitive string comparison), since nothing is typed in this card.
- [ ] `item_editor.dart` (#004 editor): type picker gains `choice`/`freeText` as the two vocab-flavored options (replacing the single `vocab` entry); existing fields (prompt/answer/direction/choices) stay as-is for `choice`. `freeText`-specific editor UI is #007's job — this issue only needs the type-picker rename + validation wiring so saving a `freeText` item doesn't get rejected.
- [ ] `set_json_codec.dart` / `sets_repository.dart`: import/export "known type" validation accepts `choice`/`freeText` (not `vocab`); `direction` required for `choice`, optional for `freeText` on import.
- [ ] `item_type_icons.dart` / `set_detail_screen.dart`: icon map covers `choice`/`freeText` (reusing the existing vocab-style icon for both is fine — no new art required).
- [ ] Seed content (`assets/seed/demo_family.foxstreak.json`, `assets/seed/demo_animals.foxstreak.json`, `assets/seed/README.md`): `type: "vocab"` renamed to `type: "choice"`.
- [ ] `lib/test/lesson/helpers/placeholder_exercise_card.dart` and all existing tests referencing `'vocab'` updated to `'choice'`; full suite green.
- [ ] `flutter analyze` clean, `dart format` clean, `flutter test` green (incl. the new migration test).

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
