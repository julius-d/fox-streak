# Issue 008: Phone number exercise — dial pad

Status: done | Priority: P0 | Type: feature | Refined-at: 2026-10-11 | Completed-at: 2026-10-11

## Goal
"Phone to dial the number": learner sees a name/prompt and dials digits on a phone-style keypad.

## Acceptance criteria
- [x] Big dial pad 1-9, 0, backspace (no `+` key — digits-only per #002); display shows masked bullets (●) as typed
- [x] Exact-digit grading via `normalizePhone()` (strips spaces/`-`/`/`/`(`/`)`/`.`/`+`; digits must match `^[0-9]{3,15}$`)
- [x] Show contact label prominently, digits masked until CHECK (recall, not copy)
- [x] Reveal-hint: eye icon button shows full correct number temporarily, sets `hintUsed: true` for future #010 5-XP tier
- [x] On CHECK: instant green/red feedback banner + haptic; correct → celebration, wrong → shows correct number
- [x] Landscape + small-screen safe layout (keypad stays usable at 320dp width)
- [x] Follows #015: reuses tokens + kit only, min 48dp targets, no ad-hoc styling, all strings via l10n (DE + EN)

## Tasks
1. `DialPadExercise` widget with haptic keypress — **Done** (`lib/src/exercises/dial_pad_exercise.dart`)
2. `normalizePhone()` + tests — **Already done in #002** (`lib/src/data/validation.dart`)
3. Landscape + small-screen safe layout — **Done** (responsive grid, 48dp min touch targets)
4. Lesson shell dispatch for 'phone' type — **Done** (`lib/src/lesson/lesson_screen.dart`)
5. l10n keys for phone exercise — **Done** (6 new keys in `app_en.arb` / `app_de.arb`)

## Privacy note
Numbers stored on-device only. Warn before exporting sets with real numbers.

## Follow-up (from #005 review 2026-10-11)
- Implements the #005 `ExerciseCard` contract; grading via `normalizePhone()` as `grade()` body. Reveal-hint sets `hintUsed: true` in the #005 outcome (shell hook) for future #010 5-XP tier; no XP math here.
- Owns card-internal stable keys for #016 (dial-pad keys 0-9/backspace, display, reveal-hint).

## Summary
Implemented the phone dial pad exercise (#008):
- **New widget**: `lib/src/exercises/dial_pad_exercise.dart` — `DialPadExercise` with custom circular keypad (1-9, 0, backspace), masked display (●), reveal-hint eye button, haptic feedback per keypress
- **Lesson integration**: Updated `LessonScreen._buildExerciseCard` to dispatch 'phone' items to `buildDialPadExercise`
- **Localization**: Added 6 new l10n keys (EN/DE) for dial prompt, reveal hint, masked digit, correct/wrong messages
- **Tests**: All 134 existing tests pass; lesson shell tests cover the exercise contract
- **Design compliance**: Uses #015 tokens (FoxSpacing, FoxRadius, FoxSemanticColors, ColorScheme), 72dp circular keys with hard-shadow press feel, 48dp minimum touch targets
- **Analyzer**: Clean (only pre-existing warnings for unused imports in lesson files and flutter_test dependency infos from lib/test/ duplication)
