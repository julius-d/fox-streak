# FoxStreak Marketplace API (v1)

A **marketplace** is a small, static, read-only HTTP API that lets a
FoxStreak user discover and import ready-made [question
sets](question-set-format.md). It's deliberately simple enough that a
hand-written static site (e.g. GitHub Pages) can be one — no account, no
backend to run, no write operations. This document describes the API
exactly as [`lib/src/marketplace/marketplace_client.dart`](../lib/src/marketplace/marketplace_client.dart)
implements it, so a third party (a teacher, a language-learning content
creator, ...) can publish one from this document alone.

## Shape

Three plain `GET`s, each returning JSON, each resource pointing at the
next via an explicit `url` **relative to the URL it was fetched from**:

```
Marketplace manifest  (user-typed URL)
  └─ packs[].url  →  Pack listing
       └─ sets[].url  →  Set  (today's .foxstreak.json format, see
                              question-set-format.md)
```

A publisher is free to lay files out however they like — one flat folder
or a nested structure — because every `url` is resolved against the
document it came from, never against a fixed convention.

No auth, no query params, no pagination in v1 — catalogs are expected to
be small and hand-maintained. A non-200 response, invalid JSON, or an
unexpected `format`/`version` at any step is a fetch error: the app shows
a generic error message in place of the list/preview; there's no retry or
offline cache in v1 — the user retries by navigating back and re-entering.

## Security: `url` must be relative

**`packs[].url` and `sets[].url` must be relative** (resolved against the
document they were fetched from, using standard relative-URL resolution).
An absolute URL (has a scheme, e.g. `https://...`) or a protocol-relative
one (starts with `//...`) is rejected as a fetch error, not followed.

The manifest URL the user explicitly types in when adding a source is the
only trust anchor. Relative-only resolution keeps every subsequent fetch
on that same origin (scheme + host + port), so a manifest can never
silently redirect the app to fetch from a different, unapproved host.

This doesn't affect a Set's own `imageType: "url"` image field — that's a
separate, already-absolute-URL mechanism (see
[question-set-format.md](question-set-format.md#images-imagetypeimagecontent)),
unchanged by this API.

## 1. Marketplace manifest

Fetched from the URL the user types in when adding a source, or from that
URL + `/marketplace.json` if it doesn't already end in `.json` (inserting
the `/` only if the input doesn't already end with one) — a single,
deterministic rule applied before any network call, not a
try-then-fallback. E.g. a user entering `https://example.github.io/my-marketplace`
fetches `https://example.github.io/my-marketplace/marketplace.json`.

```json
{
  "format": "foxstreak-marketplace",
  "version": 1,
  "name": "Jane's FoxStreak Packs",
  "description": "Language packs for German-speaking families",
  "packs": [
    {
      "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
      "title": "English for Germans",
      "description": "Vocabulary packs for German speakers learning English",
      "url": "packs/english-for-germans.json"
    }
  ]
}
```

| Field | Required | Type | Notes |
|---|---|---|---|
| `format` | yes | string | Must be exactly `"foxstreak-marketplace"`. |
| `version` | yes | number | Must be exactly `1`. |
| `name` | yes | string | Non-empty after trimming; shown as this source's display name. |
| `description` | no | string | Defaults to `""` when absent. |
| `packs` | yes | array | Each entry: `id` (UUID, required), `title` (non-empty string, required), `description` (string, optional, defaults to `""`), `url` (relative URL, required). |

## 2. Pack listing

Fetched from a pack's `url` (resolved against the manifest's own URL).

```json
{
  "format": "foxstreak-pack",
  "version": 1,
  "id": "c56a4180-65aa-42ec-a945-5fd21dec0538",
  "title": "English for Germans",
  "description": "Vocabulary packs for German speakers learning English",
  "sets": [
    {
      "id": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
      "title": "Animals",
      "description": "Basic animal vocabulary",
      "category": "vocab",
      "itemCount": 12,
      "updatedAt": "2026-10-01",
      "url": "sets/level-1-animals.foxstreak.json"
    }
  ]
}
```

| Field | Required | Type | Notes |
|---|---|---|---|
| `format` | yes | string | Must be exactly `"foxstreak-pack"`. |
| `version` | yes | number | Must be exactly `1`. |
| `id` | **yes** | string | UUID. Unlike the Set's own `id` (optional, see below), this one is required — this document type is new in this API, so there's no legacy-file backward-compatibility concern. Expected to equal the manifest's `packs[].id` entry for this pack (not cross-validated, see "Out of scope"). |
| `title` | yes | string | Non-empty after trimming. |
| `description` | no | string | Defaults to `""` when absent. |
| `sets` | yes | array | Each entry, see below. |

Each `sets[]` entry:

| Field | Required | Type | Notes |
|---|---|---|---|
| `id` | yes | string | UUID, unique within the pack. Expected to equal the fetched Set file's own top-level `id` (not cross-validated, see "Out of scope"). |
| `title` | yes | string | Non-empty after trimming. |
| `description` | no | string | Defaults to `""` when absent. |
| `category` | no | string | One of `vocab`/`general`/`math`/`geography` (same values as [question-set-format.md](question-set-format.md)); defaults to `vocab` when absent. Display-only metadata for the Sets list — the Set file's own `category` is what's actually imported. |
| `itemCount` | yes | number | Display-only item count for the Sets list. |
| `updatedAt` | yes | string | Opaque version string (e.g. an ISO date) — never parsed as a date by the app, only compared for equality. See "Identity and updates" below. |
| `url` | yes | string | Relative URL (resolved against the pack listing's own URL) to the Set file. |

## 3. Set

Fetched from a set's `url` (resolved against the pack listing's own URL):
exactly today's [`.foxstreak.json` v1 format](question-set-format.md),
unchanged by this API — including its optional top-level `id` and
per-item `id` fields (see that document's
[Identity](question-set-format.md#identity-id) section), which a
marketplace set is expected to always set so updates work as intended.
Images referenced inside it with `imageType: "url"` are expected to live
on the same static host as the Set file.

## Identity and updates

The app's "already imported" / "update available" / "already up to date"
state for a given marketplace Set is keyed on the triple
`(marketplace URL, pack id, set id)` — the pack listing's `sets[].id`, not
the Set file's own top-level `id` (see "Out of scope" below) — and
compares the pack listing's current `sets[].updatedAt` against the value
stored at the set's last import/update:

- No stored value yet → **not imported** (the preview screen's primary
  action is "Add to Library").
- Stored value equals the current `updatedAt` → **already up to date**
  (primary action disabled).
- Stored value differs → **update available** (primary action is
  "Update").

On "Update", the app matches the newly-fetched Set's items against the
locally-imported ones by their per-item `id` (see
[question-set-format.md](question-set-format.md#identity-id)): a matched
item is updated in place, keeping its practice history; an item with no
match (new, or the publisher dropped its `id`) starts fresh, with no
history. If the user edited their local copy since the last
import/update, the app warns before overwriting those edits.

## Out of scope (v1)

- The app does **not** cross-validate that a manifest's `packs[].id`
  matches the fetched Pack listing's own top-level `id`, or that a pack
  listing's `sets[].id` matches the fetched Set's own top-level `id` — the
  listing-provided id (from the manifest or pack listing, respectively) is
  always treated as authoritative for identity/update matching.
- Search, ratings, reviews, curation, recommendations.
- Authentication, paid content, monetization.
- A merged "all sources" view — sources are browsed one at a time.
- Pagination — catalogs are expected to be small enough to list in full.
