# Issue 093: Question-set format docs for GitHub Pages

Status: done | Priority: P3 | Type: docs | Refined-at: 2026-10-31 | Completed-at: 2026-10-31

## Context

The `.foxstreak.json` question-set share format already exists and is
implemented in `lib/src/data/set_json_codec.dart` /
`lib/src/data/validation.dart` (share format v1). Real examples ship today
in `assets/seed/*.foxstreak.json` (e.g. `demo_family.foxstreak.json` has
`phone`, `date` and `choice` items; `demo_times_tables.foxstreak.json` has
many `choice` items). This issue only documents what's there today — it
does not add or change any format fields or validation rules.

There is no `docs/` folder yet. This issue only adds its content;
enabling/configuring GitHub Pages itself for the repo (repo settings,
build workflow, etc.) is a separate, later concern.

## Goal

Add a `docs/` folder with:

- `docs/question-set-format.md` — a human-readable explanation of the
  `.foxstreak.json` format: the four item types (`choice`, `freeText`,
  `phone`, `date`), what fields each needs/allows, the `category` values
  (`vocab`, `general`, `math`, `geography`), the `de`/`en` language
  codes, and a worked JSON example for each item type plus one complete
  multi-item set example. It also documents the validation rules /
  common rejection reasons (phone normalisation, date range limits,
  creator-name length, `choices` only allowed on `choice` items,
  `promptLang`/`answerLang` pairing rules) so a hand-written or
  AI-generated file can be fixed up without trial and error. It links to
  the schema file below.
- `docs/question-set.schema.json` — a JSON Schema (not OpenAPI — this is
  a file format, not an HTTP API) describing the same structure
  precisely, with embedded `examples`.

So that other users — and AI agents — can read this and create new,
valid question sets without reading the Dart source.

## Decisions

- **Schema strictness: strict.** `additionalProperties: false` on the
  top-level object and on each item object, even though
  `set_json_codec.dart` itself silently ignores unknown fields today.
  Strictness catches typos (e.g. `anwser`) for anyone authoring files by
  hand or via an LLM — a better authoring experience than mirroring the
  app's current leniency.
- **Schema covers what JSON Schema can express; prose covers the rest.**
  Type-specific structural rules (`choices` only on `choice` items,
  `promptLang`/`answerLang` required together and only for
  `choice`/`freeText`) are expressed with `if`/`then`/`oneOf` in the
  schema. Dynamic rules JSON Schema can't express cleanly (date answer
  must be `<=` today, phone becomes 3–15 digits only after separator
  stripping) stay as prose + examples in the markdown, with the
  validation-rules section explicitly flagging them as "the schema
  can't fully enforce this.".
- **Automated drift check.** Add a test that loads
  `docs/question-set.schema.json` and validates every
  `assets/seed/*.foxstreak.json` file against it, so the schema can't
  silently drift from the real format over time. This likely needs a
  JSON Schema validator as a new dev dependency (e.g. the `json_schema`
  pub package) — picking the exact package is an implementation detail.
- **File names**: `docs/question-set-format.md` and
  `docs/question-set.schema.json`, matching the "question set"
  terminology already used in code (`SetsRepository`, `question_sets`
  table).

## Acceptance criteria

- [x] `docs/question-set-format.md` exists, explains all 4 item types,
  all `category` values, the `de`/`en` language codes, includes a worked
  example per item type plus one full multi-item set example, documents
  validation rules / common rejection reasons, and links to
  `docs/question-set.schema.json`.
- [x] `docs/question-set.schema.json` is a valid JSON Schema describing
  the v1 share format exactly as implemented in `set_json_codec.dart` /
  `validation.dart` (required/optional fields, enums for `type` and
  `category`, `additionalProperties: false`), with embedded `examples`.
- [x] A test validates every `assets/seed/*.foxstreak.json` file against
  `docs/question-set.schema.json` and passes.
- [x] `flutter analyze` and `dart format` clean; `flutter test` green.

## Out of scope

- Enabling/configuring GitHub Pages itself for the repo.
- Any change to the actual format, fields, or validation behavior in
  `set_json_codec.dart` / `validation.dart`.
- In-app instructions for how to import a `.foxstreak.json` file into
  FoxStreak.

## Summary

Added `docs/question-set-format.md` and `docs/question-set.schema.json`
(JSON Schema 2020-12, `additionalProperties: false` everywhere, `oneOf`
per item type, a `languagePair` `$defs` entry enforcing the
promptLang/answerLang pairing + `de`/`en` distinctness rule). Added dev
dependency `json_schema` and `test/docs/question_set_schema_test.dart`,
which validates every `assets/seed/*.foxstreak.json` file against the
schema (drift guard). No production code changed.

## Code review

The automated code-review subagent failed on a network error (API
unreachable) rather than completing, so this review was done directly.
- `title`/`createdBy`/item `prompt`/`answer` (choice & freeText) only had
  `minLength: 1`, so a whitespace-only value (e.g. `"   "`) would pass the
  schema but be rejected by `set_json_codec.dart`'s trim-then-check logic.
  Fixed: added `"pattern": "\\S"` to those fields (and to `choices` array
  entries) so the schema now also rejects whitespace-only strings.
- Everything else checked out: the `languagePair` `oneOf` (absent-both /
  de→en / en→de) exactly mirrors `validateLanguagePair`'s pairing +
  distinctness rule for the current 2-code language set; `phone`/`date`
  item schemas correctly omit `promptLang`/`answerLang`/`choices` (caught
  by `additionalProperties: false`); the "unknown fields are silently
  ignored by the app" prose claim was re-verified against
  `set_json_codec.dart` (no exhaustive-key check exists at either the set
  or item level). Not fixed because no issue found — matches the real
  implementation.
