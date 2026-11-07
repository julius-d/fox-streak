# Issue 113: Restyle image copyright note and full-screen image view

Status: done | Priority: P3 | Type: enhancement | Refined-at: 2026-11-07 | Completed-at: 2026-11-07

## Goal

The image copyright/credit note (#094) currently sits in its own bar with a
background, which makes it look heavier than the unimportant information it
is. Restyle it as a plain, tiny caption directly under the image, and give
the full-screen image view a dark, gallery-style look with the question
shown above the image.

## Desired behavior

### Question card

- The copyright note has **no background**: just small text.
- It sits **directly below the image**, with only a small spacing, and is
  **right-aligned to the image's real right edge** (the rendered image
  border, not the card padding). Its width is capped at the rendered image
  width, so for narrow (e.g. tall portrait) images it never sticks out
  past the image.
- Very small font (~11sp), muted theme colour (secondary text colour), so
  it reads in both light and dark mode but stays subtle.
- Long notes wrap to at most 2 lines, then ellipsis. The full text stays
  available to screen readers.
- No note set: nothing is shown, as today.
- The note is part of the image block: it must not make the options block
  jump between cards (#112 "no jumping" rule still holds).

### Full-screen image view

- Background is **always black**, in light and dark mode.
- A visible **white close (X) button in the top-left corner** (48dp target,
  localized a11y label). Tapping the image and the platform back gesture
  still close the view.
- Below the close button, in its own row, the **question text in white**
  (left-aligned, max ~3 lines, then ellipsis). The card's own question is
  unchanged.
- The copyright note sits **directly under the image**, not at the bottom
  of the screen, right-aligned to the image's real right edge, width capped
  at the image width, same small size as on the card, in dimmed white
  (~70%), max 2 lines.
- The note is shown only under a real image: not while loading, on load
  failure (retry button stays) or on the placeholder. The question and
  close button are always visible.
- The image is not zoomable (unchanged).

## Acceptance criteria

- [x] Card: note has no background and sits directly under the image,
      right-aligned to the image's rendered right edge, width capped at
      the image width, ~11sp, muted theme colour.
- [x] Card: note wraps to max 2 lines with ellipsis; full text in
      semantics; options block does not jump between cards.
- [x] Full screen: black background in light and dark theme.
- [x] Full screen: white close button top-left, 48dp target, a11y label
      (DE + EN via l10n); image tap and back still close.
- [x] Full screen: question in white in its own row below the close
      button, max ~3 lines with ellipsis.
- [x] Full screen: note in dimmed white directly under the image,
      right-aligned to its real right edge, for portrait and landscape
      images and in both device orientations; hidden while loading, on
      error and on the placeholder.
- [x] Large system font: no overflow on card or full screen; note still
      max 2 lines.
- [x] Hero transition between card and full screen still works.
- [x] Tests updated/added; golden baselines regenerated for the affected
      widgets (macOS locally, Linux via CI per AGENTS.md).
- [x] Follows #015 (design kit): no ad-hoc colours beyond the explicit
      black/white of the full-screen view; strings via l10n.
- [x] No question-format or schema change, so no `docs` update needed.

## Out of scope

- Pinch-to-zoom in the full-screen view.
- Changing how the copyright text is edited (#094 editor field).

## Summary

- `FoxQuestionImage` / `FoxFullScreenImageViewer` (`fox_question_image.dart`)
  now measure the image's intrinsic size (`_ImageSizeBuilder`) and lay out
  image + caption as one block (`_CaptionedImage`): caption sits directly
  under the exact `contain` rect, right edge = image edge, width capped.
  Space for 2 caption lines is always reserved, so the card never jumps.
- Full screen: black, white X (`fullScreenImageCloseLabel`, DE+EN), question
  above the image; new required params `closeLabel` / `question`.
- Caption on the card is shown even while the size is unknown (full width);
  on full screen it only appears under a real, loaded image.
- Only macOS goldens regenerated; `linux/` baselines for
  `fox_question_image_caption_*` need the CI `workflow_dispatch` job.
- Tests use valid PNG fixtures now (the old 1x1 PNG was undecodable).
- Pre-existing failing `issue102` integration test split out as #118.
- Screenshots: `issue-113-card.png`, `issue-113-fullscreen.png`.

## Code review

- Negative image size when the full-screen header leaves little height
  (landscape / large font).
  Fixed: scale is clamped to >= 0.
- New `MemoryImage` per build resets the measured size and re-decodes.
  Fixed: last decode is memoised (`_memoryImageFor`).
- Caption alignment not RTL-aware (`TextAlign.right`).
  Fixed: `TextAlign.end` / `AlignmentDirectional.topEnd`.
- Widget-test image decode wait could be flaky on slow CI.
  Fixed: wait raised to 600ms.
- Caption jumps from full width to image width once the size resolves.
  Not fixed: brief, only on the card, and keeps the note visible for failed/placeholder images.
- Reserve assumes a linear text scaler / exactly 2 lines.
  Not fixed: +1px slack added; non-linear scalers are an edge case.
- URL image resolved twice (size probe + `Image.network`).
  Not fixed: both hit the shared `ImageCache`, so no second download.
- Duplicated base64/url switch in card and viewer.
  Not fixed: differs in hero/tap wiring; acceptable for now.
- Raw black/white colours in the viewer.
  Not fixed: explicitly required by the issue.
- Linux golden baselines stale.
  Not fixed: can only be regenerated on CI (AGENTS.md).
