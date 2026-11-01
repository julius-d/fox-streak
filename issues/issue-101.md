# Issue 101: Marketplace — browse and import question packs from external sources

Status: open | Priority: P2 | Type: feature | Refined-at: 2026-11-01

## Context

Today the only way to get a set into FoxStreak's Library is to create one by
hand or import a single `.foxstreak.json` file someone shared with you
(`newSetFab` speed-dial on `LibraryScreen`: "New set" + "Import", #074). There
is no way to discover ready-made content.

This issue adds a third option, **Marketplace**, that lets a user browse and
import sets published by someone else over plain HTTP GET — no account,
no backend we have to run. A "marketplace" is just something that answers a
small, static, read-only API; it could be a hand-written GitHub Pages site
publishing JSON files, or a real server later. Because it's GET-only and
static-friendly, a marketplace is also something third parties (e.g. a
teacher, a language-learning content creator) could publish themselves.

## Goal

Add a **Marketplace** entry point next to "New set" / "Import" that lets a
user:

1. Add one or more marketplace sources by URL.
2. Browse a chosen marketplace's **Packs** (a named grouping of sets, e.g.
   "English for Germans — Level 1").
3. Browse the **Sets** inside a Pack (title, description, item count,
   category).
4. Preview a Set and add it to their Library, or update a Set they already
   imported earlier if the marketplace's copy has changed.

## Decisions (from clarifying discussion)

- **Naming:** the grouping of sets within a marketplace is called a **Pack**.
- **Multiple sources:** this is not a single built-in marketplace URL — the
  user can add any number of marketplace sources (by URL), similar to adding
  a podcast feed. The Marketplace entry screen lists the sources the user has
  added (plus an "add a marketplace" action); picking one drills into that
  source's Packs. There is no merged cross-source list.
- **Browsing depth:** Marketplace source → its Packs → a Pack's Sets → a
  Set's preview. Each level is a simple list (title + short description,
  no search/filter/rating for this MVP).
- **Preview before import:** tapping a Set never imports immediately. It
  opens a preview (title, description, creator, category, item count) with
  an explicit "Add to Library" action.
- **Updating a previously-imported Set:** a user can come back to a Set in
  the Marketplace and get a newer version if the publisher changed it.
  - Update availability is only surfaced when the user browses back to that
    Set in the Marketplace (no proactive badge in the Library itself).
  - If the locally-imported copy was edited since import (title/items
    changed), updating warns the user first that this will overwrite their
    local edits, instead of silently discarding them.
  - Where items match between the old and new version (see the new `id`
    field below), the learner's progress/attempt history for those items is
    kept; only new or changed items start with no history.
- **Images:** Set JSON may reference images by URL (already supported by the
  existing `imageType: "url"` share format, #094) so a marketplace can host
  images alongside its JSON on the same static site — no new image pipeline
  needed.
- **Item identity (format change):** the share format gains a new **optional**
  per-item `id` field (any non-empty string, publisher-assigned, unique
  within the set). It's what lets the app tell "the same item" apart across
  two versions of a marketplace set, so an update can keep progress for
  items that didn't change and only reset progress for items that are new
  or genuinely edited. Absent on hand-created/legacy sets (backward
  compatible, same opt-in pattern as `imageType`/`imageCopyright`); a
  marketplace Set is expected to always set it so updates work as intended.
  Matching an item across versions without this field falls back to "no
  match" (treated as a new item) — the app does not try to guess sameness
  from content. **This needs `docs/question-set-format.md` and
  `docs/question-set.schema.json` updated as part of this issue.**
- **Managing sources:** "add a marketplace" (enter a URL) and removing a
  previously-added one both live directly on the Marketplace browse screen
  — no separate Settings section.
- **Set preview action:** a single contextual primary button: "Add to
  Library" (never imported before), "Update" (imported before and the
  marketplace copy changed), or a disabled "Already up to date" state
  (imported before, unchanged).
- **Error handling (MVP):** no offline caching of marketplace listings.
  A failed fetch (no network, broken/unreachable source, bad response) shows
  an error message in place of the list/preview, matching today's
  `importFailed`-snackbar level of effort; the user retries by navigating
  back and re-entering.

## Marketplace API (v1)

