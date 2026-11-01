# Issue 094: Image copyright caption + full-screen view

Status: done | Priority: P2 | Type: feature | Refined-at: 2026-10-31 | Completed-at: 2026-11-01

## Goal
Extend #014's question images with an optional short copyright/credit
notice per image, and let the user tap an image to view it full-screen,
with the same credit shown below it there too.

## Context
#014 (open, dependency) adds optional images (`emoji` / `base64` / `url`)
to item prompts, rendered via a shared `FoxItemImage` widget reused across
exercise cards, the library list, and set detail. This issue extends that
same widget with a credit line and a tap-to-expand full-screen view.

## Decisions (2026-10-31, with repo owner)
- **Scope**: applies to `base64` and `url` images only — not `emoji` (a
  system glyph has no meaningful copyright, and isn't worth zooming into
  full-screen). `emoji` items get no copyright field and stay non-tappable.
- **Storage**: one new nullable `items` column, `imageCopyright` (text).
  Only ever set when `imageType` is `base64` or `url`; must be `null` when
  `imageType` is `emoji` or `null` (mirrors #014's both-or-neither pattern,
  but one-sided here — copyright implies an image, not the reverse).
- **Content rule**: optional; when present, a single line (no newlines),
  non-empty after trimming, **at most 120 characters**.
- **Inline display**: when set, the copyright renders as small,
  right-aligned text inside a caption bar directly below the image. No
  caption bar at all when unset (not an empty bar).
- **Tap-to-expand**: every `base64`/`url` image is tappable — regardless of
  whether a copyright is set — and opens a new full-screen route showing
  just that image, via a standard page push (not an overlay/dialog), so
  the platform back button/gesture also closes it, in addition to tapping
  anywhere on the image to close.
- **Full-screen caption**: the same caption bar (if a copyright is set)
  renders below the image in the full-screen view too, same styling as
  inline.
