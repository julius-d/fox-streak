# Issue 061: Holiday + funny-rotation greetings on Home

Status: done | Priority: P3 | Type: feature | Completed-at: 2026-10-17

## Goal

Home's greeting (`_greeting`, `lib/src/home/home_screen.dart:37-53`, extended
by #060 with a night bucket) always shows one of 4 plain time-of-day strings.
Add two more layers on top, in priority order:

1. **Fixed-date holiday greetings** — a small hardcoded set of non-movable
   calendar dates (e.g. Jan 1 New Year's, Apr 1 April Fools, Oct 31
   Halloween, Dec 24-25 Christmas) override the time-of-day greeting for
   that date, in both EN and DE.
2. **Random funny rotation** — on ordinary (non-holiday) days, occasionally
   swap the standard greeting for a playful variant from a curated pool,
   instead of always showing the plain time-of-day text.

Deliberately out: movable holidays (Easter, Thanksgiving) that need date
calculation — fixed-date only, to avoid a date-math dependency.

## Decisions to make during implementation

- **No name personalization for holiday/funny variants.** Doubling every
  pool entry into named/unnamed arb pairs (like the 4 time-of-day buckets
  do) multiplies the translation surface a lot for little payoff. Holiday/
  funny copy stays generic; only the plain time-of-day greeting uses
  `displayName`. Revisit if this feels wrong once a few are written.
- **Rotation is deterministic per calendar day, not per rebuild.** Pick the
  funny variant via a seed derived from the local day string (same
  `toLocalDayString` convention used by streak/#059), so the greeting
  doesn't change every time Home rebuilds within the same day — it should
  feel like "today's greeting", not flicker on every navigation.
- **Rotation frequency**: propose roughly 1-in-5 days shows a funny variant,
  rest show the plain time-of-day greeting — tune during implementation,
  not load-bearing.
- **Precedence**: holiday (if today matches) > funny rotation > plain
  time-of-day. A holiday always wins on its date.

## Acceptance criteria

- [x] A fixed-date holiday table (date → arb key) covers at minimum Jan 1,
      Apr 1, Oct 31, Dec 24, Dec 25, each with EN + DE copy.
- [x] A curated pool (suggest 5-10 entries to start) of funny/playful
      generic greetings, EN + DE, picked deterministically per local day
      when no holiday matches.
- [x] `_greeting` (or its caller) checks holiday → rotation → existing
      time-of-day logic, in that order, using the injected `Clock` (no
      direct `DateTime.now()`, keeping it testable like today).
- [x] New strings via `lib/l10n` arb, no hardcoded copy (#015).
- [x] Tests: a holiday date shows its override regardless of hour; a
      non-holiday day with `FakeClock` deterministically reproduces the
      same rotation pick across rebuilds; rotation is skipped (falls back
      to plain greeting) on the days it's not selected.

## Out of scope

- Movable/computed holidays (Easter, Thanksgiving, etc.).
- Per-locale/region-specific holidays (e.g. Nikolaus, Thanksgiving-US-only)
  — the app only switches EN/DE language, not region.
- Name personalization for holiday/funny copy (see Decisions above).
- The night bucket itself — that's #060.

## Dependencies

- Builds on #060 (adds the 4th time-of-day bucket this layers on top of).
- Follows #015 (l10n-only copy, no ad-hoc styling).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

Extracted the greeting logic from `home_screen.dart`'s private `_greeting`
into `lib/src/home/greeting.dart` (`greetingText`), now checking a
fixed-date holiday table (Jan 1, Apr 1, Oct 31, Dec 24, Dec 25) first, then
a `Random(_daySeed(now))`-seeded ~1-in-5 funny rotation (8-entry pool,
`_daySeed` built from the local `year/month/day`, not `String.hashCode`,
so it's stable across runs), falling back to the existing time-of-day
text. Both new layers are generic (no `displayName`), per the issue's
decision. 13 new arb keys (EN+DE), hand-mirrored into
`app_localizations.dart` (no working `flutter gen-l10n` here, see
`lib/l10n/README.md`). New tests: `test/home/greeting_test.dart` (pure
logic, precedence, determinism), 2 new cases in
`test/home/home_screen_test.dart`, and
`integration_test/home_greeting_test.dart` (real `FoxStreakApp`
end-to-end). Screenshot: `issues/done/issue-061-home_holiday_greeting.png`.

## Code review

- No findings. A medium-effort review of the diff (correctness +
  reuse/simplification/efficiency) cleared the precedence order, the
  deterministic day-seed, arb/locale-file completeness, and the single
  `greetingText` call site with nothing to flag.
  N/A — nothing to fix.
