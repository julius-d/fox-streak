# Issue 086: Reword 4 of the DE funny-greeting rotation strings

Status: open | Priority: P3 | Type: chore

## Goal

Home's playful-rotation greetings (issue #061, `lib/l10n/app_de.arb`,
`_funnyPool` in `lib/src/home/greeting.dart`) are indexed 1–8. Reword the
DE copy for slots 2, 4, 6, and 8 to shorter, punchier variants. EN copy and
all other slots are unchanged.

## Acceptance criteria

- [ ] `homeGreetingFunny2` (`app_de.arb`): "Dein Fuchsgehirn wärmt sich
      auf!" → "Moin"
- [ ] `homeGreetingFunny4` (`app_de.arb`): "Wissens-Snacks kommen sofort!"
      → "Hi"
- [ ] `homeGreetingFunny6` (`app_de.arb`): "Gehirn-Gains warten auf dich!"
      → "Lass uns loslegen"
- [ ] `homeGreetingFunny8` (`app_de.arb`): "Fuchs-Modus: aktiviert!" →
      "Wie geht es Dir?"
- [ ] No change to `app_en.arb` or `lib/src/home/greeting.dart`.

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
