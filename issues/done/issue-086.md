# Issue 086: Reword 4 of the DE funny-greeting rotation strings

Status: done | Priority: P3 | Type: chore | Completed-at: 2026-10-31

## Goal

Home's playful-rotation greetings (issue #061, `lib/l10n/app_de.arb`,
`_funnyPool` in `lib/src/home/greeting.dart`) are indexed 1–8. Reword the
DE copy for slots 2, 4, 6, and 8 to shorter, punchier variants. EN copy and
all other slots are unchanged.

## Acceptance criteria

- [x] `homeGreetingFunny2` (`app_de.arb`): "Dein Fuchsgehirn wärmt sich
      auf!" → "Moin"
- [x] `homeGreetingFunny4` (`app_de.arb`): "Wissens-Snacks kommen sofort!"
      → "Hi"
- [x] `homeGreetingFunny6` (`app_de.arb`): "Gehirn-Gains warten auf dich!"
      → "Lass uns loslegen"
- [x] `homeGreetingFunny8` (`app_de.arb`): "Fuchs-Modus: aktiviert!" →
      "Wie geht es Dir?"
- [x] No change to `app_en.arb` or `lib/src/home/greeting.dart`.

## Out of scope

- Slots 1, 3, 5, 7 and all EN strings.
- Any change to the rotation/selection logic in `greeting.dart`.

## Dependencies

- Builds on #061 (introduced the funny-greeting rotation and these arb
  keys).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

Reworded `homeGreetingFunny2/4/6/8` in `app_de.arb` only; regenerated
`app_localizations_de.dart` via `flutter gen-l10n`. Added DE spot-check
tests in `test/home/greeting_test.dart` (one date per changed slot,
picked via the same deterministic per-day RNG as the existing funny-
rotation tests). No UI/widget change, so no new integration test or
screenshots.

## Code review

No findings. Diff scan, removed-behavior check, cross-file trace, and
reuse/simplification/efficiency pass all came back clean.
Not fixed: nothing to fix — review confirmed the diff exactly matches the
issue's acceptance criteria with no logic change.
