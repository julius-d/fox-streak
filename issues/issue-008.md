# Issue 008: Phone number exercise — dial pad

Status: open | Priority: P0 | Type: feature

## Goal
"Phone to dial the number": learner sees a name/prompt and dials digits on a phone-style keypad.

## Acceptance criteria
- [ ] Big dial pad 1-9, 0, backspace (no `+` key — digits-only per #002); display formats as typed
- [ ] Exact-digit grading via `normalizePhone()` (strips spaces/`-`/`/`/`(`/`)`/`.`/`+`; digits must match `^[0-9]{3,15}$`)
- [ ] Show contact label prominently, digits hidden until check (recall, not copy)
- [ ] Optional reveal-hint (show first 3 digits, costs XP bonus)

## Tasks
1. `DialPadExercise` widget with haptic keypress
2. `normalizePhone()` (strip spaces, `-`, `/`, `(`, `)`, `.`, `+`; digits-only output per #002) + tests
3. Landscape + small-screen safe layout

## Privacy note
Numbers stored on-device only. Warn before exporting sets with real numbers.

## Follow-up (from #005 review 2026-10-11)
- Implements the #005 `ExerciseCard` contract; grading via `normalizePhone()` as `grade()` body. Reveal-hint sets `hintUsed: true` in the #005 outcome (shell hook) for future #010 5-XP tier; no XP math here.
- Owns card-internal stable keys for #016 (dial-pad keys, display).
