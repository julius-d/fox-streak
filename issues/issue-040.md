# Issue 040: Missing real-number export-warning dialog claimed by #008/#003

Status: open | Priority: P3 | Type: tech-debt

## Goal

`share_actions.dart`'s header comment says: "Verifiable export-warning
criteria (real privacy dialog copy, `SetImportException` snackbar copy,
picker-cancel behavior) are owned and tested in #008" — and #003's own task
list repeats the same claim. Neither #003 nor #008's shipped summaries
mention building it, and there is no such dialog anywhere in
`lib/src/library/` or `lib/src/exercises/`: `shareSet()` exports and opens
the share sheet unconditionally, regardless of whether the set contains
phone-number items with real-looking digits. #008's "Privacy note" section
is prose only ("Warn before exporting sets with real numbers"), never
implemented as code. Found incidentally while writing #016's Flow 4
(share-round-trip) integration test, which only exercises the actual
shipped behavior (export → share, no warning step).

## Acceptance criteria

- [ ] Decide: either implement the warning dialog (shown before `shareSet`
      opens the share sheet, when the set contains at least one `phone`
      item) and cover it with a test, or formally drop the requirement and
      correct the stale comments in `share_actions.dart`/`issues/issue-003.md`/
      `issues/issue-008.md` that still claim it exists.
- [ ] `flutter analyze`, `dart format`, `flutter test` stay clean.

## Out of scope

- Any other share/import behavior change.

## Dependencies

- Builds on #003/#008 (both `done`).
