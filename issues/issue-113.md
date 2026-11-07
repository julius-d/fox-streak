# Issue 113: Restyle image copyright note and full-screen image view

Status: open | Priority: P3 | Type: enhancement | Refined-at: 2026-11-07

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

- [ ] Card: note has no background and sits directly under the image,
      right-aligned to the image's rendered right edge, width capped at
      the image width, ~11sp, muted theme colour.
- [ ] Card: note wraps to max 2 lines with ellipsis; full text in
      semantics; options block does not jump between cards.
- [ ] Full screen: black background in light and dark theme.
- [ ] Full screen: white close button top-left, 48dp target, a11y label
      (DE + EN via l10n); image tap and back still close.
- [ ] Full screen: question in white in its own row below the close
      button, max ~3 lines with ellipsis.
- [ ] Full screen: note in dimmed white directly under the image,
      right-aligned to its real right edge, for portrait and landscape
      images and in both device orientations; hidden while loading, on
      error and on the placeholder.
- [ ] Large system font: no overflow on card or full screen; note still
      max 2 lines.
- [ ] Hero transition between card and full screen still works.
- [ ] Tests updated/added; golden baselines regenerated for the affected
      widgets (macOS locally, Linux via CI per AGENTS.md).
- [ ] Follows #015 (design kit): no ad-hoc colours beyond the explicit
      black/white of the full-screen view; strings via l10n.
- [ ] No question-format or schema change, so no `docs` update needed.

## Out of scope

- Pinch-to-zoom in the full-screen view.
- Changing how the copyright text is edited (#094 editor field).
