# Issue 112: Multiple-choice card — all four options visible with an image

Status: done | Priority: P2 | Type: bug | Refined-at: 2026-11-06 | Completed-at: 2026-11-06

## Goal

On a phone, the multiple-choice question screen with an image pushes the
lower answer options off-screen, so the learner has to scroll to see all
four. The image is the question itself ("Which country is this?", "Which US
state is highlighted?"), so it must never be smaller than it is today. The
layout should make better use of the space instead.

## Desired behavior

- **Image present, portrait:** the whole question (image, prompt, four
  options) is aligned to the top of the screen, with no empty space above
  the image, so all four options are visible without scrolling on the
  reference device (360x800dp, default font size).
- **Image never smaller than today.** Today it is up to 240dp tall (less if
  the image is naturally smaller); that is the floor. If more room is
  available (taller phones), the image grows to use the spare space.
- **Image present, landscape / wide windows:** the app is not
  orientation-locked (iOS allows landscape, Android has no restriction), so
  phone landscape, tablets and resized desktop windows are all in scope.
  Image on one side, prompt and options on the other, so nothing needs
  scrolling at default font size.
- **No image:** the question stays vertically centered as today, but only
  while everything fits without scrolling. If centering would cause
  scrolling (large fonts, small screens), align to top instead. Image and
  text-only cards in the same lesson may therefore sit differently; that is
  accepted.
- **No jumping:** the options block does not move when the learner selects
  an option or when the result is revealed. Moving to the next card with an
  image of a different aspect ratio (wide flag vs. tall state outline) must
  not make the options block jump either.
- **When it still doesn't fit** (e.g. 640dp-tall phone, large system font)
  scrolling remains the fallback. CHECK stays pinned and reachable and
  tap-to-enlarge on the image keeps working (both already the case).

## Acceptance criteria

- [ ] Portrait, 360x800dp, default font size, image item: image (>= today's
      size) and all four options are visible without scrolling.
- [ ] Taller phones: the image grows into the spare space; it is never
      smaller than before this change on any screen size.
- [ ] Landscape/wide window: image beside the question/options, no
      scrolling at default font size.
- [ ] Item without an image: centered when it fits, top-aligned when
      centering would require scrolling.
- [ ] No layout shift of the options block on selecting an option, on
      revealing the result, or between cards whose images have different
      aspect ratios.
- [ ] Small phone (e.g. 360x640) and large-font: scrolling works as
      fallback, nothing clipped; dark mode unaffected.
- [ ] Widget tests cover small phone, large phone, wide window and the
      large-font case (top-alignment, unchanged/growing image size,
      centering only when it fits).
- [ ] Follows #015 (kit, no ad-hoc styling; a11y floor: 48dp targets,
      wrapping labels).
- [ ] No question-format change, so no `docs`/schema update needed.

## Out of scope

- Other exercise types (free text, dial pad, date), which already
  top-anchor (#092).
- Changing how the tap-to-enlarge image view works.
- 2x2 option grid or tighter/smaller option buttons.
- Making 360x640 phones fit without scrolling (would need compact
  spacing).

## Summary

- `MultipleChoiceCard` measures its real viewport (LayoutBuilder). With a base64/url image: top-aligned, image grows into spare height (floor 240dp via `FoxQuestionImage(expandToFill)`); landscape/wide (width > height) puts image beside prompt + options. Emoji/no image: centered while it fits.
- No jump: viewport height is frozen after reveal (re-based on width change); option border+padding now sum to a constant size; trimmed first/last option padding and the prompt gap so 360x800 fits exactly.
- Known trade-off: on 360x800 the feedback banner covers the bottom of the options until scrolled.
- Tests: `test/exercises/multiple_choice_layout_test.dart`, kit test, `integration_test/issue112_choice_image_layout_test.dart`. Screenshots: `issue-112-*.png`.

## Code review

- Frozen viewport height went stale on rotation/resize after reveal.
  Fixed: width change re-bases it; test added.
- Bottom option can be covered by the feedback banner on 360x800.
  Not fixed: inherent to "options must not move"; scrolling is the fallback.
- Claimed reveal test doesn't shrink the viewport.
  Not valid: the test shell adds a 72dp banner on reveal.
- Trailing 12dp spacer under the image in wide mode (cosmetic).
  Not fixed: negligible.
- `expandToFill` floor relies on an enclosing `IntrinsicHeight`.
  Fixed: documented on the parameter.
