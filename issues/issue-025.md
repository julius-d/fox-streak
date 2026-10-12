# Issue 025: Extract shared day/month/year focus-advance logic

Status: open | Priority: P3 | Type: tech-debt | Refined-at: 2026-10-12

## Goal
`lib/src/library/item_editor.dart` (#004, the date editor's `_dateFields`) and `lib/src/exercises/date_exercise.dart` (#009, the date exercise card) each implement an identical copy of the day/month/year auto-advance + backspace-back focus logic (`_nextDateNode` / `_prevDateNode` / `_onDateChanged` / `_onDateKey`, locale-ordered). #009 intentionally copy-adapted rather than shared it (its own issue allowed "reuse/adapt"), but the duplication is a drift risk: a fix to one copy's focus/backspace behavior won't apply to the other.

## Acceptance criteria
- [ ] A single shared helper (e.g. `lib/src/library/date_field_focus.dart` or similar) owns the locale-aware next/prev node lookup, the auto-advance-on-fill `onChanged` handler, and the backspace-on-empty `onKeyEvent` handler, parameterized by the day/month/year `FocusNode`s + `TextEditingController`s + `isGerman`.
- [ ] Both `item_editor.dart`'s date fields and `date_exercise.dart` use the shared helper; existing behavior (and all existing tests, incl. `date-auto-advance and backspace-back` in `test/library/item_editor_test.dart` and the auto-advance tests in `test/exercises/date_exercise_test.dart`) is unchanged.
- [ ] No new widget keys or visual changes; this is a pure refactor.
- [ ] `flutter analyze`, `dart format`, `flutter test` all clean/green.

## Out of scope
- Any behavior change to the date editor or date exercise (validation, styling, locale order).

## Dependencies
- Builds on #004 (date editor) and #009 (date exercise), both already shipped.

## Verify
```powershell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```
