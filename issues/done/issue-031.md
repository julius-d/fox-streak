# Issue 031: Double-tap race on CHECK/CONTINUE/Skip can duplicate attempts/outcomes

Status: done | Priority: P3 | Type: tech-debt
Completed-at: 2026-10-13

## Goal
`LessonController.submitGrade()`/`skip()` both `await _statsRepo.recordAttempt(...)`
*before* touching `state` at all. If the triggering button/menu item fires
twice in quick succession (e.g. a double-tap, or two near-simultaneous
calls before the first `await` resumes), both calls read the same
`state.currentItem`/`state.outcomes`, so both write an `attempts` row and
both append an outcome for the same item — advancing `index` twice and
duplicating an entry in `outcomes`, which skews `correctCount`/`scorePct`.
Pre-existing pattern (not introduced by #010), but #010 widened the window
slightly by making the lesson-completion path (`_completeLesson`, formerly
`_advanceAfterOutcome`/`next()`) `async` and awaited end-to-end — found
during #010's code review.

## Acceptance criteria
- [x] CHECK, CONTINUE, and Skip are each effectively idempotent/debounced
      while a previous call for the same action is still in flight, so a
      double-tap can't duplicate an `attempts` row or an `outcomes` entry.
- [x] No regression to the existing single-tap flows; `flutter analyze`,
      `dart format`, `flutter test` stay clean/green.
- [x] A test reproducing the double-tap (e.g. firing `skip()` twice without
      awaiting the first call) asserts exactly one outcome/attempt is
      recorded for the item.

## Out of scope
- Any UI redesign of the CHECK/CONTINUE button beyond what's needed to
  guard against the double-tap (e.g. disabling it while a request is in
  flight is an acceptable minimal fix).

## Dependencies
- None blocking. Touches `lib/src/lesson/lesson_controller.dart` (and
  possibly `lesson_screen.dart` if the fix disables buttons during the
  in-flight window).

## Summary
Added a single `_actionInFlight` bool guard on `LessonController`, run via
a shared `_guarded()` helper wrapping `submitGrade()`/`skip()`/`next()`
(shared since CHECK and Skip are both live UI targets during the
`answering` phase, so a cross-action race is exactly as unsafe as a
same-action double-tap). `LessonState.busy` mirrors the guard so
`lesson_screen.dart` can disable CHECK/CONTINUE and hide the Skip menu
item for the duration, rather than silently dropping a tap with no visible
affordance. New `test/lesson/lesson_controller_double_tap_test.dart` fires
each action twice without awaiting the first call and asserts exactly one
outcome/attempt; new `integration_test/lesson_double_tap_test.dart` drives
the real `LessonScreen` (with an artificially slowed `StatsRepository`) to
prove a Skip tap landing while CHECK's write is in flight doesn't skip the
item. Both verified to fail without their respective fix.

## Code review
- `_completeLesson`'s `xpApplied`-guard doc comment was stale (described
  "possibly overlapping" calls `_actionInFlight` now prevents).
  Fixed — comment updated to note it's now defense-in-depth, mainly hit via
  rebuild/rotation replay.
- `restart()`/`start()` aren't guarded by `_actionInFlight`, so a restart
  mid-flight of a prior `submitGrade`/`skip`/`next` could drop a legitimate
  action or get clobbered by the stale call's state write.
  Not fixed — out of scope for #031, low-probability given current screen
  flow (restart only reachable from the done screen); filed as #033.
- The shared `_actionInFlight` flag blocks Skip while CHECK is in flight
  (both reachable during `answering`), contradicting the original "never
  legitimately concurrent" comment — Skip would silently no-op with no
  user feedback.
  Fixed — added reactive `LessonState.busy`; CHECK disables and the Skip
  menu item hides while any guarded action is in flight, so the UI never
  offers a tap the guard would have to swallow.
- The guard/try/finally boilerplate was duplicated identically across
  `submitGrade()`/`skip()`/`next()`, inviting divergence on future edits.
  Fixed — extracted a shared `_guarded()` helper; all three are now a
  one-line call into it.
