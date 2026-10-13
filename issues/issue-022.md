# Issue 022: Generify direction into promptLang/answerLang + Bundesländer capitals seed set

Status: open | Priority: P1 | Type: feature | Refined-at: 2026-10-13

## Goal
Replace the opaque `items.direction` enum (`deEn`/`enDe`) with two language-code fields, `promptLang`/`answerLang` (ISO 639-1, e.g. `de`/`en`), so adding more language pairs later is just adding codes to a supported-languages set — no enum explosion, no further schema change. Use this to make `choice` (multiple-choice) usable for non-vocab recall quizzes (optional language pair, mirroring `freeText`'s existing optionality), and ship a concrete example: a bundled demo set quizzing the capitals of all 16 German Bundesländer.

## Decisions (2026-10-13, with repo owner)
- **Schema**: `items.direction` (`TEXT?`) replaced by `items.prompt_lang` + `items.answer_lang` (`TEXT?`, ISO 639-1 codes). `schemaVersion` bumps 3→4; `onUpgrade` step rewrites existing rows (`direction = 'deEn'` → `prompt_lang='de', answer_lang='en'`; `'enDe'` → reversed; `null` → both null), then drops the old `direction` column. Migration test required (precedent: `test/data/migration_test.dart`'s #026 vocab→choice case).
- **Supported languages**: `kSupportedLanguages = {'de', 'en'}` for now (`validation.dart`) — adding a third language later is just adding a code here plus a display-name string; no further architecture change. A language-pair value is valid iff both codes are in this set and `promptLang != answerLang`.
- **Optionality**: both `promptLang`/`answerLang` stay optional (and must be set/unset together) for `choice` **and** `freeText` — this generalizes the existing `freeText`-only optionality (e.g. the "Capital of France" non-vocab test fixture) to `choice` too. `phone`/`date` forbid both, as `direction` did.
- **Same-set distractor fallback must filter by type, not just language pair.** `choice_options.dart`'s fallback currently guards on `item.direction != null` (defensively added so phone/date items, which also have no direction, never leak in as distractors). Once `choice` items can legitimately have no language pair, that guard would also block two non-vocab `choice` items from distracting each other. Fix: filter by `other.type == item.type && other.promptLang == item.promptLang && other.answerLang == item.answerLang`.
- **Editor UX**: `item_editor.dart`'s shared direction-picker helper (used by both `_choiceFields` and `_freeTextFields`) becomes: a toggle (default **off** for new items, default **on** when editing an item that already has a language pair) — e.g. "Vocabulary translation" — that reveals two language dropdowns (populated from `kSupportedLanguages`) only when on. Off hides both dropdowns and keeps both fields null. On requires picking both (and they must differ) before save.
- **Direction-framing label**: `multiple_choice_exercise.dart`/`free_text_exercise.dart` build their "X → Y" framing label generically from `promptLang`/`answerLang` via a language-display-name lookup (`l10n`, currently covering `de`/`en`) + one parameterized template string, replacing the two fixed `directionDeEn`/`directionEnDe` l10n keys.
- **Share format (JSON)**: `set_json_codec.dart`'s `"direction": "deEn"` field becomes `"promptLang": "de", "answerLang": "en"`. No backward-compat shim for old-shape files — pre-release, local-only MVP, no real users yet (per AGENTS.md). Existing bundled seed assets (`demo_animals`, `demo_family`) and `assets/seed/README.md`'s example are updated to the new field shape in this issue, not left as a dangling format mismatch.
- **Seed content**: one new bundled set, `assets/seed/demo_bundeslaender.foxstreak.json`, all 16 Bundesländer as `choice` items (no `promptLang`/`answerLang`), including the 3 city-states (Hamburg/Berlin/Bremen) as-is. Distractors rely on the same-set fallback (no explicit `choices`) — every item's 3 wrong options are drawn from the other 15 states' capitals.
  - Content: Schleswig-Holstein→Kiel, Hamburg→Hamburg, Mecklenburg-Vorpommern→Schwerin, Niedersachsen→Hannover, Bremen→Bremen, Sachsen-Anhalt→Magdeburg, Brandenburg→Potsdam, Berlin→Berlin, Sachsen→Dresden, Thüringen→Erfurt, Hessen→Wiesbaden, Nordrhein-Westfalen→Düsseldorf, Rheinland-Pfalz→Mainz, Saarland→Saarbrücken, Baden-Württemberg→Stuttgart, Bayern→München.

## Acceptance criteria
- [ ] `database.dart`: `schemaVersion` 4; `prompt_lang`/`answer_lang` columns added, `direction` dropped, `onUpgrade` rewrite step + migration test (old `direction` values map correctly, old column gone).
- [ ] `validation.dart`: `kSupportedLanguages = {'de','en'}`; direction validation replaced by a language-pair validator (both optional together for `choice`/`freeText`, must differ when set, forbidden for `phone`/`date`).
- [ ] `sets_repository.dart`: `createItem`/`updateItem` take `promptLang`/`answerLang` instead of `direction`; the inline `'direction is required for choice items'` throw in `updateItem`'s type-change guard is removed (no longer required at all). *(Touches the same guard #029 flagged as duplicated — fold in if convenient.)*
- [ ] `set_json_codec.dart` + `assets/seed/README.md`: JSON share format uses `promptLang`/`answerLang`; existing seed assets (`demo_animals`, `demo_family`) updated to match.
- [ ] `item_editor.dart`: shared direction-picker becomes a toggle + two language dropdowns, used by both `_choiceFields` and `_freeTextFields`; hidden by default for new items, shown by default when editing an item with an existing language pair.
- [ ] `multiple_choice_exercise.dart` / `free_text_exercise.dart`: direction-framing label built generically from `promptLang`/`answerLang` via a language-display-name lookup + one parameterized l10n template (replacing `directionDeEn`/`directionEnDe`).
- [ ] `choice_options.dart`'s same-set fallback filters by type + language pair (not language pair alone).
- [ ] New `assets/seed/demo_bundeslaender.foxstreak.json` (16 `choice` items, no language pair, no `choices`) registered in `seed_loader.dart`'s `kSeedAssetPaths`.
- [ ] All existing tests touching `direction` updated to the new fields (`item_editor_test.dart`, `multiple_choice_exercise_test.dart`, `free_text_exercise_test.dart`, `migration_test.dart`, `set_json_codec_test.dart`, `lesson_shell_test.dart`, `choice_options_test.dart`, `sets_repository_test.dart`, both integration tests); new tests for the toggle UX, the generic label builder, and the new seed.
- [ ] `flutter analyze` / `dart format` / `flutter test` clean.

## Tasks
1. Schema migration: add `prompt_lang`/`answer_lang`, drop `direction`, `schemaVersion` → 4, `onUpgrade` rewrite + migration test.
2. `validation.dart`: `kSupportedLanguages` + language-pair validator replacing `validateDirection`/`kDirections`.
3. `sets_repository.dart`: swap `direction` param for `promptLang`/`answerLang` in create/update; drop the inline required-direction guard.
4. `set_json_codec.dart` + seed assets + README: new JSON field shape.
5. `item_editor.dart`: toggle + two-language-dropdown picker (shared by choice/freeText), new l10n label.
6. `multiple_choice_exercise.dart` / `free_text_exercise.dart`: generic direction-label builder (language display names + template string), replacing `directionDeEn`/`directionEnDe`.
7. `choice_options.dart`: fix same-set fallback filter (type + language pair).
8. New `demo_bundeslaender.foxstreak.json`; register in `seed_loader.dart`.
9. Update all tests listed in the acceptance criteria.

## Out of scope
- Actually adding a third language (e.g. French) — this issue only builds the architecture that makes doing so trivial later (`kSupportedLanguages` + a display-name string, no schema/UI change).
- Full language-name localization beyond `de`/`en` display names.

## Dependencies
- Builds on #002 (schema), #004/#026 (editor + type split), #006 (choice card + `choice_options.dart`), #007 (`freeText`'s existing optional direction), #010 (schema v3, `todayXp` — this issue bumps to v4 on top of it).
- Touches the same `sets_repository.dart` guard #029 already flagged.

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```
