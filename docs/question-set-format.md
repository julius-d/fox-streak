# FoxStreak question-set format (`.foxstreak.json`, share format v1)

A question set is a single JSON file with a `.foxstreak.json` extension. It
describes a quiz: a title, who created it, a category, and a list of
questions ("items"). This document explains the format so you can write one
by hand or generate one with an AI assistant.

A precise, machine-checkable version of this same format is at
[`question-set.schema.json`](question-set.schema.json) (JSON Schema,
2020-12 dialect). If you're generating a file with an LLM, feed it that
schema. This document covers a few dynamic rules the schema can't fully
express — look for the **"the schema can't fully enforce this"** notes
below.

This format is implemented in
[`lib/src/data/set_json_codec.dart`](../lib/src/data/set_json_codec.dart) and
[`lib/src/data/validation.dart`](../lib/src/data/validation.dart). This
document describes the format exactly as those files implement it — it does
not add or change any fields or rules.

## Top-level structure

```json
{
  "format": "foxstreak-set",
  "version": 1,
  "title": "Familie",
  "description": "Family vocabulary and contacts",
  "createdBy": "Mama",
  "category": "vocab",
  "items": [ /* see below */ ]
}
```

| Field | Required | Type | Notes |
|---|---|---|---|
| `format` | yes | string | Must be exactly `"foxstreak-set"`. |
| `version` | yes | number | Must be exactly `1`. |
| `title` | yes | string | Non-empty after trimming whitespace. |
| `description` | no | string | Defaults to `""` when absent. |
| `createdBy` | yes | string | Free-text name, non-empty after trimming, at most 50 characters. Any name works (e.g. `"Mama"`, `"Ms. Smith"`) — it is not restricted to a fixed role list. |
| `category` | no | string | One of `vocab`, `general`, `math`, `geography`. Defaults to `vocab` when absent. |
| `id` | no | string | A UUID identifying "this set", independent of where it's hosted (issue #101). See [Identity](#identity-id) below. |
| `items` | yes | array | The questions in this set, see below. |

### `category` values

`category` is a hint used for icon/color choices in the app, not a strict
subject boundary:

- `vocab` — vocabulary / translation pairs (the default).
- `general` — general-knowledge questions that aren't vocab, math, or
  geography.
- `math` — arithmetic facts (e.g. multiplication tables).
- `geography` — places, capitals, etc.

## Item types

Every item has a `type`, a `prompt` (the question text) and an `answer`
(the expected response). What else is allowed depends on `type`:

| Type | `choices` | `promptLang`/`answerLang` | `hint` | `imageType`/`imageContent` | Typical use |
|---|---|---|---|---|---|
| `choice` | optional | optional (paired) | optional | optional (paired) | Multiple-choice question |
| `freeText` | **not allowed** | optional (paired) | optional | optional (paired) | Type-the-answer question |
| `phone` | **not allowed** | **not allowed** | optional | optional (paired) | A phone number to memorize |
| `date` | **not allowed** | **not allowed** | optional | optional (paired) | A date to memorize |

`hint` is optional on every type; when present it's shown as a small nudge
next to the question. Omit it or leave it `""` for no hint.

