# Issue 049: Set detail screen shows raw unformatted date/phone answers

Status: open | Priority: P3 | Type: bug | Refined-at: 2026-10-17

## Goal

`SetDetailScreen`'s per-item subtitle
(`lib/src/library/set_detail_screen.dart:175`) prints `item.answer` raw:

```dart
subtitle: Text('$typeLabel · ${item.answer}'),
```

For `date` items this is the stored ISO value (`1985-05-14`) instead of the
locale-formatted display a German user expects (`14.05.1985`). This is the
only screen that bypasses the shared formatter — the question creation/edit
screen (`item_editor.dart`) and the lesson answer screen
(`date_exercise.dart`) both already call
`formatDateForDisplay(item.answer, Localizations.localeOf(context))` from
`lib/src/library/date_display.dart`. (The input fields themselves, and the
lesson's feedback/reveal text, were checked and are not affected — this bug
is isolated to this one subtitle line.)

Same root cause hits `phone` items on the same line: raw digits instead of
the existing `groupPhoneForDisplay()` grouping (from `phone_formatting.dart`,
already used by `item_editor.dart` and `dial_pad_exercise.dart`). Fixing both
in one pass since it's the same line and the same class of bug.

`choice`/`freeText` items are plain text already and are unaffected.

## Acceptance criteria

- [ ] `set_detail_screen.dart`'s item subtitle formats `date` items via
      `formatDateForDisplay(item.answer, Localizations.localeOf(context))`.
- [ ] Same subtitle formats `phone` items via
      `groupPhoneForDisplay(normalizePhone(item.answer))`.
- [ ] `choice`/`freeText` items keep showing `item.answer` as-is.
- [ ] Test added/updated in `test/library/set_detail_screen_test.dart`
      asserting a `date` item's subtitle shows `DD.MM.YYYY` (not raw ISO)
      and a `phone` item's subtitle shows grouped digits.
- [ ] `flutter analyze` / `dart format` / `dart fix --dry-run` /
      `flutter test` clean.

## Out of scope

- Making `formatDateForDisplay` properly locale-aware beyond its current
  German-vs-everything-else split (e.g. via `intl`'s `DateFormat`) — separate
  concern, not touched here.
- Any change to the input fields, editor preview, or lesson feedback/reveal
  text for date or phone items — all already correct and out of scope.

## Dependencies

- Builds on #002 (data layer), #004 (item editor + `date_display.dart`),
  #008 (phone formatting), #009 (date exercise).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
