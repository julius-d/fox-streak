# Seed sets (`assets/seed/`)

Fictional first-launch content for issue #002. Real learning content ships in #013.

## Share format v1 (`.foxstreak.json`)

```json
{ "format": "foxstreak-set", "version": 1, "title": "…", "description": "…",
  "createdBy": "Mama", "items": [
    { "type": "vocab", "prompt": "Hund", "answer": "dog",
      "direction": "deEn", "choices": ["cat","mouse","bird"], "hint": "" },
    { "type": "phone", "prompt": "Mama", "answer": "01711234567" },
    { "type": "date", "prompt": "Mamas Geburtstag",
      "answer": "1985-05-14" } ] }
```

Rules (enforced by `lib/src/data/set_json_codec.dart`):

- `format` must be `"foxstreak-set"`, `version` must be `1`.
- `title` non-empty; `createdBy` free-text creator name (trimmed, non-empty,
  max 50 chars, e.g. `"Mama"`).
- Item `type` one of `vocab|phone|date`; `prompt`/`answer` non-empty.
- `vocab`: `direction` required (`deEn|enDe`); `choices` optional list of
  non-empty strings; `hint` optional.
- `phone`: `answer` digits-only after normalisation, `^[0-9]{3,15}$`
  (normalisation strips spaces, `-`, `/`, `(`, `)`, `.`, `+`; German numbers
  keep their leading `0`, e.g. `01711234567`).
- `date`: `answer` strict ISO `YYYY-MM-DD` in `1900-01-01..today`.
- Import always creates a **new** set with fresh ids, never overwrites.
- Unknown fields at the set level are ignored; unknown item fields throw
  `SetImportException`.

## Seeding

`SeedLoader.ensureSeeded()` imports every `demo_*.foxstreak.json` when the
database has no sets. Corrupt seeds are skipped, never crash launch.
