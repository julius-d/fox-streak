# Issue 029: Tech debt from #026 review — SetDetailScreen test gap + repeated type-grouping checks

Status: open | Priority: P3 | Type: tech-debt

## Goal
Two cleanups surfaced by #026's code review, not fixed there (both pre-exist #026, which only added one more untested switch arm / one more copy of an existing pattern):

1. **`SetDetailScreen` has zero test coverage.** Its item-type label switch (`'choice' => l10n.typeChoice, 'freeText' => l10n.typeFreeText, 'phone' => ..., 'date' => ..., _ => item.type`) and icon rendering have never had a widget test, going back to #003/#004 — not just the `choice`/`freeText` arms #026 added.
2. **The "is this type choice-or-freeText" grouping is hand-duplicated** across `item_editor.dart` (prefill, `directionForSave`), `sets_repository.dart` (`updateItem`'s direction/choices-clearing logic), and implicitly in `validation.dart`'s `validateDirection`/`validateChoices`, with no shared predicate. `sets_repository.dart`'s `updateItem` also repeats the identical three-part guard (`type != null && xUpdate == null && type != existing.type`) once for direction and once for choices.

## Acceptance criteria
- [ ] Add a widget test for `SetDetailScreen` (`test/library/set_detail_screen_test.dart` or similar): pumps the screen with items of each type via a real repo + in-memory db, asserts the rendered type label + icon per type.
- [ ] Extract a shared predicate (e.g. `bool isVocabFlavoredType(String type) => type == 'choice' || type == 'freeText';` in `validation.dart`) and use it in `item_editor.dart` and `sets_repository.dart` instead of the repeated literal-set checks.
- [ ] Factor `sets_repository.dart`'s repeated `type != null && xUpdate == null && type != existing.type` guard into one local helper/variable.
- [ ] `flutter analyze`, `dart format`, `flutter test` stay clean; no behavior change.

## Out of scope
- Any new SetDetailScreen functionality — this is test-coverage + refactor only.

## Dependencies
- Builds on #003/#004 (SetDetailScreen) and #026 (the choice/freeText split that prompted this review).
