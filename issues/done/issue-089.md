# Issue 089: Streak Details calendar — weekday/month labels + connected streak highlight

Status: done | Priority: P3 | Type: polish | Refined-at: 2026-10-31 | Completed-at: 2026-10-31

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

- [x] Mon/Wed/Fri rows of the grid show a locale-aware narrow weekday letter
  to the left of the grid; Sun/Tue/Thu/Sat rows show no letter.
- [x] A 3-letter, locale-aware month abbreviation appears above the first
  week-column of each month in the ~6-month window.
- [x] The current streak's run of consecutive days renders as one connected
  highlighted shape (flame color), including when the run spans across a
  week-column boundary.
- [x] The longest-in-window streak's run (only when `longestDiffersFromCurrent`
  is true) renders with the same connected treatment in the primary color.
- [x] A day belonging to both runs renders with the current-streak color only
  (no double-highlighting) — unchanged precedence from #084.
- [x] Weekday/month header labels are excluded from the accessibility tree;
  existing per-cell semantics labels are unchanged.
- [x] Golden tests (#019) cover the new header labels and connected-streak
  rendering, for both `en`/`de` locales (weekday letters differ) and both
  light/dark themes.
- [x] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
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

## Summary

Added a fixed weekday-letter column (narrow Mon/Wed/Fri letters via
`DateFormat.EEEEE`, locale-aware) and a month-abbreviation row that scrolls
with the grid (`DateFormat.MMM`, one label per week-column whose topmost
day starts a new month) to `ActivityCalendarView`. Replaced the old
per-cell highlight border with one merged rounded-rect per contiguous
same-kind run within a week-column, plus two short connector notches on
the boundary cells (Saturday/Sunday) when a run crosses into the next
column — current-streak flame color still takes precedence over
longest-in-window primary color, unchanged from #084. Header labels are
wrapped in `ExcludeSemantics`; per-cell semantics are unchanged. Coverage:
16 widget tests (locale, semantics, merged shapes, connectors, boundary
edge cases) in `activity_calendar_view_test.dart`, a new
`integration_test/issue089_streak_calendar_header_and_connected_streak_test.dart`
driving the real app, and 4 new golden tests (en/de × light/dark) in
`test/golden/activity_calendar_golden_test.dart`. Screenshot in
`issues/done/`.

## Code review

- New golden tests ship only macOS baselines; CI (`ubuntu-latest`) runs
  plain `flutter test` with no linux baseline to compare against.
  Not fixed here: generating the `linux/` baselines requires running the
  repo's `update-goldens.yml` `workflow_dispatch` job on `ubuntu-latest`
  (AGENTS.md's documented fallback — can't be done from this macOS
  machine), which needs this branch pushed to the remote first; raising
  with the user alongside the merge question rather than deciding alone.
- A month label anchored by its left edge at the very last (rightmost)
  week-column had no header space to bleed into and would get hard-clipped
  by the `Stack`'s own bounds.
  Fixed: the last column's label now anchors by its *right* edge instead,
  growing leftward into always-available space; added a regression test.
- `_kindOf`'s doc comment overstated that a day can *never* carry both
  `isCurrentStreak` and `isLongestStreak` — `ActivityCalendarData.build`'s
  `longestDiffers` only checks the two day-sets aren't exactly equal, not
  disjoint, so a subset overlap is possible (pre-existing #084 precedence,
  not a new bug).
  Fixed: reworded the comment to describe the precedence without the
  overstated "never" guarantee.
- The weekday-letter lookup used `DateTime.add(Duration(days: ...))`,
  inconsistent with this codebase's stated convention (`activity_calendar.
  dart`'s header comment) of calendar-field arithmetic to avoid DST
  off-by-ones elsewhere in date math.
  Fixed: switched to the same `DateTime(y, m, d + n)` field-arithmetic
  style, even though the fixed non-DST reference date made the `Duration`
  version practically safe.
- No test exercised a highlighted run ending on the Saturday of the very
  last week-column (no following column to attempt a connector against).
  Fixed: added a regression test confirming no dangling/erroring connector.
- No test covered an empty `data.days` window, or a run starting at the
  very first real row of the leftmost column.
  Not fixed: both are already structurally safe by inspection (empty-list
  loops are no-ops; `_kindOf(null)` short-circuits leading-null padding
  the same as any other row) and low marginal value for the time cost.
