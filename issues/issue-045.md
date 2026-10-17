# Issue 045: Multiplication-table practice set (set `category`) + fix translate-icon mislabeling

Status: open | Priority: P2 | Type: feature | Refined-at: 2026-10-17

## Goal

Add a bundled times-tables practice set using the existing `choice`/`freeText`
item types — #022 already made both work content-wise without a language
pair (proven by the Bundesländer seed), so no new exercise mechanics are
needed. Along the way, fix a real bug this surfaced: `iconForItemType`
(`lib/src/library/item_type_icons.dart`) shows `Icons.translate` for *every*
`choice`/`freeText` item regardless of content, which is already wrong for
the Bundesländer geography set today and would be equally wrong for math.
Fix it with a new `category` field on the **set**, not the item — sets are
thematically single-purpose today (all-vocab, all-Bundesländer), so one
category per set is enough and keeps the per-set/per-item icon code simple.

## Decisions (2026-10-17, with repo owner)

- **New `sets.category` column** (`TEXT?`), values from a new
  `kSetCategories = {'vocab', 'general', 'math', 'geography'}` in
  `validation.dart`. `schemaVersion` 5→6; `onUpgrade` just adds the column,
  no backfill needed — existing rows stay `null` and are treated as `vocab`
  everywhere category is read, which preserves today's icon for every
  existing set without a migration decision. `general` stays available for
  future catch-all knowledge sets that aren't vocab/math/geography.
- **Icon/color driven by set category, not item type**, for `choice`/
  `freeText` items: `vocab` → `Icons.translate` (unchanged), `math` →
  `Icons.calculate`, `geography` → `Icons.public`, `general` → `Icons.quiz`.
  `phone`/`date` items are unaffected — those stay keyed by `type` as today
  (`Icons.phone` / `Icons.cake`), since that distinction is still meaningful
  per item. Color pairing mirrors the existing semantic-token approach
  (`colorForItemType`): pick AA-safe light/dark pairs from `FoxSemanticColors`
  for the two new categories, same as `info`/`success`/`flame` today.
- **`library_screen.dart`'s per-set badge row** simplifies from "one icon per
  distinct item `type` present in the set" to one icon for the set's
  `category` — the list-of-distinct-types logic goes away.
- **`set_detail_screen.dart`'s per-item icon**: `phone`/`date` items keep
  their type-based icon; `choice`/`freeText` items show the set's category
  icon instead of the always-translate icon.
- **`set_editor_screen.dart`** gets a category picker (segmented button, 4
  options), defaulting to `vocab` for new sets (matches today's only
  behavior, so existing muscle memory doesn't change).
- **`sets_repository.dart`**: `createSet`/`updateSet` take `category`.
- **`set_json_codec.dart`**: share format gains an optional `"category"`
  field; missing on import → defaults to `vocab` (same rule as the DB
  migration default, for the same reason — no decision forced on old files).
- **Distractors**: reuse `choice_options.dart`'s existing same-set fallback
  as-is — no new "near-miss" numeric distractor logic. Lessons already
  shuffle-and-cap a set's items at 20 per session
  (`lesson_controller.dart:254`), so a 78-item set works fine with existing
  infra.
- **New `assets/seed/demo_times_tables.foxstreak.json`**: `category: 'math'`,
  `choice` items, no `promptLang`/`answerLang` (same shape as Bundesländer).
  Content: all 78 unique multiplication facts for 1–12 where `a ≤ b`
  (dedupes commutative pairs — `3×5` and `5×3` are the same fact, not drilled
  twice). Prompt format `"{a} × {b}"`, answer `"{a*b}"`.
- **Existing seeds retrofitted**: `demo_animals`/`demo_family` →
  `category: 'vocab'`; `demo_bundeslaender` → `category: 'geography'` (fixes
  its existing mis-icon as a side effect of this issue, not a separate fix).
- **`free_text_exercise.dart`**: use `TextInputType.number` for the answer
  field when `item.answer` consists solely of digits. Content-driven (checks
  the stored answer), not category-gated, so it also benefits any other
  all-digit freeText content, not just math.

## Acceptance criteria

- [ ] `database.dart`: `schemaVersion` 6; `sets.category` (`TEXT?`) column
      added via `onUpgrade`; migration test (existing rows' `category` is
      `null` post-upgrade, column present).
- [ ] `validation.dart`: `kSetCategories = {'vocab', 'general', 'math', 'geography'}`.
- [ ] `item_type_icons.dart` (or a renamed equivalent): icon/color for
      `choice`/`freeText` items keyed by the set's category (`null` treated
      as `vocab`); `phone`/`date` unchanged.
