# Issue 034: Tech debt from #012 review — LessonResultScreen's "Back to library" doesn't always go to the library

Status: done | Priority: P3 | Type: tech-debt
Completed-at: 2026-10-15

## Goal
`LessonResultScreen`'s `backToLibraryButton` (`lesson_screen.dart`'s `_buildResultScreen`) just calls `Navigator.of(context).pop(result)` — it returns to whichever screen pushed the lesson, not necessarily the library. That was already slightly off before #012 (popping from `SetDetailScreen`'s `LessonEntryButton` returns to the set detail screen, not the library list), but #012 widens the gap: `HomeScreen`'s Continue button pushes `LessonScreen` directly, so tapping "Back to library" from that path pops back to the Home dashboard while still being labelled "Back to library" — confirmed by `integration_test/home_screen_test.dart`, which asserts landing back on `homeScreen` (not "My Sets") after that tap.

Surfaced by #012's code review; not fixed there since a proper fix touches a shared screen (`LessonResultScreen`) used by multiple callers (`SetDetailScreen`, `HomeScreen`, and `LessonScreen`'s own practice-again/restart path) and needs a design decision, not just a one-line patch.

## Acceptance criteria
- [x] Decide and implement one of: (a) make the button's label caller-aware (e.g. a `backLabel` param passed in by whoever pushes `LessonScreen`), or (b) make "back" always actually return to the library root (e.g. `Navigator.popUntil` to a named/known route) regardless of entry point.
- [x] Add a regression test covering the Home-entry path (button navigates/labels correctly when the lesson was reached via `HomeScreen`'s Continue button, not just via `SetDetailScreen`).
- [x] `flutter analyze`, `dart format`, `flutter test` stay clean.

## Out of scope
- Any other lesson-screen navigation change.

## Dependencies
- Builds on #005 (`LessonScreen`/`LessonResultScreen`), #003 (`SetDetailScreen`'s `LessonEntryButton`), #012 (`HomeScreen`'s direct Continue-button push, which is what exposed this).

## Summary
Chose (a), caller-aware label: option (b) doesn't actually work for the Home-direct path since `LibraryScreen` is never pushed onto that stack (`Home → Lesson` only), so there's nothing for `popUntil` to find — a true "always reach the library" fix would have to push a new `LibraryScreen` route, which is a bigger behavior change than this ticket's scope. Added `LessonScreen.backLabel` (nullable, defaults to the existing `lessonBackToLibrary` wording so `SetDetailScreen`'s `LessonEntryButton` push is unchanged) and threaded it into `LessonResultScreen.backLabel`; `HomeScreen._onContinue` passes the new `lessonBackToHome` ("Back to home" / "Zurück zur Startseite") string. `Navigator.pop(result)` behavior is unchanged — only the label now matches the real destination. New assertions in `test/lesson/lesson_shell_test.dart` (default label) and `integration_test/home_screen_test.dart` (Home-entry label).

## Code review
- Home-entry regression coverage lives only at the integration-test level (device/macOS-dependent), with no widget-test fallback if that suite gets flaky.
  Not fixed: verified passing on `-d macos`; a widget-level duplicate would need a fake `Navigator`/route-stack setup disproportionate to this fix's size.
- `backToLibraryButton`'s key name is now generic-but-named-library-specific now that its label is caller-dependent.
  Not fixed: cosmetic only; renaming would touch two existing test files for no behavior change, out of scope here.