`imageType`/`imageContent` are optional on every type — see
[Images](#images-imagetypeimagecontent) below.

Every item may also optionally carry an `id` — see [Identity](#identity-id)
below.

### `choice` — multiple choice

```json
{
  "type": "choice",
  "prompt": "Hund",
  "answer": "dog",
  "promptLang": "de",
  "answerLang": "en",
  "choices": ["cat", "mouse", "bird"],
  "hint": ""
}
```

- `choices` is **optional**, even for `choice` items. When present, it's a
  list of non-empty strings — these are the wrong-answer distractors shown
  alongside `answer`. When absent, the app picks distractors from other
  items in the same set instead (see
  `demo_bundeslaender.foxstreak.json` in `assets/seed/` for a real example
  of this — 16 capitals, no explicit `choices` anywhere, each item borrows
  its 3 wrong options from the other 15).
  The borrowed options are ordered by what the learner did in the current
  session: answers of items they missed or skipped come first, then
  answers not yet answered, and answers they already got right come last
  (only used when there are too few others). "Redo missed items" rounds
  follow the same rule. Authored `choices` always take priority.
- `promptLang`/`answerLang` are optional — see [Language codes](#language-codes-promptlanganswerlang)
  below.

### `freeText` — type the answer

```json
{
  "type": "freeText",
  "prompt": "Katze",
  "answer": "cat",
  "promptLang": "de",
  "answerLang": "en"
}
```

- Same rules as `choice` except `choices` is **forbidden** — a `freeText`
  item with a `choices` field is rejected.
- Grading trims whitespace, strips at most one trailing `. , ! ?`, then
  compares case-insensitively. Umlauts (`ä ö ü`) and `ß` are never folded to
  their non-umlaut equivalent — they must match exactly.

### `phone` — a phone number to memorize

```json
{
  "type": "phone",
  "prompt": "Mama",
  "answer": "01711234567"
}
```

- No `promptLang`/`answerLang`, no `choices`.
- `answer` may be written with separators (spaces, `-`, `/`, `(`, `)`, `.`,
  `+`) for readability — e.g. `"+49 171 123 4567"` or `"0171-123-4567"` — but
  after stripping those characters it must be **3 to 15 digits**. The
  stored/exported form is always the stripped digits-only string (so a
  German number keeps its leading `0`, e.g. `01711234567`).

### `date` — a date to memorize

```json
{
  "type": "date",
  "prompt": "Mamas Geburtstag",
  "answer": "1985-05-14"
}
```

- No `promptLang`/`answerLang`, no `choices`.
- `answer` must be a strict ISO `YYYY-MM-DD` string, and must fall between
  `1900-01-01` and **today's date** (inclusive). **The schema can't fully
  enforce this**: it checks the `YYYY-MM-DD` shape, but not that the date is
  a real calendar day (e.g. not `2024-02-30`) or that it's not in the
  future — both are checked when the file is imported.

### Language codes (`promptLang`/`answerLang`)

Only `choice` and `freeText` items may have these fields, and only as a
pair:

- Omit **both** for a prompt that isn't a language-translation pair (e.g.
  a general-knowledge or math question — see
  `demo_times_tables.foxstreak.json`, which has no language fields at all).
- Or set **both** to distinct codes from the currently supported set: `de`
  (German) and `en` (English). `promptLang` and `answerLang` must differ
  from each other.

Setting only one of the two, or using an unsupported code (e.g. `"fr"`), is
rejected. The schema enforces all of this exactly (it's expressed as three
alternatives: both absent, or `de`→`en`, or `en`→`de`).

### Images (`imageType`/`imageContent`)

Any item type may optionally carry a prompt-side image, attached to the
**prompt** only (never the answer or distractor choices):

```json
{ "imageType": "emoji", "imageContent": "🐶" }
```

- Both fields must be set **together** — one without the other is rejected.
- `imageType` is one of:
  - `emoji` — `imageContent` is the literal emoji/symbol string (any
    non-empty string; not restricted to a single grapheme).
  - `base64` — `imageContent` is base64-encoded image data. Whitespace
    (including a multi-line paste, e.g. from the `base64` CLI, which wraps
    at ~76 characters) is stripped before decoding, so it doesn't need to
    be a single line.
  - `url` — `imageContent` is an `http://` or `https://` URL. **The schema
    can't fully enforce this** — it accepts any non-empty string; the app
    checks the scheme and host at import time.
- `url` needs network access to load and isn't guaranteed to work offline —
  bundled seed sets (`assets/seed/`) only ever use `emoji`/`base64` for this
  reason. `url` is fine for sets you create yourself.

### Image copyright (`imageCopyright`)

An item may optionally carry a short copyright/credit line alongside a
`base64` or `url` image (issue #094):

```json
{
  "imageType": "url",
  "imageContent": "https://example.com/fox.png",
  "imageCopyright": "© Jane Doe"
}
```

- Optional; unlike `imageType`/`imageContent`, it's **one-sided** — an image
  may exist without a copyright, but a copyright may never exist without a
  `base64`/`url` image. It's rejected on `emoji` items (a system glyph has
  no meaningful copyright) and on items with no image at all.
- When present, must be a single line (no `\n`), non-empty after trimming,
  and at most 120 characters.
- Rendered as a small, right-aligned caption below the image — on the
  lesson exercise card and the full-screen view it opens, not on the
  compact set-detail/library thumbnail (too small to fit a caption).

### Identity (`id`)

The top-level set `id` and each item's `id` are optional UUID strings
(issue #101):

```json
{
  "id": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
  "items": [
    { "id": "a1b2c3d4-0000-4000-8000-000000000001", "type": "choice", "...": "..." }
  ]
}
```

- Both must be a valid UUID when present: RFC 4122 shape (the standard
  8-4-4-4-12 hex-with-hyphens grouping), case-insensitive — version/variant
  nibbles aren't checked, so v4/v5/etc. all work.
- Both are **absent on hand-created/legacy sets** — the app never generates
  one for a set you create or edit by hand. Same opt-in pattern as
  `imageCopyright`.
- They exist for the [Marketplace](marketplace-api.md) feature: a
  marketplace set is expected to always set both, so a later re-import of a
  changed set can tell which items are unchanged (matched by `id`, keeping
  their practice history) from which are new or edited (no match, starting
  with no history). A plain file import (this document) accepts and stores
  them too, but doesn't otherwise act on them.
- The app does not cross-validate a set's own `id` against anything else —
  see [`marketplace-api.md`](marketplace-api.md)'s "Out of scope" for the
  one place this matters.

## A complete multi-item example

```json
{
  "format": "foxstreak-set",
  "version": 1,
  "title": "Familie",
  "description": "Family vocabulary and contacts",
  "createdBy": "Mama",
  "category": "vocab",
  "items": [
    {
      "type": "choice",
      "prompt": "Hund",
      "answer": "dog",
      "promptLang": "de",
      "answerLang": "en",
      "choices": ["cat", "mouse", "bird"],
      "hint": "",
      "imageType": "emoji",
      "imageContent": "🐶"
    },
    {
      "type": "freeText",
      "prompt": "Katze",
      "answer": "cat",
      "promptLang": "de",
      "answerLang": "en"
    },
    {
      "type": "phone",
      "prompt": "Mama",
      "answer": "01711234567"
    },
    {
      "type": "date",
      "prompt": "Mamas Geburtstag",
      "answer": "1985-05-14"
    }
  ]
}
```

More real examples ship with the app in `assets/seed/*.foxstreak.json`.

## Validation rules / common rejection reasons

A file is rejected (import fails with an error message, no partial import)
when any of these hold. These are the reasons you'll most likely hit when
hand-writing or AI-generating a file:

- `format` isn't exactly `"foxstreak-set"`, or `version` isn't exactly `1`.
- `title` is missing, not a string, or empty after trimming.
- `createdBy` is missing, empty after trimming, or longer than 50 characters
  after trimming.
- `category` is present but isn't one of `vocab`/`general`/`math`/`geography`.
- `items` isn't a list, or any entry in it isn't an object.
- An item's `type` isn't one of `choice`/`freeText`/`phone`/`date`.
- An item's `prompt` or `answer` is missing or empty after trimming.
- `choices` is present on a `freeText`, `phone`, or `date` item — **it's
  `choice`-only.**
- `promptLang`/`answerLang` is set on a `phone` or `date` item.
- Only one of `promptLang`/`answerLang` is set on a `choice`/`freeText` item
  (they must be set together), or the value isn't `de`/`en`, or they're
  equal to each other.
- A `phone` item's `answer` isn't 3–15 digits after stripping separators
  (spaces, `-`, `/`, `(`, `)`, `.`, `+`). **The schema can't fully enforce
  this** — it accepts any non-empty string, since the digit count depends on
  stripping first.
- A `date` item's `answer` isn't a valid `YYYY-MM-DD` calendar date, or is
  before `1900-01-01`, or is after today. **The schema can't fully enforce
  this** — it only checks the `YYYY-MM-DD` shape, not the day's validity or
  the dynamic "not in the future" bound.
- Only one of `imageType`/`imageContent` is set (they must be set together),
  `imageType` isn't `emoji`/`base64`/`url`, or `imageContent` doesn't fit
  that type (e.g. `base64` content that isn't decodable, or a `url` that
  isn't a valid `http`/`https` link). **The schema can't fully enforce
  this** — it accepts any non-empty `imageContent` string.
- `imageCopyright` is set but `imageType` isn't `base64`/`url` (e.g. it's
  `emoji` or absent), or it's empty after trimming, multi-line, or longer
  than 120 characters.
- A set or item `id` is present but isn't a valid UUID (RFC 4122 shape).

Unknown fields are currently ignored by the app (not rejected) at both the
set level and the item level. The schema is stricter than the app on
purpose — it sets `additionalProperties: false` everywhere, so a typo like
`"anwser"` instead of `"answer"` is caught by schema validation even though
the app itself would silently drop it.

Importing a file always creates a **new** set with fresh ids — it never
overwrites an existing set, even if the title matches one you already have.
