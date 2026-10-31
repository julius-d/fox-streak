# Issue 089: Streak Details calendar — weekday/month labels + connected streak highlight

Status: open | Priority: P3 | Type: polish | Refined-at: 2026-10-31

## Goal

Polish the #084 Streak Details calendar (`ActivityCalendarView`): add weekday
and month labels so the grid is readable without counting cells, and make a
streak's run of consecutive days read as one connected shape instead of
separate per-cell rings.

## Context

#084 shipped the GitHub-style activity calendar (`lib/src/stats/
activity_calendar_view.dart`) with no row/column labels, and highlights a
streak's days by drawing an individual colored border on each cell
(`_DayCell._highlightBorder`) — current streak in the flame token, longest-
in-window streak in the primary color. Both gaps were flagged as "UI-polish,
left to implementation" in #084 and are what this issue addresses.

## Decisions

- **Weekday labels**: one locale-aware narrow weekday letter
  (`DateFormat.EEEEE(locale)` — confirmed available in the `intl` package
  already used by this screen) to the left of the grid, **sparse,
  GitHub-style**: only on the Mon/Wed/Fri rows (rows 1, 3, 5 of the
  Sunday-first 7-row grid), not all 7 rows. Rejected: labeling every row,
  since the narrow letter repeats within a week in several locales (e.g.
  German: M=Montag/Mittwoch, D=Dienstag/Donnerstag, S=Samstag/Sonntag),
  which reads as more confusing than helpful.
- **Month labels**: a 3-letter month abbreviation (`DateFormat.MMM(locale)`)
  above the grid, placed above the first week-column in which that month
  starts (GitHub-style), aligned above the weekday-letter column — not a
  single static "current month" label.
- **Connected streak highlight**: replace the individual per-cell border
  with one continuous highlighted shape spanning the whole run of
  consecutive days, for both the current streak (flame color) and the
  longest-in-window streak (primary color) when it differs from the current
  streak — same two colors and same precedence as today (a day in both runs
  renders with the current-streak color only; this is already how
  `ActivityDay.isCurrentStreak`/`isLongestStreak` and
  `longestDiffersFromCurrent` are computed in `activity_calendar.dart`, no
  change needed there).
  - *Implementation note*: a run's cells are vertically contiguous within a
    week-column but a streak can cross into the next column (e.g. a run
    ending Saturday of week N continuing Sunday of week N+1). The
    continuous shape needs to bridge that column boundary, not just draw
    one shape per column. Left to implementation (e.g. one rounded
    rect/stadium per contiguous within-column segment, joined by a short
    connector between the boundary cells when the run crosses columns) —
    exact rendering approach is a UI-polish detail, not a contract.
- **Header labels are decorative, not semantic**: each day cell already
  carries a full-date semantics label (`cellSemanticsLabel` in
  `streak_details_screen.dart`); the new weekday/month header labels must
  be excluded from the semantics tree (e.g. `ExcludeSemantics`) so a screen
  reader doesn't announce them separately from the cells.

## Acceptance criteria

- [ ] Mon/Wed/Fri rows of the grid show a locale-aware narrow weekday letter
  to the left of the grid; Sun/Tue/Thu/Sat rows show no letter.
- [ ] A 3-letter, locale-aware month abbreviation appears above the first
  week-column of each month in the ~6-month window.
- [ ] The current streak's run of consecutive days renders as one connected
  highlighted shape (flame color), including when the run spans across a
  week-column boundary.
- [ ] The longest-in-window streak's run (only when `longestDiffersFromCurrent`
  is true) renders with the same connected treatment in the primary color.
- [ ] A day belonging to both runs renders with the current-streak color only
  (no double-highlighting) — unchanged precedence from #084.
- [ ] Weekday/month header labels are excluded from the accessibility tree;
  existing per-cell semantics labels are unchanged.
- [ ] Golden tests (#019) cover the new header labels and connected-streak
  rendering, for both `en`/`de` locales (weekday letters differ) and both
  light/dark themes.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md.

## Out of scope

- Any change to streak computation (`StreakService`, `currentStreakDays`,
  `longestRunInWindow`) — this issue is the calendar's visual layer only.
- Cell size, color-bucket thresholds, or scroll behavior (#084, untouched
  here).
- Labeling all 7 weekday rows (explicitly rejected above).

## Dependencies

- Builds on #084 (`ActivityCalendarView`, `ActivityCalendarData`,
  `isCurrentStreak`/`isLongestStreak` flags already in place).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
