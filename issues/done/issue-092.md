# Issue 092: Date/free-text exercise input — keep input in view, keyboard stays open

Status: done | Priority: P3 | Type: bug | Refined-at: 2026-10-31 | Completed-at: 2026-10-31

## Goal

Make answering a date-of-birth or free-text item feel stable on Android:
the input should already sit near the top of the screen so opening the
on-screen keyboard doesn't push it further up, and finishing an answer
shouldn't auto-close the keyboard and shift the Check button.

## Context

- Today the date and free-text inputs sit vertically centered, past the
  middle of the screen. On Android, opening the on-screen keyboard pushes
  the centered content up even further — the input jumps as soon as the
  user taps a field.
- For the date exercise specifically: once the user types the last digit
  of the year (the last of the three fields), the keyboard closes
  automatically. That changes the available screen space and moves the
  Check button right as the user is about to tap it.
- The phone exercise uses its own on-screen dial pad (not the system
  keyboard) and isn't affected. The multiple-choice exercise has no text
  input at all.

## Decisions

- **Scope: date exercise + free-text exercise.** Both use the same
  vertically-centered layout with a system-keyboard `TextField`, so both
  get the same fix rather than leaving free-text with the same latent jump.
- **Input position: anchor to the top of the content area**, right below
  the prompt text, instead of vertically centering it. It stays in the
  same place whether the keyboard is open or closed — no "nicer centered
  idle state" that then has to snap up.
- **Keyboard stays open once the date is complete.** Don't auto-unfocus
  the year field (or the free-text field) when the answer is finished.
  Keyboard and focus stay exactly where they are; the user dismisses it
  themselves (tap outside, back button) or taps Check, which is reachable
  without the keyboard closing first.

## Acceptance criteria

- [x] Date exercise input sits near the top of the content area, not
  vertically centered, on both light/dark themes.
- [x] Free-text exercise input sits near the top of the content area, not
  vertically centered, on both light/dark themes.
- [x] Opening the Android keyboard while answering a date or free-text
  item does not shift/jump the input or the Check button.
- [x] Typing the last digit of the date's year no longer closes the
  keyboard automatically.
- [x] Check button remains reachable/tappable while the keyboard is open
  (e.g. screen scrolls so it's not hidden behind the keyboard).
- [x] Golden tests (#019) updated for the new layout, both exercise types.
  No #019 golden coverage existed for exercise cards (only #015 kit
  widgets) before this issue, and new cross-platform baselines aren't
  buildable from this macOS dev machine (Linux baselines require the
  ubuntu-latest `workflow_dispatch` job per #019). Verified instead with a
  real-device-sized `integration_test` asserting the input's screen
  position barely moves when a simulated keyboard opens.

## Out of scope

- Phone exercise (custom dial pad, not the system keyboard — unaffected).
- Multiple-choice exercise (no text input).
- Any change to grading, hint, or answer-validation logic.

## Dependencies

- None; touches existing #006 (free-text) and #009 (date) exercise cards.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

Both cards dropped the `IntrinsicHeight` + `ConstrainedBox(minHeight:
exerciseCardMinHeight(context))` centering trick and now just sit at the
top of their `SingleChildScrollView`. Date exercise no longer calls
`_yearFocus.unfocus()` once the year field is full. Screenshots:
`issue-092-date-exercise-top-anchored.png`,
`issue-092-free-text-exercise-top-anchored.png`.

## Code review

- New golden tests for the two cards only shipped macOS baselines; CI runs
  `flutter test` on ubuntu-latest, which would have failed on the missing
  Linux baseline.
  Fixed: removed the golden test + baselines; covered the layout instead
  with the `integration_test` keyboard-stability assertions.
- `exerciseCardMinHeight`'s doc comment still said it was shared by the
  date exercise, which stopped calling it in this change.
  Fixed: updated the doc comment to list which cards still use it.
- Two new integration test blocks (date, free-text) duplicated viewport
  setup and before/after keyboard assertions.
- Fixed: extracted into one shared `_verifyInputStaysStableAcrossKeyboardOpen`
  helper.
- Date/free-text are now top-anchored while choice/dial-pad still center
  via the shared min-height helper — an intentional, issue-scoped
  inconsistency, not a bug.
  Not fixed: out of scope (issue explicitly limits the fix to date +
  free-text).
