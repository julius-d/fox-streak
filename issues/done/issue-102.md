# Issue 102: Question images sometimes fail to show, with no way to retry

Status: done | Priority: P2 | Type: bug | Refined-at: 2026-11-03 | Completed-at: 2026-11-03

## Context

On the lesson/question screen, the item's image (`FoxQuestionImage`,
#014/#094) sometimes fails to load and shows a permanent broken-image
placeholder, even though the image loads fine moments later — e.g. if the
user leaves the question and comes back, or it shows up correctly the 2nd
or 3rd time the question is presented. This looks like a transient network
hiccup (slow connection, brief server issue, etc.), not a genuinely broken
or missing image: today there's no retry of any kind, so a one-off failure
is shown as permanent until something incidentally causes the image widget
to reload (e.g. revisiting the question).

This affects `url`-type images, i.e. images on user-added items and items
imported via the marketplace (#101) — not `emoji` or `base64` images,
which don't depend on a network fetch.

## Goal

Make question images on the lesson/question screen resilient to transient
load failures, so a temporary hiccup doesn't strand the user on a
permanently broken image:

- When an image fails to load, the app automatically retries a few times
  in the background before giving up, so most transient failures resolve
  on their own without the user noticing anything went wrong.
- If it still hasn't loaded after those automatic attempts, show a clear
  failed-to-load state in place of the image, with a button the user can
  tap to retry manually (as many times as they like).
- The rest of the question (tags, answer input, buttons, etc.) stays fully
  usable while the image is loading, retrying, or failed — none of that
  should be blocked or hidden by an image problem.

## Decisions

- **Scope**: lesson/question screen only — `FoxQuestionImage` and the
  full-screen tap-to-expand viewer it opens. The small thumbnail used in
  set-detail/library list rows (`FoxItemImage`) is out of scope for this
  issue (same underlying problem, but not where the user reported it).
- **Automatic retries**: on a load failure, retry automatically a small,
  fixed number of times (e.g. 3 attempts total) with short, increasing
  delays between them, keeping the total extra wait under a few seconds.
  Only once those automatic attempts are exhausted does the user see a
  failure state.
- **Automatic-retry visuals**: indistinguishable from a normal first-time
  load — the same loading spinner throughout, no "retrying…" indicator.
  Matches the goal that most transient failures resolve without the user
  ever noticing anything went wrong.
- **Failure UI**: the image's normal space is replaced by a lightweight
  placeholder — scoped to just the image area, not the full-screen
  `FoxEmptyState` kit widget — containing a short "couldn't load image"
  message and a tappable retry affordance. This placeholder takes the
  place of the image only — the question prompt text, tags, caption (if
  any), answer input, and all other screen content render normally
  around/below it, exactly as if the image had loaded.
- **Manual retry**: unlimited — the user can tap the retry button as many
  times as needed; there's no final "give up" state beyond the retry
  button itself. Tapping it re-runs the same automatic-retry-then-
  placeholder cycle.

## Acceptance criteria

- [x] A transient image load failure on the lesson/question screen is
  retried automatically a few times before anything is shown to the user.
- [x] If automatic retries don't succeed, the image area shows a
  placeholder with a visible, tappable "retry" affordance, with
  appropriate accessibility labeling (not just a bare icon).
- [x] Tapping retry re-attempts the load; this can be repeated indefinitely.
- [x] While the image is loading, auto-retrying, or in the failed state,
  the rest of the question card (prompt, tags, answer input, submit
  button, etc.) remains visible and usable.
- [x] The full-screen tap-to-expand image viewer (#094) gets the same
  auto-retry + manual-retry treatment when opened on an image that failed
  to load (it fetches independently of the inline image, so it can fail
  and retry on its own).
- [x] Successful loads (first try or after retries) look exactly as today
  — no behavior change for the common case.
- [x] Follows #015: the failure placeholder uses kit tokens/spacing, no
  ad-hoc colors or styling; retry button and accessibility label strings
  go through `lib/l10n` (DE + EN), not hardcoded.
- [x] Covered by unit/widget tests: load succeeds after N automatic
  retries, automatic retries exhausted then manual retry succeeds, and the
  full-screen viewer's independent retry behaves the same way.

## Out of scope

- `FoxItemImage` thumbnails in set-detail/library list rows (separate fix,
  same root cause, not reported here).
- `emoji`/`base64` images — they don't fetch over the network and aren't
  affected by this bug.
- A permanent "stop retrying, this image is unavailable" state after
  repeated manual retries — retry stays available indefinitely.
- Offline detection/messaging beyond the generic retry affordance.

## Summary

Added `_RetryingNetworkImage` (private to `fox_question_image.dart`),
wrapping `Image.network` with 3-total-attempt auto-retry (300ms/700ms
delays, evicting the failed `ImageCache` entry + remounting via a new
`Image` key to force a genuine refetch), then a shared
`buildFoxImageLoadFailedPlaceholder` (kit tokens, `FoxSecondaryButton`
retry) once exhausted. `FoxQuestionImage` and `FoxFullScreenImageViewer`
each get their own independent instance. New l10n keys
`questionImageLoadFailed`/`questionImageRetryButton` (DE+EN), threaded
through `buildItemImage`. 16 new/updated widget tests in
`fox_question_image_test.dart` drive the real `errorBuilder` closure
directly (same technique `fox_item_image_test.dart` already used) for
deterministic coverage. An `integration_test` was written but could not
be executed in this sandboxed session — see that file's header comment.

## Code review

- Retry state machine (`_generation`/`_autoAttempt`/`_scheduledForGeneration`,
  `evict()`-before-`setState` ordering, no `dispose()` override) reviewed for
  races/leaks/"setState during build".
  Not fixed — no_change_needed: traced correct; missing `dispose()` is
  harmless given `mounted` guards and cache eviction being lifecycle-free.
- Acceptance criterion "load succeeds after N automatic retries" wasn't
  actually asserted by any test, despite being checked off.
  Fixed — extended the first #102 widget test to manually invoke the
  post-retry `Image`'s `loadingBuilder` with `progress: null` and assert
  the resolved child passes through unchanged.
