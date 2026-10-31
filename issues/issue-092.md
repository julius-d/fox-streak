# Issue 092: Date/free-text exercise input — keep input in view, keyboard stays open

Status: open | Priority: P3 | Type: bug | Refined-at: 2026-10-31

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

- [ ] Date exercise input sits near the top of the content area, not
  vertically centered, on both light/dark themes.
- [ ] Free-text exercise input sits near the top of the content area, not
  vertically centered, on both light/dark themes.
- [ ] Opening the Android keyboard while answering a date or free-text
  item does not shift/jump the input or the Check button.
- [ ] Typing the last digit of the date's year no longer closes the
  keyboard automatically.
- [ ] Check button remains reachable/tappable while the keyboard is open
  (e.g. screen scrolls so it's not hidden behind the keyboard).
- [ ] Golden tests (#019) updated for the new layout, both exercise types.

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
