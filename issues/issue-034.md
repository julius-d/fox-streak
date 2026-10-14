# Issue 034: Tech debt from #012 review — LessonResultScreen's "Back to library" doesn't always go to the library

Status: open | Priority: P3 | Type: tech-debt

## Goal
`LessonResultScreen`'s `backToLibraryButton` (`lesson_screen.dart`'s `_buildResultScreen`) just calls `Navigator.of(context).pop(result)` — it returns to whichever screen pushed the lesson, not necessarily the library. That was already slightly off before #012 (popping from `SetDetailScreen`'s `LessonEntryButton` returns to the set detail screen, not the library list), but #012 widens the gap: `HomeScreen`'s Continue button pushes `LessonScreen` directly, so tapping "Back to library" from that path pops back to the Home dashboard while still being labelled "Back to library" — confirmed by `integration_test/home_screen_test.dart`, which asserts landing back on `homeScreen` (not "My Sets") after that tap.

Surfaced by #012's code review; not fixed there since a proper fix touches a shared screen (`LessonResultScreen`) used by multiple callers (`SetDetailScreen`, `HomeScreen`, and `LessonScreen`'s own practice-again/restart path) and needs a design decision, not just a one-line patch.

## Acceptance criteria
- [ ] Decide and implement one of: (a) make the button's label caller-aware (e.g. a `backLabel` param passed in by whoever pushes `LessonScreen`), or (b) make "back" always actually return to the library root (e.g. `Navigator.popUntil` to a named/known route) regardless of entry point.
- [ ] Add a regression test covering the Home-entry path (button navigates/labels correctly when the lesson was reached via `HomeScreen`'s Continue button, not just via `SetDetailScreen`).
- [ ] `flutter analyze`, `dart format`, `flutter test` stay clean.

## Out of scope
- Any other lesson-screen navigation change.

## Dependencies
- Builds on #005 (`LessonScreen`/`LessonResultScreen`), #003 (`SetDetailScreen`'s `LessonEntryButton`), #012 (`HomeScreen`'s direct Continue-button push, which is what exposed this).
