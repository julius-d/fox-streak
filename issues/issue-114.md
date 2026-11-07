# Issue 114: Slim down the lesson result screen buttons

Status: open | Priority: P3 | Type: enhancement | Refined-at: 2026-11-07

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
