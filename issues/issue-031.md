# Issue 031: Double-tap race on CHECK/CONTINUE/Skip can duplicate attempts/outcomes

Status: open | Priority: P3 | Type: tech-debt

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
- [ ] CHECK, CONTINUE, and Skip are each effectively idempotent/debounced
      while a previous call for the same action is still in flight, so a
      double-tap can't duplicate an `attempts` row or an `outcomes` entry.
- [ ] No regression to the existing single-tap flows; `flutter analyze`,
      `dart format`, `flutter test` stay clean/green.
- [ ] A test reproducing the double-tap (e.g. firing `skip()` twice without
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
