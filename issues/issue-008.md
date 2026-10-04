# Issue 008: Phone number exercise — dial pad

Status: open | Priority: P0 | Type: feature

## Goal
"Phone to dial the number": learner sees a name/prompt and dials digits on a phone-style keypad.

## Acceptance criteria
- [ ] Big dial pad 1-9, 0, +, backspace; display formats as typed
- [ ] Exact-digit grading (spaces/dashes ignored, digits must match)
- [ ] Show contact label prominently, digits hidden until check (recall, not copy)
- [ ] Optional reveal-hint (show first 3 digits, costs XP bonus)

## Tasks
1. `DialPadExercise` widget with haptic keypress
2. `normalizePhone()` (strip spaces, -, /, ()) + tests
3. Landscape + small-screen safe layout

## Privacy note
Numbers stored on-device only. Warn before exporting sets with real numbers.
