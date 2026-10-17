# Issue 056: `xp_level_result_test.dart` fails deterministically on a real device run

Status: open | Priority: P2 | Type: bug

## Goal

`integration_test/xp_level_result_test.dart` ("a perfect-score lesson shows
the XP count-up, perfect bonus callout, and level-progress bar...") fails
every time on a real `-d macos` run (confirmed 3/3 on `main` as of
2026-10-17, unrelated to #053's changes) — not flaky, deterministic.

## Root cause

The set has exactly 2 items (`der Hund`→`dog`, `die Katze`→`cat`). With
only 2 items total, each question's sole distractor is the *other* item's
answer — so both "dog" and "cat" are visible simultaneously on *every*
question screen, regardless of which question is actually showing.

The test picks which answer to tap via:
```dart
final shown = itemsByAnswer.keys.firstWhere(
  (a) => find.text(a).evaluate().isNotEmpty,
);
```
Since both keys are always visible, this always resolves to the first key
in the map's iteration order ("dog"), on *both* iterations of the loop —
correct for whichever question actually asks about "der Hund", wrong for
the other. Net result: 1 correct + 1 wrong instead of 2 correct, so the
asserted "+25 XP"/100% never appears.

`streak_result_test.dart` shares the exact same 2-item setup and the same
tap-selection pattern, but happens not to notice: it only asserts the
streak milestone (which increments on any completed lesson regardless of
per-item correctness), not the score/XP values.

## Acceptance criteria

- [ ] `flutter test integration_test/xp_level_result_test.dart -d macos`
      passes.
- [ ] The tap-selection logic no longer depends on which *answer* text
      happens to be visible — e.g. key off the current question's unique
      *prompt* text instead (see
      `integration_test/level_up_result_test.dart`'s `answerAllCorrectly`
      helper, added by #053, for a working pattern) — and give
      `streak_result_test.dart` the same fix even though it doesn't
      currently fail, so it doesn't silently start failing if its
      assertions ever tighten.

## Out of scope

- Any other integration test file — only these two share this exact
  2-item/1-distractor shape today.

## Dependencies

- None. Discovered incidentally while implementing #053.