- **Caption bar styling**: follows the app's light/dark theme (`FoxStreak
  Theme`/`FoxSemanticColors`), not a fixed black/white bar. Identical
  styling inline and full-screen.
- **No pinch-to-zoom/pan**: the full-screen view is a bigger static image,
  not an interactive zoom viewer. Keeps this issue scoped to the
  caption + expand behavior.
- **Everywhere `FoxItemImage` renders**: exercise cards, library list
  thumbnails, and set-detail rows all get the same tap-to-expand + caption
  behavior, since they share the one widget.
  **Revised during implementation (2026-11-01, with repo owner):** a
  caption bar doesn't fit Material's `ListTile.leading` slot (40px
  thumbnail + caption needs ~64dp; `ListTile` caps leading height at
  48–56dp — confirmed via a real overflow crash). Split into two widgets
  instead: `FoxItemImage` (#014, unchanged) stays the small, square,
  non-interactive thumbnail for set-detail/library rows; a new
  `FoxQuestionImage` (not cropped to square, more room) carries the
  caption + tap-to-expand, used only on the lesson exercise card (and the
  full-screen view it opens). See the Summary below.

## Acceptance criteria
- [x] `items` gains a nullable `imageCopyright` text column via an
  additive migration (next `schemaVersion` after #014's); existing rows
  get `null` (no caption, unchanged rendering).
- [x] `imageCopyright` can only be non-null when `imageType` is `base64`
  or `url`; validation rejects it on `emoji`/`null` image items, rejects
  empty-after-trim, multi-line, and longer-than-120-character values.
- [x] `set_json_codec.dart` import/export round-trips `imageCopyright`;
  missing field in older exported JSON decodes as `null` (backward
  compatible).
- [x] Item editor (#004's `item_editor.dart`): when image type is `base64`
  or `url`, an optional copyright text field appears below the image
  content field; hidden for `emoji`/"none"; inline error on invalid
  content (too long, multi-line); can be cleared back to empty.
- [x] **Revised** (see Decisions): the caption bar + tap target live on a
  new `FoxQuestionImage` widget, not `FoxItemImage` — renders a
  right-aligned caption bar below the image when `imageCopyright` is set
  (themed per #015, light/dark), and wraps `base64`/`url` images in a tap
  target that pushes a new full-screen image-viewer route.
- [x] New full-screen image-viewer screen: shows the image and, if set,
  the same caption bar below it; tapping anywhere on the image closes the
  route; the platform back button/gesture also closes it.
- [x] **Revised** (see Decisions): the caption + tap-to-expand are
  question-card-only (`FoxQuestionImage`, used by exercise cards
  #006–#009) — not on the set-detail/library thumbnail (`FoxItemImage`,
  unchanged from #014, doesn't fit a caption in `ListTile.leading`).
- [x] A11y: the tap target carries a semantic hint that it opens a
  full-screen view; the caption text is included in the image's semantic
  label alongside the existing `prompt`-based label from #014.
- [x] Follows #015: kit tokens/spacing for the caption bar, no ad-hoc
  styling; all new UI-chrome strings (not the user-entered copyright text
  itself) via `lib/l10n` arb params (DE + EN).
- [x] `docs/question-set-format.md` and `docs/question-set.schema.json`
  are updated to document the new optional `imageCopyright` field
  alongside whatever #014 already documented for `imageType`/
  `imageContent` (coordinate with #014's own doc update if it lands
  first).
- [x] Unit + widget tests green (see Tasks).

## Tasks
1. Schema: add `items.imageCopyright` (nullable text) via the next
   migration after #014's; update `database.dart`'s migration doc comment.
2. `validation.dart`: `isValidImageCopyright` (length, single-line,
   non-empty-after-trim) + the image-type pairing rule.
3. `set_json_codec.dart`: encode/decode `imageCopyright`; backward-compat
   decode (missing → null).
4. Item editor: copyright text field, shown only for `base64`/`url`,
   wired to `SetsRepository.addItem`/`updateItem`.
5. `FoxItemImage`: render the caption bar when set; wrap `base64`/`url`
   images in a tappable region.
6. New full-screen image-viewer screen/route: image + optional caption
   bar, tap-anywhere-to-close, standard back button/gesture support.
7. l10n: arb keys for the editor's copyright field label/placeholder,
   validation error strings, and the expand-view semantic hint (DE + EN).
8. Stable keys for #016: e.g. `itemImageCopyrightField`,
   `fullScreenImageView`.
9. Docs: update `docs/question-set-format.md` + `question-set.schema.json`
   for `imageCopyright`.
10. Tests: validation unit tests (length/pairing/multi-line), JSON codec
    round-trip + backward-compat decode, item editor widget tests (set/
    clear, hidden for emoji/none, invalid content blocked), `FoxItemImage`
    widget tests (caption bar present/absent, tap opens viewer),
    full-screen viewer widget tests (shows caption, tap/back closes), one
    exercise/library integration test per usage site. Golden tests (#019)
    for the caption bar in light/dark.

## Out of scope
- Copyright or full-screen expand for `emoji` images.
- Pinch-to-zoom/pan in the full-screen view.
- A separate alt-text field — full-screen image reuses the same semantic
  label approach as #014 (prompt text + copyright).
- Any editing-time preview of the full-screen view from inside the item
  editor.

## Dependencies
- Builds on #014 (question images: `imageType`/`imageContent`,
  `FoxItemImage`, item editor image section), which is itself still open.
  This issue's migration targets the schema version right after #014's.
- #015 (kit tokens for the caption bar), #016 (stable widget keys), #019
  (golden tests).

## Verify
```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary
Schema v14 adds `items.imageCopyright` (nullable, one-sided-paired with
`base64`/`url`, ≤120 chars, single line). Split rendering into two
widgets: `FoxItemImage` (#014, unchanged — small square thumbnail, no
caption/tap) for set-detail/library rows, and a new `FoxQuestionImage`
(not cropped to square, more room, caption bar, tap-to-expand) for the
lesson exercise card, which opens the new `FoxFullScreenImageViewer`
route. Item editor gained an optional copyright field (base64/url only).
Screenshots: `issue-094-item_editor_copyright_field.png`,
`issue-094-exercise_card_caption.png`, `issue-094-fullscreen_viewer.png`.

## Code review
- `FoxQuestionImage`'s base64/url image box uses a fixed `width`/`height`
  instead of sizing from the decoded image's intrinsic dimensions.
  No change needed — intentional: a size derived from the real decoded
  `ui.Image` can stay zero-height indefinitely in headless tests (the
  codec `Future` may not resolve within a pump loop); fixed dimensions +
  `BoxFit.contain` keep layout deterministic while still preserving
  aspect ratio (confirmed via a real bug hit during implementation).
- The integration test's set-detail-thumbnail-not-tappable assertion
  originally checked a `Key` (`foxItemImageTapTarget`) that was never
  defined anywhere, making it vacuously true.
  Fixed — now taps the real `FoxItemImage` widget and asserts the
  full-screen viewer does not open.
- JSON Schema's `imageCopyright.maxLength: 120` counts raw (untrimmed)
  string length, while Dart's `isValidImageCopyright` counts post-trim
  length, so a padded string could pass the schema but fail Dart
  validation in a pathological case.
  Not fixed — already disclosed in the schema's own `description` field
  as a known, narrow looseness (consistent with several other
  schema-can't-fully-enforce-this gaps already documented in
  `question-set-format.md`); not worth a schema `allOf`/regex contortion
  for this edge case.
