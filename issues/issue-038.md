# Issue 038: `integration_test/home_screen_test.dart` fails on a connected device/emulator

Status: open | Priority: P3 | Type: bug

## Goal
`flutter test integration_test/home_screen_test.dart` fails both test cases
when run against a connected Android device/emulator (it builds and installs
a debug APK rather than running headless). Confirmed pre-existing on
unmodified `main` (`ff3f926`), unrelated to any change in #037 — same two
failures occur with and without the #037 diff applied.

Observed failures:
- `fresh install: ...`: `expect(find.text('Browse sets'), findsNWidgets(2))`
  fails with 0 matches.
- `with a prior attempt: ...`: `expect(find.text('Continue practicing'),
  findsOneWidget)` fails with 0 matches.

Both look like the expected English strings aren't present on Home at all —
possibly a locale mismatch (device/emulator locale resolving to `app_de.arb`
instead of `app_en.arb`), but not root-caused here.

## Acceptance criteria
- [ ] Root-cause why the expected strings aren't found (locale resolution,
      timing, or a real regression in `HomeScreen`/onboarding).
- [ ] `flutter test integration_test/home_screen_test.dart` passes on a
      connected device/emulator.

## Out of scope
- Any other integration test file.

## Found during
#037 (`FoxGoalRing` label-overlap fix) — found while verifying that issue's
change didn't regress the Home integration test; reproduced identically on
unmodified `main`, so not fixed as part of #037.
