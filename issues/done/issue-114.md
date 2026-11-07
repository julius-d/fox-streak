# Issue 114: Slim down the lesson result screen buttons

Status: done | Priority: P3 | Type: enhancement | Refined-at: 2026-11-07 | Completed-at: 2026-11-07

## Goal

The result screen at the end of a lesson shows up to four buttons (Home, Set
overview, Redo whole set, Redo missed items). That is too many choices at a
moment that should feel like a celebration. Reduce it to the two actions that
matter: leave, or retry what went wrong.

## Rationale

Fewer choices, and the only retry offered is the one that targets what the
user got wrong. Restarting the whole set is deliberately no longer offered
here: it now always goes through Home -> set. This is an intended trade-off,
not a bug.

## Desired behavior

- **Removed** from the result screen: "Set overview" and "Redo whole set".
  They are only gone from this screen; the user can still reach the set and
  start it again from Home / the library as before.
- **Some items missed:** two full-width buttons, stacked, same spacing as
  today:
  1. "Redo missed items", primary style (on top)
  2. "Home", secondary style (below)
- **Perfect score (nothing missed):** a single full-width "Home" button in
  primary style. No redo option is shown.
- Score summary, pet, and the rest of the screen are unchanged.
- Existing labels (DE + EN) are reused; no new copy.
- Follows #015 (kit buttons, 48dp targets, wrapping labels, dark mode,
  large-font).

## Out of scope

- Changing what "Redo missed items" or "Home" do.
- Adding any new way to restart the whole set.
- The completion screens pushed on top of the result screen (lootbox,
  streak, XP).
- Changes to the question format (no `docs/` update needed).

## Acceptance Criteria

- With missed items: exactly "Redo missed items" (primary) above "Home"
  (secondary) is shown.
- With a perfect score: exactly one button, "Home" (primary).
- "Set overview" and "Redo whole set" no longer appear in any case.
- Dead code is removed: the `onSetOverview` / `onRedoWholeSet` params of
  `LessonResultScreen`, `_goToSetOverview` and the now-unused
  `LessonController.restart()` (keep `restartWithItems`), and the
  `lessonSetOverview` / `lessonRedoWholeSet` strings in both ARB files
  (regenerate l10n).
- Tests cover both states (missed / perfect) and the absence of the removed
  buttons.
- Existing tests in `test/lesson/lesson_shell_test.dart` that tap or expect
  `redoWholeSetButton` (incl. the #109 Hero-flight test) are updated to use
  another route (e.g. redo missed items, or Home).
- `flutter analyze`, `dart format` and `flutter test` are clean.

## Summary

- `LessonResultScreen` shows primary "Redo missed items" above secondary "Home", or a lone primary "Home" on a perfect score.
- Removed `onSetOverview`/`onRedoWholeSet`, `_goToSetOverview`, `LessonController.restart()` and both l10n strings.
- Tests: new `test/lesson/lesson_result_screen_test.dart`; shell/controller/integration tests moved off `redoWholeSetButton`/`restart()`.
- Screenshots: `issue-114-result-missed-items.png`, `issue-114-result-perfect-score.png`.

## Code review

- Redo missed items makes `sourceItems` (the choice distractor pool) only the missed items.
  Not fixed: pre-existing, out of scope; follow-up issue 116.
- Stale comments mentioning `restart`/"Redo whole set"/"Set overview".
  Fixed.
- Integration test no longer covers the Set overview entry route.
  Not fixed: the route was removed by this issue.
- Shell tests skip items to produce a missed item, so Redo shows.
  Not fixed: skip counting as missed is documented behavior; the screen's perfect-score path is covered in `lesson_result_screen_test.dart`.
- Perfect score inferred from `onRedoMissedItems == null`.
  Not fixed: existing, documented design; covered by tests.
- #072 remount test no longer exercises a full-set restart.
  Not fixed: the remount is keyed on `attempt`, identical for redo-missed; comment updated.