Three plain `GET`s, each returning JSON, each resource pointing at the next
via an explicit `url` (absolute, or relative to the URL it was fetched
from) — so a publisher is free to lay files out however they like (one
flat folder or a nested structure) and the app never has to guess a path.
No auth, no query params, no pagination in v1 — catalogs are expected to
be small/hand-maintained. A non-200 response or invalid JSON at any step is
a fetch error (see "Error handling" above).

**1. Marketplace manifest** — the URL the user types in when adding a
source, e.g. `https://example.github.io/my-marketplace/marketplace.json`:

```json
{
  "format": "foxstreak-marketplace",
  "version": 1,
  "name": "Jane's FoxStreak Packs",
  "description": "Language packs for German-speaking families",
  "packs": [
    {
      "id": "english-for-germans",
      "title": "English for Germans",
      "description": "Vocabulary packs for German speakers learning English",
      "url": "packs/english-for-germans.json"
    }
  ]
}
```

**2. Pack listing** — fetched from a pack's `url`:

```json
{
  "format": "foxstreak-pack",
  "version": 1,
  "title": "English for Germans",
  "description": "Vocabulary packs for German speakers learning English",
  "sets": [
    {
      "id": "level-1-animals",
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

**3. Set** — fetched from a set's `url`: exactly today's existing
`.foxstreak.json` v1 payload (#002/#094), unchanged except items may now
carry the new optional `id` field (see Decisions above). Images referenced
inside it with `imageType: "url"` are expected to live on the same static
host.

**Identity:** `packs[].id` is unique within a manifest; `sets[].id` is
unique within a pack. The app's "already imported" / "update available" /
"already up to date" check (Decisions above) is keyed on
`(marketplace URL, pack id, set id)`, comparing the listing's `updatedAt`
against the value stored at the set's last import/update.

**`format`/`version` envelopes** on the manifest and pack listing mirror
the existing Set format's self-describing convention — lets the app reject
a URL that isn't a FoxStreak marketplace with a clear error instead of a
confusing parse failure, and leaves room for a future v2 without breaking
v1 publishers.

## Out of scope

- Standing up any real marketplace server or publishing actual content —
  this issue is about the in-app browse/import experience only.
- Search, ratings, reviews, curation, or recommendations within a
  marketplace.
- Authentication/paid content/monetization.
- A merged "all sources" view — sources are browsed one at a time.
- Any proactive "update available" notification on the Library screen.

## Acceptance criteria

- [ ] `LibraryScreen`'s `newSetFab` speed-dial gains a third mini-FAB,
      "Marketplace", alongside today's "New set" and "Import" (#074).
- [ ] Tapping it opens a Marketplace screen listing the user's added
      sources (empty state + "add a marketplace" action when there are
      none yet); adding/removing a source happens on this screen.
- [ ] Picking a source shows its list of Packs; picking a Pack shows its
      list of Sets (title, description, item count, category per Set).
- [ ] Picking a Set opens a preview (title, description, creator, category,
      item count) with one contextual primary action: "Add to Library",
      "Update", or a disabled "Already up to date".
- [ ] "Add to Library" downloads and validates the Set JSON (same
      validation as today's file import, #008) and creates a new local
      set; a validation/network failure shows an error message, no partial
      import.
- [ ] "Update" on a locally-edited set shows a confirmation warning before
      overwriting; on confirm, items matching by the new `id` field keep
      their attempt/progress history, items without a match start fresh.
- [ ] The app records, per locally-imported marketplace set, the
      `(marketplace URL, pack id, set id, updatedAt)` it was imported/
      updated at, so a later visit can tell new / update-available /
      already-up-to-date apart per the Marketplace API section above.
- [ ] `docs/question-set-format.md` and `docs/question-set.schema.json` are
      updated to document the new optional per-item `id` field (including
      that it's absent-by-default/backward-compatible, same pattern as
      `imageCopyright`).
- [ ] A new `docs/marketplace-api.md` documents the Marketplace API (v1)
      section above (manifest/pack/set shapes, the `url`-linking and
      identity/update rules), in the same style as
      `docs/question-set-format.md`, so a third party can implement a
      marketplace from the doc alone.
- [ ] New user-visible strings go through `lib/l10n` (DE + EN), none
      hardcoded, per AGENTS.md.
- [ ] New widgets reuse the existing kit (#015) — no ad-hoc buttons/dialogs
      for the preview action, confirmation warning, or empty states.
