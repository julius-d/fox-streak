# Issue 131: A broken streak still shows as alive until the next lesson

Status: open | Priority: P3 | Type: bug

## Goal

`profile.streakCount` only changes when a lesson is completed (#011's
`StreakService.recordActivity`) or a freeze bridges exactly one missed day
(#087). After two or more missed days the stored count stays at its old
value until the next lesson resets it to 1. Until then:

- Home's streak badge still shows the old count and its per-day icons.
- The Streak Details hero (#128) shows that count with the "practice today
  to keep your streak going" nudge, and the current-streak band still
  outlines those old days, although the streak is already lost.

Found while implementing #128. It's out of #128's scope, which leaves
streak counting unchanged.

## Desired behavior

- Every streak display uses an *effective* streak: the stored count when
  `lastActiveDay` is today or yesterday, otherwise 0. The stored value
  isn't rewritten (#011 stays the only writer).
- One pure helper (next to `StreakService.computeNext`) decides this,
  used by Home's badge and `ActivityCalendarData.build`.
- The freeze auto-apply runs before the badge/hero read the value (same
  launch order as today), so a bridged day still counts as alive.

## Acceptance criteria

- [ ] A streak whose `lastActiveDay` is 2+ days ago shows as 0 / no badge on
      Home and the no-streak hero state on Streak Details.
- [ ] Unit tests for the helper (today, yesterday, older, null).
- [ ] `flutter analyze`, `dart format`, `flutter test` clean.
