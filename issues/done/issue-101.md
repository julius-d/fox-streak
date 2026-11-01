# Issue 101: Marketplace — browse and import question packs from external sources

Status: done | Priority: P2 | Type: feature | Refined-at: 2026-11-01 | Completed-at: 2026-11-01

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
- **Item & Set identity (format change):** the share format gains two new
  **optional** UUID fields:
  - a top-level `id` on the Set itself — identifies "this set", independent
    of where it's hosted or which pack lists it.
  - a per-item `id` — identifies "this item" within its set, so an update
    can tell which items are unchanged.

  Both must be a valid UUID when present (RFC 4122 shape — the standard
  8-4-4-4-12 hex-with-hyphens grouping, case-insensitive; version/variant
  nibbles aren't checked, so v4/v5/etc. all work). Both are absent on
  hand-created/legacy sets (backward compatible, same opt-in pattern as
  `imageType`/`imageCopyright`); a marketplace Set is expected to always
  set both so updates work as intended, and its pack listing's `sets[].id`
  (see Marketplace API below) is expected to equal the Set file's own
  top-level `id` — the app doesn't cross-validate this in v1 (see
  Out of scope). Matching an item across versions without the per-item `id`
  falls back to "no match" (treated as a new item) — the app does not try
  to guess sameness from content. **This needs `docs/question-set-format.md`
  and `docs/question-set.schema.json` updated as part of this issue.**
- **Managing sources:** "add a marketplace" (enter a URL) and removing a
  previously-added one both live directly on the Marketplace browse screen
  — no separate Settings section.
