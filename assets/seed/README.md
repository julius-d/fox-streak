# Seed sets (`assets/seed/`)

Fictional first-launch content for issue #002. Real learning content ships in #013.

## Share format v1 (`.foxstreak.json`)

```json
{ "format": "foxstreak-set", "version": 1, "title": "…", "description": "…",
  "createdBy": "Mama", "items": [
    { "type": "choice", "prompt": "Hund", "answer": "dog",
      "promptLang": "de", "answerLang": "en",
      "choices": ["cat","mouse","bird"], "hint": "",
      "imageType": "emoji", "imageContent": "🐶" },
    { "type": "phone", "prompt": "Mama", "answer": "01711234567" },
    { "type": "date", "prompt": "Mamas Geburtstag",
      "answer": "1985-05-14" } ] }
```

Rules (enforced by `lib/src/data/set_json_codec.dart`):

- `format` must be `"foxstreak-set"`, `version` must be `1`.
- `title` non-empty; `createdBy` free-text creator name (trimmed, non-empty,
  max 50 chars, e.g. `"Mama"`).
- Item `type` one of `choice|freeText|phone|date` (#026 split the original
  `vocab` type into `choice`/`freeText`); `prompt`/`answer` non-empty.
- `choice`/`freeText`: `promptLang`/`answerLang` are optional ISO 639-1 codes
  (#022) — omit both for a non-vocab prompt (e.g. a general-knowledge quiz),
  or set both to distinct codes from `kSupportedLanguages` (currently
  `de`/`en`) for a vocab-flavored one; `choice` additionally allows an
  optional `choices` list of non-empty strings, forbidden for `freeText`;
  `hint` optional on both.
- `phone`: `answer` digits-only after normalisation, `^[0-9]{3,15}$`
  (normalisation strips spaces, `-`, `/`, `(`, `)`, `.`, `+`; German numbers
  keep their leading `0`, e.g. `01711234567`).
- `date`: `answer` strict ISO `YYYY-MM-DD` in `1900-01-01..today`.
- `imageType`/`imageContent` are optional and both-or-neither (#014), on any
  item type: `imageType` one of `emoji|base64|url`, `imageContent` the
  literal emoji / base64 data / URL. **Bundled seed sets must only use
  `emoji` or `base64` — never `url`**: the app is local-only (#013 requires
  airplane-mode to work) and a `url` image needs network to load, so it
  isn't guaranteed to work offline. `url` is fine for user-added items,
  with that tradeoff documented in the item editor.
- Import always creates a **new** set with fresh ids, never overwrites.
- Unknown fields at the set level are ignored; unknown item fields throw
  `SetImportException`.

## Seeding

`SeedLoader.ensureSeeded()` imports every `demo_*.foxstreak.json` when the
database has no sets. Corrupt seeds are skipped, never crash launch.

`demo_bundeslaender.foxstreak.json` (#022) is a non-vocab `choice` example:
all 16 German Bundesländer capitals, no `promptLang`/`answerLang`, no
explicit `choices` — distractors come entirely from the same-set fallback
(each item's 3 wrong options are drawn from the other 15 states' capitals).

`demo_animals.foxstreak.json`'s "Hund"/"dog" item (#014) carries
`"imageType": "emoji"` / `"imageContent": "🐶"` as the end-to-end example of
the prompt-side image field.

`demo_bundeslaender_shapes.foxstreak.json` is the `base64` counterpart to
the above: all 16 Bundesländer again, but the prompt is the same fixed
question ("Welches Bundesland ist das?") for every item — the map outline
in `imageContent` is the actual content being tested, and the answer is the
state name, so the prompt text alone must never give it away. No
`promptLang`/`answerLang`/explicit `choices` either, for the same same-set
distractor fallback as the capitals quiz. Images are downsized (max 300px)
PNGs, not the source SVGs — `FoxItemImage`'s `base64` path renders via
`Image.memory`, which cannot decode SVG.

Both Bundesländer seeds' map images are boundary polygons sourced from
OpenStreetMap (via Nominatim), licensed ODbL — every item carries
`"imageCopyright": "© OpenStreetMap contributors"` (#094) accordingly.
