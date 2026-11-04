# Issue 103: Hero animation for question images expanding to full screen

Status: done | Priority: P3 | Type: enhancement | Refined-at: 2026-11-03 | Completed-at: 2026-11-04

## Context

`FoxQuestionImage` (issue #094) renders a lesson question's prompt image
and, for `base64`/`url` images, makes it tappable to open
`FoxFullScreenImageViewer` via a plain `MaterialPageRoute` push. Today
that's a flat transition — the full-screen view just fades/slides in with
no visual connection to the image the user tapped; it pops back the same
way (tap the image, or platform back).

Issue #100 already added a Hero animation elsewhere in the app (the
equipped pet flying between Home and Pet Collection) and established the
app's convention for this kind of transition: the moving element is
wrapped in a `Hero`, and when the OS-level reduce-motion accessibility
setting is on, the transition is instant instead — no bespoke in-app
toggle. This issue applies that same idea to the question-image expand.

Only one `FoxQuestionImage` is ever mounted at a time (the lesson screen
swaps a single exercise card in place, not a `PageView` with several kept
alive), so there's no ambiguity about which image instance is flying.

## Goal

When a question image is tapped to expand, it should visually grow/move
from its position and size on the question card into its position and
size on the full-screen view — and shrink back the same way when the
full-screen view is closed — instead of the full-screen view just
appearing/disappearing in place.

## Decisions (from clarifying discussion)

- **Reduce motion**: when the OS reduce-motion accessibility setting is
  on, the transition is instant in both directions — no flight animation
  — matching the `FoxPet`/`FoxProgressBar`/#100 convention rather than
  introducing a new one.
- **Scope**: only `FoxQuestionImage`'s existing tap-to-expand (`base64`/
  `url` images, per #094) gets this animation. The separate, non-
  interactive `FoxItemImage` thumbnail (set-detail/library rows) is not
  touched — it stays as-is.
- **What animates**: just the image itself. The copyright caption bar
  below it (when set) is not part of the Hero — it appears on the
  full-screen view as a normal element (e.g. fading in with the rest of
  the page), not flying in alongside the image.
- **Works regardless of load state**: the image's box — whatever it's
  currently showing at the moment of the tap (a loading spinner, the
  loaded image, or a failed/retry placeholder for a `url` image) — still
  flies to the same box on the full-screen view. The user shouldn't have
  to wait for a `url` image to finish loading before the animated
  transition works; position/size continuity holds in every state.

## Acceptance criteria

1. Tapping an expandable question image visually carries it into its
   full-screen position/size as the full-screen view transitions in.
2. Closing the full-screen view (tapping the image, platform back button,
   or back gesture) visually carries the image back into its question-card
   position/size as the view transitions out.
3. The copyright caption bar (when present) is not part of the flying
   element; it appears on the full-screen view as a normal page element.
4. The animated transition works the same way regardless of whether the
   image is currently loading, loaded, or showing a failed/retry
   placeholder.
5. With the OS reduce-motion accessibility setting enabled, the
   transition is instant in both directions — no flight animation.
6. No change to tap targets, the full-screen view's existing close
   behavior, or any other element on either screen.

## Out of scope

- `FoxItemImage` thumbnails (set-detail/library rows) — not interactive
  today, not made interactive by this issue.
- Any interactive zoom/pan in the full-screen view — out of scope per
  #094, unchanged here.
- Changing what counts as an expandable image (still `base64`/`url` only,
  per #094).

## Summary

Added a shared, constant Hero tag in `fox_question_image.dart`, wrapping
the card's tappable image box and the full-screen viewer's image in it
(bypassed via `MediaQuery.disableAnimationsOf`, mirroring #100's
convention) — a single match on each side of the push/pop, since only
one `FoxQuestionImage` is ever mounted at a time. Both Hero endpoints
also got a matching `ClipRRect(FoxRadius.md)` so Flutter's default
flight shuttle (always the destination's child) doesn't visibly snap
corners square/round at the start of the flight. No screenshots: this is
purely an animated transition, no new static visuals (goldens
unchanged).

## Code review

- Hero endpoints had mismatched decoration (card: `ClipRRect` + fixed
  box; full-screen: bare image) — Flutter's default flight shuttle
  always renders the destination's child, so corners would visibly snap
  square/round at the start of the flight.
  Fixed: full-screen viewer's image now gets the same `ClipRRect(FoxRadius.md)`.
- `_wrapQuestionImageHero`'s reduce-motion-bypass logic duplicates
  `pet_hero.dart`'s `wrapEquippedPetHero` (#100) 3-line pattern verbatim.
  Not fixed here: spans two already-shipped, unrelated files; split out
  as issue #105 instead.