- **Adding a source — URL shorthand:** the URL field accepts either the
  full manifest URL (anything ending in `.json`, e.g.
  `https://example.github.io/my-marketplace/marketplace.json`) or a bare
  base URL (anything not ending in `.json`, e.g. `https://example.github.io`
  or `https://example.github.io/my-marketplace`) — for a base URL, the app
  appends `/marketplace.json` (inserting the `/` only if the input doesn't
  already end with one) before fetching. This is a single, deterministic
  rule applied before any network call, not a try-then-fallback — a
  mistyped `.json` filename still surfaces as one normal fetch error (see
  Error handling above), not a confusing double request.
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
via an explicit `url`, **relative to the URL it was fetched from** — so a
publisher is free to lay files out however they like (one flat folder or a
nested structure) and the app never has to guess a path. No auth, no query
params, no pagination in v1 — catalogs are expected to be small/
hand-maintained. A non-200 response, invalid JSON, or a `url` that isn't
relative to the fetched document at any step is a fetch error (see "Error
handling" above).

**Relative-only `url`, for security:** `packs[].url` and `sets[].url` must
be relative (resolved against the document they were fetched from using
standard relative-URL resolution) — an absolute URL (has a scheme, e.g.
`https://`) or a protocol-relative one (starts with `//`) is rejected as a
fetch error, not followed. The marketplace manifest URL the user explicitly
types in when adding a source is the only trust anchor; relative-only
resolution keeps every subsequent fetch on that same origin
(scheme+host+port), so a manifest can never silently redirect the app to
fetch from a different, unapproved host. This doesn't affect the
pre-existing `imageType: "url"` image field inside a Set (#094) — that's a
separate, already-absolute-URL mechanism, unchanged by this issue.

**1. Marketplace manifest** — fetched from the URL the user types in when
adding a source, or from that URL + `/marketplace.json` if it doesn't
already end in `.json` (see "Adding a source — URL shorthand" above), e.g.
`https://example.github.io/my-marketplace/marketplace.json`:

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

**2. Pack listing** — fetched from a pack's `url`. Its top-level `id` is
**required** (not optional like the Set/item ids — this document type is
new in this issue, so there's no legacy-file backward-compatibility
concern) and is expected to equal the manifest's `packs[].id` entry for
this pack:

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

**3. Set** — fetched from a set's `url`: exactly today's existing
`.foxstreak.json` v1 payload (#002/#094), unchanged except it may now carry
a top-level `id` and items may now carry a per-item `id` (both new optional
UUID fields, see Decisions above). Images referenced inside it with
`imageType: "url"` are expected to live on the same static host.

**Identity:** `packs[].id` is unique within a manifest and is a UUID,
expected to equal the Pack listing's own top-level `id` once downloaded.
`sets[].id` is unique within a pack and is a UUID, expected to equal the
Set file's own top-level `id` once downloaded (Decisions above). The app's
"already imported" / "update available" / "already up to date" check is
keyed on `(marketplace URL, pack id, set id)`, comparing the listing's
`updatedAt` against the value stored at the set's last import/update.

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
- Cross-validating that a manifest's `packs[].id` matches the fetched Pack
  listing's own top-level `id`, or that a pack listing's `sets[].id`
  matches the fetched Set's own top-level `id` — the listing-provided id
  (from the manifest or pack listing, respectively) is treated as
  authoritative for identity/update matching in v1.

## Acceptance criteria

- [x] `LibraryScreen`'s `newSetFab` speed-dial gains a third mini-FAB,
      "Marketplace", alongside today's "New set" and "Import" (#074).
- [x] Tapping it opens a Marketplace screen listing the user's added
      sources (empty state + "add a marketplace" action when there are
      none yet); adding/removing a source happens on this screen.
- [x] "Add a marketplace" accepts either a full manifest URL (ends in
      `.json`) or a bare base URL, appending `/marketplace.json` to the
      latter before the first fetch.
- [x] Picking a source shows its list of Packs; picking a Pack shows its
      list of Sets (title, description, item count, category per Set).
- [x] Picking a Set opens a preview (title, description, creator, category,
      item count) with one contextual primary action: "Add to Library",
      "Update", or a disabled "Already up to date".
- [x] "Add to Library" downloads and validates the Set JSON (same
      validation as today's file import, #008) and creates a new local
      set; a validation/network failure shows an error message, no partial
      import.
- [x] `packs[].url` and `sets[].url` are resolved only as relative to the
      document they were fetched from; an absolute (has a scheme) or
      protocol-relative (`//...`) `url` is rejected as a fetch error, not
      followed — no cross-origin fetches beyond the marketplace URL the
      user explicitly added.
- [x] "Update" on a locally-edited set shows a confirmation warning before
      overwriting; on confirm, items matching by the new `id` field keep
      their attempt/progress history, items without a match start fresh.
- [x] The app records, per locally-imported marketplace set, the
      `(marketplace URL, pack id, set id, updatedAt)` it was imported/
      updated at, so a later visit can tell new / update-available /
      already-up-to-date apart per the Marketplace API section above.
- [x] `docs/question-set-format.md` and `docs/question-set.schema.json` are
      updated to document two new optional fields — a top-level Set `id`
      and a per-item `id` — both UUID strings (RFC 4122 shape, case-
      insensitive, version/variant not checked) when present, absent-by-
      default/backward-compatible, same pattern as `imageCopyright`.
- [x] A new `docs/marketplace-api.md` documents the Marketplace API (v1)
      section above (manifest/pack/set shapes, the `url`-linking and
      identity/update rules), in the same style as
      `docs/question-set-format.md`, so a third party can implement a
      marketplace from the doc alone.
- [x] New user-visible strings go through `lib/l10n` (DE + EN), none
      hardcoded, per AGENTS.md.
- [x] New widgets reuse the existing kit (#015) — no ad-hoc buttons/dialogs
      for the preview action, confirmation warning, or empty states.

## Summary

- Schema v16: `Items.marketplaceItemId`, `MarketplaceSources`,
  `ImportedMarketplaceSets` tables. Share format gains optional `id` on
  Set/item (`set_json_codec.dart`, `validation.dart`'s `isValidUuid`).
- New `lib/src/marketplace/` (`marketplace_client.dart` — HTTP fetch +
  relative-url security + envelope validation; 4 screens;
  `marketplace_providers.dart` with an overridable `httpClientProvider`)
  and `lib/src/data/marketplace_repository.dart` (sources CRUD,
  import/update orchestration, item-matching for attempt-history
  preservation on Update).
- `docs/marketplace-api.md` added; `docs/question-set-format.md` +
  `question-set.schema.json` updated for the new `id` fields.
- Added `http` package dependency (pure-Dart, all 4 platforms).
- Tests: unit (validation/codec/sets_repository/marketplace_repository/
  marketplace_client), widget (library speed-dial, marketplace sources
  screen), integration (full browse → add-to-library → update flow,
  `integration_test/issue101_marketplace_test.dart`).

## Code review

- `MarketplaceRepository.updateSet`/`importSet` weren't wrapped in a DB transaction, risking a partially-applied write on failure mid-loop.
  Fixed: both now run inside `_db.transaction()`.
- `_AddMarketplaceSourceDialog._submit`'s error-handling branches called `setState` without a `mounted` guard (dialog can be dismissed while a fetch is in flight).
  Fixed: added `if (!mounted) return;` before each.
- `SetsRepository.duplicateSet` didn't carry over `marketplaceItemId`, unlike every other item-copy path (addItem/import/export).
  Fixed: now threaded through, with a new repository test.
- `MarketplaceClient._fetchJsonObject` rebuilt a new map + re-stringified every key instead of a cheap cast.
  Fixed: uses `decoded.cast<String, dynamic>()`.
- Reviewer also checked relative-URL-only enforcement, the `isLocallyEdited` timestamp comparison, the v15→v16 migration/legacy fixtures, and l10n coverage for hardcoded strings — no issues found in those areas.
