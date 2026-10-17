# Issue 060: Add a "night" greeting bucket for very early hours

Status: open | Priority: P3 | Type: feature

## Goal

Home's time-of-day greeting (`_greeting`, `lib/src/home/home_screen.dart:37-53`)
only has three buckets: morning (`hour < 12`), afternoon (`12-17`), evening
(`18-23`). Opening the app between midnight and ~5am falls into the morning
bucket and shows "Good morning!", which reads oddly at 2am. Add a 4th "night"
bucket for the small hours, with its own generic + named localized strings
(DE + EN), following the existing pattern (`l10n.homeGreetingNight` /
`homeGreetingNightNamed(name)`).

Proposed boundary: `hour < 5` → night, `5 <= hour < 12` → morning, unchanged
afternoon/evening ranges otherwise. This directly fixes the "2am = good
morning" case without touching the existing evening range.

## Acceptance criteria

- [ ] `_greeting` gains a night bucket for `hour < 5` (shifting morning to
      `5 <= hour < 12`); afternoon/evening boundaries (`12`, `18`) unchanged.
- [ ] New arb keys `homeGreetingNight` / `homeGreetingNightNamed` (EN + DE),
      following the existing generic/named pairing for the other three
      buckets. Suggested EN copy: "Up late?" / "Up late, {name}?" — final
      wording is the implementer's call, just keep the tone consistent with
      the other buckets (short, friendly, no shaming — per #015).
- [ ] Follows #015: new strings via `lib/l10n` arb params, no hardcoded
      copy.

## Tasks

1. Add `homeGreetingNight`/`homeGreetingNightNamed` to `app_en.arb` and
   `app_de.arb`, regenerate `app_localizations.dart`.
2. Update `_greeting` in `home_screen.dart` to branch on the new boundary.
3. Add widget tests in `test/home/home_screen_test.dart` using `FakeClock`
   for boundary coverage: just before/at/after `hour == 5`, `12`, and `18`
   (existing tests only cover a fixed 9am fixture — no boundary currently
   has dedicated coverage).

## Out of scope

- Holiday/special-date greetings — tracked separately.

## Dependencies

- None. Builds on the existing `_greeting`/`Clock` structure from #012.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