- [ ] `library_screen.dart`: per-set badge shows one category icon, not a
      per-distinct-type list.
- [ ] `set_detail_screen.dart`: per-item icon uses category for
      `choice`/`freeText`, type for `phone`/`date`.
- [ ] `set_editor_screen.dart`: category segmented-button picker, defaults to
      `vocab` for new sets, pre-fills from `existing?.category` when editing.
- [ ] `sets_repository.dart`: `createSet`/`updateSet` take `category`.
- [ ] `set_json_codec.dart`: `"category"` optional field, round-trips on
      export, defaults to `vocab` on import when absent.
- [ ] New `assets/seed/demo_times_tables.foxstreak.json` (78 items, `category:
      'math'`, no language pair, no explicit `choices`), registered in
      `seed_loader.dart`'s `kSeedAssetPaths`.
- [ ] `demo_animals`/`demo_family` seeds get `"category": "vocab"`;
      `demo_bundeslaender` gets `"category": "geography"`.
- [ ] `free_text_exercise.dart`: all-digit answers get
      `keyboardType: TextInputType.number`.
- [ ] New l10n strings (DE + EN) for the 4 category picker labels.
- [ ] Tests updated/added: migration test, `item_type_icons_test.dart` (or
      equivalent) for category-driven icons, `set_editor_screen_test.dart`
      for the picker, `set_json_codec_test.dart` for the new field,
      `sets_repository_test.dart`, `library_screen_test.dart`/
      `set_detail_screen_test.dart` for the simplified badge logic,
      `free_text_exercise_test.dart` for the numeric keyboard.
- [ ] `flutter analyze` / `dart format` / `dart fix --dry-run` /
      `flutter test` clean.

## Tasks

1. Schema migration: `sets.category`, `schemaVersion` → 6, migration test.
2. `validation.dart`: `kSetCategories`.
3. `sets_repository.dart`: `category` param on create/update.
4. Icon/color rework: category-driven for `choice`/`freeText`, type-driven
   unchanged for `phone`/`date`.
5. `library_screen.dart` + `set_detail_screen.dart`: wire up the new icon
   logic, simplify the per-set badge row.
6. `set_editor_screen.dart`: category picker + new l10n strings.
7. `set_json_codec.dart`: `"category"` field, codec tests.
8. New `demo_times_tables.foxstreak.json` (78 facts); register in
   `seed_loader.dart`; retrofit `category` onto the 3 existing seeds.
9. `free_text_exercise.dart`: numeric keyboard for all-digit answers.
10. Update/add all tests listed in acceptance criteria.

## Out of scope

- Addition/subtraction/division practice — follow-up issue once
  multiplication ships; this issue is multiplication tables only.
- Per-item category (mixed-category sets) — nothing today needs that.
- "Near-miss" numeric distractors (off-by-one, common mistake values) —
  same-set random fallback is good enough for v1.
- Timed/speed mode, adaptive difficulty, mastery tracking per number —
  future math-specific issues if this lands well.
- A procedural math generator — this issue ships a fixed bundled seed, same
  pattern as Bundesländer.

## Dependencies

- Builds on #002 (schema), #006 (`choice` + `choice_options.dart`), #007
  (`freeText`), #022 (optional language pair on `choice`/`freeText`, and the
  Bundesländer precedent this issue follows + fixes the icon on).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
