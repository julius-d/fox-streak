# Issue 014: Question images (emoji / base64 / url)

Status: open | Priority: P2 | Type: feature | Refined-at: 2026-10-13

## Goal
Items can carry an optional image alongside their prompt — an emoji, an
embedded base64 image, or a remote URL — so questions aren't text-only.
Storage format and content are kept separate (`imageType` + `imageContent`)
so the same shape can grow a renderer later (e.g. lottie, in a follow-up
issue) without another schema migration to the type enum.

## Decisions (2026-10-13, with repo owner)
- Scope split: lottie/animated images are **not** part of this issue.
  AGENTS.md, #010, and #015 all repeat "no lottie dep" (3-platform
  compatibility risk) — adding that dependency is a separate decision.
  Split into #032 (filed alongside this refinement) as a follow-up; this
  issue's `imageType` enum stays **closed** to `emoji | base64 | url` (no
  reserved-but-unimplemented `lottie` value — #032 adds its own enum value
  + migration when/if it lands).
- Storage: two new nullable `items` columns — `imageType`
  (`'emoji' | 'base64' | 'url'`) and `imageContent` (the actual emoji
  string / base64 data / URL, interpreted per `imageType`). Both-or-neither:
  never one set without the other.
- Attachment scope: optional on all 3 item types (choice/freeText vocab,
  phone, date), attached to the **prompt** side only — not the answer or
  distractor choices.
- Offline safety (app is local-only, #013 requires airplane-mode to work):
  bundled seed sets only ever use `emoji` or `base64` — never `url`. A
  `url` image is allowed for user-added items, with a documented tradeoff:
  it needs network to load and isn't guaranteed to work offline. Loading
  failures (offline, broken link) show a placeholder/broken-image state
  instead of crashing or hanging the lesson.
- A11y: no new alt-text field in v1 — the existing `prompt` text doubles as
  the image's screen-reader label.

## Acceptance criteria
- [ ] `items` gains nullable `imageType` (`'emoji' | 'base64' | 'url'`) and
  `imageContent` columns via an additive migration (exact next
  `schemaVersion` TBD at implementation time — see Dependencies); existing
  rows get `null`/`null` (no image, unchanged text-only rendering).
- [ ] Both fields optional, present on all 3 item types, prompt-side only.
- [ ] `set_json_codec.dart` import/export round-trips `imageType` /
  `imageContent`; missing fields in older exported JSON decode as
  `null`/`null` (backward compatible with existing seed/export files).
- [ ] `validation.dart`: both-or-neither pairing enforced; `url` validated
  as a parseable `Uri` with an http/https scheme; `base64` validated as
  decodable; `emoji` accepts any non-empty string (no strict single-
  grapheme requirement — short symbol combos are fine).
- [ ] Item editor (#004's `item_editor.dart`): image section — type
  selector (`emoji` / `base64` / `url` / "none") + a content field
  appropriate to the type; inline error on invalid content; can be cleared
  back to "none"; follows #015 kit (no ad-hoc styling).
- [ ] Exercise cards (#005 lesson shell host, #006–#009 exercise widgets):
  when an item has an image, render it above/alongside the prompt via a new
  shared `FoxItemImage` widget — `emoji` as large inline text, `base64` via
  `Image.memory`, `url` via `Image.network` with loading + graceful
  broken-image/error placeholder (never crashes or hangs the lesson).
- [ ] Library list / set detail (#003): small image thumbnail/indicator
  next to items that have one; existing text-only rows unaffected.
- [ ] Seed content (`assets/seed/`): bundled demo sets use `emoji`/`base64`
  only (never `url`); at least one demo item exercises the new field
  end-to-end; `assets/seed/README.md` documents the offline-safety
  convention.
- [ ] A11y: image carries the item's `prompt` text as its semantic label;
  large-font/dark-mode smoke check per #015's floor.
- [ ] Follows #015: kit tokens/spacing for the new image area, no ad-hoc
  styling; all new strings via `lib/l10n` arb params (DE + EN).
- [ ] Unit + widget tests green (see Tasks).

## Tasks
1. Schema: add `items.imageType` + `items.imageContent` (nullable text) via
   the next migration step; update `database.dart`'s migration doc comment
   + column-ownership note.
2. `validation.dart`: `isValidImageType`, `isValidImageContent`
   (type-specific), both-or-neither pairing check.
3. `set_json_codec.dart`: encode/decode the two new fields; backward-compat
   decode (missing → null).
4. Item editor: image type selector + content field, wired to
   `SetsRepository.addItem`/`updateItem`.
5. New `FoxItemImage` widget (`lib/src/widgets/`): switches on `imageType`,
   renders emoji/base64/url incl. url loading + error states; reused by
   exercises, library, and set detail.
6. Wire `FoxItemImage` into exercise cards (#006–#009) above the prompt,
   and into library/set-detail rows as a thumbnail.
7. Seed content: add/confirm at least one demo item with an image; update
   `assets/seed/README.md` with the emoji/base64-only convention.
8. l10n: arb keys for the editor's image-type labels, "no image" option,
   image-related error strings (DE + EN).
9. Stable keys for #016: e.g. `itemImageTypeField`, `itemImageContentField`.
10. Tests: validation unit tests (per type + both-or-neither), JSON codec
    round-trip + backward-compat decode, item editor widget tests (set/clear
    each type, invalid content blocked), `FoxItemImage` widget tests (3
    render paths + url loading/error state), one exercise/library
    integration test asserting the image renders when present.

## Out of scope
- Lottie/animated images — split into #032; this issue's `imageType` enum
  stays closed (no reserved `lottie` value).
- A separate alt-text field for screen readers — reuses `prompt` text.
- Images on the answer/choices side — prompt-only in v1.
- Remote image caching / guaranteed offline availability for `url` —
  bundled seed content avoids `url` entirely instead.
- Final fox mascot art — owned by #023, not this issue.

## Dependencies
- Builds on #002 (`validation.dart`, `set_json_codec.dart` patterns),
  #003/#004 (item editor + library/detail screens to retrofit), #006–#009
  (exercise cards to retrofit), #015 (kit tokens, `FoxFeedbackBanner` for
  save errors).
- Schema migration must target the next available `schemaVersion` at
  implementation time — #012 also plans a schema bump; whichever lands
  first takes the next version number, the other follows.
- Seed content convention (emoji/base64-only) feeds into #013's QA pass.
- Predecessor to #032 (lottie/animated images), which is blocked on a
  repo-wide decision to accept a lottie dependency.

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```
