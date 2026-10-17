# Issue 047: Question add/edit screens should be full-screen, not dialogs

Status: done | Priority: P2 | Type: UX | Refined-at: 2026-10-17 | Completed-at: 2026-10-17

## Goal

Creating or editing a question (an `Item` in a `QuestionSet`) currently opens
`ItemEditorDialog` (`lib/src/library/item_editor.dart`) as an `AlertDialog`
via `showDialog` from `SetDetailScreen._openItemEditor`
(`lib/src/library/set_detail_screen.dart:46-55`). The form has several
type-specific subforms (choice + 3 distractors + optional language toggle,
freeText + language toggle, phone, date) that get cramped inside a dialog's
limited width/height. This issue converts that dialog into a full-screen
route so the form can use the full available screen space, for both
**creating a new question and editing an existing one**.

A directly analogous conversion already exists in this codebase:
`SetEditorScreen` (#003, `lib/src/library/set_editor_screen.dart`) is a full
`Scaffold` with an `AppBar`, a scrollable `Form` body, and a full-width
`FoxPrimaryButton` at the bottom — used for both creating and editing a
*set*. The item editor should follow the same pattern.

## Decision (2026-10-17, with repo owner)

- Scope covers **both** add and edit flows (one screen branching on
  `existing == null`, like `SetEditorScreen` does), not just creation, to
  avoid having two different UI patterns (dialog vs. full screen) for the
  same form.
- Dismissal without saving is via the `AppBar` back arrow and the system
  back gesture/button only — no separate "Cancel" action, matching
  `SetEditorScreen` today.
- No unsaved-changes confirmation on back navigation — matches current
  dialog behavior (Cancel closes immediately) and keeps scope small.

## Acceptance criteria

- [x] `ItemEditorDialog` is converted into a full-screen widget (e.g.
      `ItemEditorScreen`) that returns a `Scaffold` with an `AppBar`
      instead of an `AlertDialog` — title is `l10n.setDetailAddItem` when
      creating, and a new `editItem` l10n string ("Edit item" / German
      equivalent) when editing. This also fixes today's bug where the
      dialog's title falls back to `l10n.save` ("Save") in edit mode
      instead of a real heading.
- [x] `SetDetailScreen._openItemEditor` pushes the new screen via
      `Navigator.of(context).push(MaterialPageRoute(builder: ...))` (or
      equivalent) instead of `showDialog`, keeping the same `setId` /
      `existing` constructor arguments and the same `bool` pop-result
      contract so the caller's refresh logic needs no further changes.
- [x] All existing form content (type dropdown, prompt field, and the
      per-type subforms: choice + distractors + language toggle, freeText +
      language toggle, phone, date) moves into the screen's scrollable body
      unchanged, keeping existing widget keys (`itemTypeField`,
      `itemPromptField`, `saveItemButton`, etc.) so current widget tests
      keep passing without key changes.
- [x] The Save action becomes a full-width `FoxPrimaryButton` placed in the
      body (bottom), matching `SetEditorScreen`'s `saveSetButton` — no
      dialog `actions` row, no separate Cancel button.
- [x] Tests referencing `showDialog`/`ItemEditorDialog` navigation are
      updated; add/adjust tests to confirm both the add and edit flows push
      a full screen and pop correctly on save and on back navigation.
- [x] Follows #015 (design kit): reuses `FoxPrimaryButton` and
      `FoxFeedbackBanner` (save errors) as today; `AppBar` styling comes
      from the shared theme — no new ad-hoc styling introduced.
- [x] `flutter analyze` / `dart format --output=none --set-exit-if-changed .`
      / `dart fix --dry-run` / `flutter test` stay clean/green.

## Out of scope

- Any change to validation logic, field behavior, or the data model —
  this is a presentation/navigation change only (dialog container → full
  screen), not a forms rewrite.
- Unsaved-changes confirmation on back navigation (explicitly decided
  against above).
- `SetEditorScreen` (#003) and any other dialog elsewhere in the app
  (e.g. `FoxConfirmDialog` usages) — only the item/question editor is
  touched here.

## Dependencies

- Builds on #004 (`item_editor.dart` fields/subforms), #022 (language-pair
  toggle), #026 (choice/freeText type split) — their behavior is unchanged,
  only the surrounding container changes.
- Mirrors the full-screen pattern already established by #003's
  `SetEditorScreen`.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

`ItemEditorDialog` -> `ItemEditorScreen`: `Scaffold`+`AppBar` (title
`setDetailAddItem`/new `editItem` l10n key), body is `SingleChildScrollView`
+ `Column` (not `ListView` — a `ListView` only builds children within its
viewport, which left the Save button unbuilt/untappable for the longer
choice-with-language-pair form), full-width `saveItemButton` at the bottom,
no Cancel button. `SetDetailScreen._openItemEditor` now pushes via
`Navigator.push(MaterialPageRoute(...))`. All existing widget keys preserved.
`flow1_library_crud_test.dart`'s invalid-input-blocked steps now use
`tester.pageBack()` instead of tapping a (removed) Cancel button.
Screenshots: `issue047-add_item_screen.png`, `issue047-edit_item_screen.png`.

## Code review

Reviewed by a code-review subagent (medium effort); one finding survived verification.
- `test/library/set_detail_screen_test.dart`'s new `listTileWithText` duplicates `integration_test/helpers.dart`'s helper of the same name (no cross-import precedent exists between `test/` and `integration_test/` in this repo).
  Not fixed by extracting a shared file (no established pattern for that cross-dependency); instead added a cross-reference comment in both copies so a future change to one flags the other.
