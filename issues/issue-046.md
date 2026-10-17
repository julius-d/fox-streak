# Issue 046: Phone input field cursor jumps to the end on every mid-string edit

Status: open | Priority: P2 | Type: bug | Refined-at: 2026-10-17

## Goal

The phone-number field in the question editor (`item_editor.dart`'s
`_phoneField()`, using `itemAnswerField`) always snaps the text cursor to the
very end of the field after *any* edit, even when the edit itself happened in
the middle of the string. This makes it practically impossible to edit
anything but the last character: for example, a user who pastes/types an
international number with a `+49` country-code prefix and then tries to
backspace through those leading digits gets the cursor kicked back to the end
after every single backspace, forcing them to re-tap the edit position each
time.

Root cause: `PhoneGroupingFormatter.formatEditUpdate`
(`lib/src/library/phone_formatting.dart:36-58`) unconditionally returns
```dart
TextEditingValue(
  text: grouped,
  selection: TextSelection.collapsed(offset: grouped.length),
)
```
on every edit (line 53-56). This was a deliberate simplification from #004
("The caret is parked at the end, which keeps typing cursor-stable for a
single appended-at-end field" — doc comment, line 34-35) that only holds for
the append-only-at-the-end case. It breaks for any insertion or deletion
elsewhere in the string, which is the common case once a user needs to
correct or trim what they typed.

## Decision (2026-10-17, with repo owner)

Fix via **cursor-preserving regroup**: keep the live grouping-while-typing
behavior, but compute the new caret offset from the edit position instead of
always collapsing to the end — the same technique used by typical
credit-card-number / phone-number input masks. Concretely: count the digits
in `oldValue.text` at or before `oldValue.selection.baseOffset`, then after
re-grouping, place the caret right after that same digit count in the new
grouped string (accounting for the inserted block-separator spaces).

(Alternative considered and rejected for now: group only on blur, showing
plain ungrouped digits while the field has focus. Simpler to implement, but
the field would look ungrouped while actively editing — worse editing
experience than fixing the cursor math.)

## Acceptance criteria

- [ ] Deleting a character anywhere in the phone field (not just at the end)
      leaves the caret immediately after the deletion point, not at the end
      of the field — verified for deleting from the middle and deleting a
      leading country-code-like prefix (e.g. typing/pasting `+49 171 234567`
      then backspacing through the leading `49`).
- [ ] Inserting/typing a character anywhere in the middle of the field
      (not just appending at the end) leaves the caret immediately after the
      inserted character, not at the end of the field.
- [ ] Appending at the end (the original common case) keeps working exactly
      as before — caret stays at the end while typing a new number forward.
- [ ] Existing behavior unchanged: non-digit/invalid characters still get
      rejected (formatter returns `newValue` untouched), paste still
      auto-strips separators (`normalizePhone`) and re-groups, clearing the
      field still resets to an empty collapsed selection at offset 0.
- [ ] Unit tests added to `test/library/formatting_test.dart` covering
      `PhoneGroupingFormatter.formatEditUpdate` directly: delete from the
      middle, delete a leading prefix, insert in the middle, append at the
      end — asserting both the resulting grouped text and the resulting
      caret offset.
- [ ] `flutter analyze` / `dart format --output=none --set-exit-if-changed .`
      / `dart fix --dry-run` / `flutter test` stay clean/green.

## Out of scope

- Any change to the stored value format, `normalizePhone`, validation
  (`isValidPhoneAnswer`), or the digit grouping width (still blocks of 3) —
  this issue only fixes caret placement during live editing.
- The dial-pad exercise input (`dial_pad_exercise.dart`) and the set-detail
  display formatting (#049) — neither uses a live `TextInputFormatter` with
  this caret bug; not touched here.
- Supporting selection-range edits (e.g. selecting multiple digits and
  overtyping) with pixel-perfect caret placement beyond the collapsed-cursor
  cases above, if that turns out to need materially more logic — flag and
  split off if so.

## Dependencies

- Builds on #004 (`item_editor.dart`, `PhoneGroupingFormatter`,
  `groupPhoneForDisplay`, `phone_formatting.dart`).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
