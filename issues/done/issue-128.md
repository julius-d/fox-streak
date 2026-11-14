# Issue 128: Streak Details glow-up — flame hero, clean streak bands, animations

Status: done | Priority: P3 | Type: enhancement | Refined-at: 2026-11-14 | Completed-at: 2026-11-14

## Goal

The Streak Details screen (reached by tapping Home's streak badge) should
feel like a reward, not a debug view. Today it is three plain text lines, a
small GitHub-style grid and a lot of empty space. Its streak highlight also
looks broken: when a streak runs from Saturday into Sunday, small stubs show
at the column edges instead of the streak reading as one run (visible on
Android, and in #089's own screenshot `issues/done/issue-089-streak-details-calendar.png`).

Keep the GitHub-style overview as the core of the screen, but fix how streaks
look across week breaks, add a flame "hero" with key stats at the top, make
days tappable, and add a few motivating animations using the flame and the
snowflake.

## Desired behavior

### Hero (top of the screen)

- A large flame with the current streak number, e.g. "🔥 42 — days in a
  row!".
- Below it, one short encouraging line that depends on the situation (copy
  is a suggestion, final wording in DE + EN at implementation):
  - **practiced today**: celebrating ("You're on fire! See you tomorrow.")
  - **not practiced yet today, streak alive**: a friendly nudge ("Practice
    today to keep your streak going.")
  - **no streak (0)**: an invitation ("Start a new streak today!"), with a
    dimmed flame.
  - Never shaming, no "you lost your streak" tone.
- A row of three small stat tiles under the hero:
  - **Longest streak**: the all-time record. Freeze days count toward a
    streak, as they do today. It is never shown smaller than the current
    streak.
  - **Practice days**: the total number of days actually practiced,
    all-time. Streak-freeze days do **not** count here.
  - **Streak freezes**: how many the learner owns, shown with the icy-blue
    snowflake (same icon as #127).
- "All-time" means all history the app has stored, i.e. from the moment
  daily activity started being recorded (#084). Older practice isn't added
  back.
- The tiles replace today's three text headlines (current streak / longest
  in 6 months / freezes available). At large font sizes the tiles wrap onto
  more lines (or stack) instead of clipping.

### Activity overview (GitHub-style grid, kept)

- Same concept as today: one cell per day, week columns, oldest on the
  left, today on the right, horizontal scrolling, opens scrolled to today,
  month labels as in #089.
- **Monday-first weeks** (new, for all languages): each week column runs
  Monday (top) to Sunday (bottom), instead of today's Sunday-first.
  The sparse weekday letters stay on the Mon/Wed/Fri rows, which are now the
  1st, 3rd and 5th rows. Month labels keep #089's rule (above the first
  column whose top day starts a new month).
- **History range**: the learner can always scroll back at least ~6 months,
  and further back to the very first recorded practice day if that is older.
  A current streak longer than 6 months is therefore fully visible.
- **No intensity shades anymore**: a cell is either *practiced* (flame
  tone), *saved by a streak freeze* (icy blue, #087), or *no practice*
  (neutral). XP per day moves into the tap popup (below).
- **Cell size about 20dp** (today 14dp): roughly 3 months visible at once on a
  360dp phone. It's easier to read and tap and still reads as an overview.
- **Streak highlight**: the current streak (flame color) and the all-time
  longest streak (second color, only if it is a different run than the
  current streak) are each marked as one continuous band around their days.
  - Within a week column the band is rounded at the run's real start and
    end.
  - Where a run crosses a week break (Sunday → next Monday), the band is
    **open** at the bottom of the first column and **open** at the top of
    the next column. It reads as "continues there". No stubs, no notches,
    nothing poking out of the grid.
  - A day in both runs shows the current-streak color only (unchanged
    precedence).
- **Today** is clearly marked (e.g. a ring), whether or not it's practiced.
- Legend under the grid: practiced, saved by a streak freeze, no practice,
  current streak, and longest streak. The longest-streak entry appears only
  when that band is shown.

### Tap a day

- Tapping a day shows a small popup / bubble anchored at that day:
  - the date
  - "N XP earned", or "Saved by a streak freeze ❄️", or "No practice", or for
    today without practice: "Not practiced yet today"
- Tapping elsewhere, scrolling, or tapping another day dismisses or replaces
  it. Only one popup is open at a time. Empty padding cells (before the
  first day of the range) aren't tappable.
- Screen readers keep reading the per-day labels. The popup is an extra for
  sighted touch users, not the only way to get the information.

### Animations

All animations are short and play each time the screen opens. They are
skipped when the system "reduce motion" setting is on; then the final state
shows immediately.

- **Count-up + flame flicker**: the streak number counts up from 0 to the
  current value in at most ~1 second, however long the streak; the hero
  flame gently flickers/pulses. With a 0 streak there is no count-up and the
  dimmed flame stays still.
- **Streak band draws in backwards**: the current-streak band starts at
  today and grows back through the streak, day by day (including across
  week breaks), to the streak's first day. The visible part animates right
  away even when the streak starts off-screen.
- **Today pulse**: whenever today isn't practiced yet (with or without a
  live streak), the today cell gently pulses, matching the hero's nudge or
  invitation line. It's gone once today is practiced.

### Relation to #127

#127 adds a snowflake in front of the "N streak freezes available" line on
this screen. This issue replaces that line with the freezes stat tile. If
#127 lands first, its snowflake moves into the tile; the tile then satisfies
#127's Streak Details criterion.

## Acceptance criteria

- [x] Hero shows a large flame with the current streak number and a
      situation-dependent encouraging line (practiced today / not yet today /
      no streak); the 0-streak state uses a dimmed flame and inviting copy.
- [x] Stat tiles show all-time longest streak (freeze days included, never
      below the current streak), all-time practice days (freeze days
      excluded), and the number of streak freezes owned with the icy-blue
      snowflake.
- [x] The three old text headlines are gone; at large font sizes the tiles
      wrap/stack without clipping.
- [x] Grid keeps the GitHub-style layout with ~20dp cells, scrolls back at
      least ~6 months and further to the first recorded practice day if
      older, and opens scrolled to today.
- [x] Cells show only three states (practiced / streak freeze / none); the
      legend matches and explains the current and (when shown) longest streak
      bands.
- [x] Week columns are Monday-first (Mon top, Sun bottom) in every
      language; weekday letters sit on the Mon/Wed/Fri rows; month labels
      still sit above the first column of each month.
- [x] A streak crossing a Sunday→Monday break renders with open band ends
      at both column edges; no stubs or notches stick out of the grid.
- [x] Longest-streak band shows only when it is a different run than the
      current streak; shared days use the current-streak color.
- [x] Today is visually marked. Tapping a day shows a popup with the date and
      XP / freeze / no practice / not yet today. Only one popup is open at a
      time, and it closes on outside tap or scroll.
- [x] Count-up (≤ ~1 s), flame flicker, backwards band draw-in, and today
      pulse play as described each time the screen opens. All are skipped
      with reduce motion on.
- [x] Looks right in light and dark theme, at large font sizes, and on a
      small (360dp) Android phone.
- [x] Screen readers get the hero/stat values and per-day labels; decorative
      animations, icons and header labels are not announced separately.
- [x] Widget tests cover the three hero states, the stat values (incl.
      freeze days excluded from practice days), the day popup texts, and
      reduce-motion behavior.
- [x] Golden tests (#019) cover the hero and a streak band crossing a week
      break, in light and dark theme. Changed baselines are updated.
- [x] An integration test drives the real app to the Streak Details screen
      and checks hero, grid, and day popup.
- [x] Follows #015 (kit reuse, semantic colors, a11y labels, DE + EN strings).
- [x] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
      `tool/check_issues.sh`, `dart fix --dry-run`, and `flutter test` are
      clean per AGENTS.md.

## Out of scope

- Any change to how streaks, freezes, or XP are counted (#011, #087).
- A week-start setting or locale-dependent week start (Monday-first for
  everyone).
- Backfilling practice from before daily activity was recorded (#084).
- Home's streak badge (stays the entry point, unchanged).
- The fox on this screen; the flame is the hero.

## Dependencies

- #127 (snowflake as the one streak-freeze icon), used in the freeze stat
  tile; see "Relation to #127".
- Builds on #084 / #087 / #089 (Streak Details screen, freeze days,
  labels + connected highlight).

## Summary
- Data: `ActivityCalendarData.build` now reads all `daily_activity` rows (`getAllDailyActivity`); window = max(6 months, first recorded day). Three `ActivityDayState`s replace the XP buckets; `longestStreak` (≥ current), `practiceDays` (freezes excluded), `showLongestStreakBand` (only when strictly longer than the current streak).
- Grid: Monday-first `groupIntoWeeks`, 20dp cells, `computeStreakBandSegments` (pure, with `openTop`/`openBottom` + `daysAfter` for the backwards draw-in) painted by `StreakBandPainter`. Today ring + pulse, tap popup via `OverlayPortal`. Header labels now scale with the font (clamped 2×).
- Hero + stat tiles in `streak_details_hero.dart`; shared animation timing in `streak_motion.dart`. All animations are bounded and skipped under reduce motion. The freezes tile carries #127's `FoxStreakFreezeIcon`, which replaces #127's balance line on this screen.
- Goldens: `activity_calendar_*` updated, `streak_hero_*` new (macOS baselines; Linux via `update-goldens.yml`).
- Screenshots: `issue-128-practiced-light.png`, `-day-popup`, `-not-yet-today-dark`, `-no-streak`, `-large-font`.

## Code review
- A freeze day inside the current run pushed the run's first day out of the band (`streakCount` doesn't count freezes), so a gold "longest" band showed on the same run.
  Fixed: `currentStreakDays` skips freeze days when counting; the longest band needs a non-overlapping run. Three test fixtures (Home, #108, #127) that had counted the freeze were corrected.
- A broken streak (2+ missed days) still shows as alive in the hero and band.
  Not fixed: out of scope (streak counting is unchanged), filed as #131.
- Linux golden baselines are stale or missing.
  Fixed after merge via `update-goldens.yml`.
- `didUpdateWidget` called `setState` to dismiss the popup.
  Fixed: state is cleared directly (build follows anyway).
- The hero doesn't restart its animations when data or reduce motion changes while the screen is open.
  Not fixed: the data can't change while this screen is open; per spec, animations play when the screen opens.
- `longestRun` was quadratic over the now-unbounded history.
  Fixed: index-based, linear.
- Home and the calendar now load and build the full history (all rows, every cell eagerly).
  Not fixed: one row per day stays small (about 1,100 cells after 3 years); revisit if it shows in profiling.
- The stat tiles stack at default font size on 320dp phones.
  Not fixed: stacking is the intended non-clipping fallback.
- An over-long comment line in `home_screen.dart`.
  Fixed.
