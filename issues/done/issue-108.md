# Issue 108: Streak bar shows one flame per streak day

Status: done | Priority: P2 | Type: feature | Refined-at: 2026-11-04 | Completed-at: 2026-11-04

## Context

Home's streak badge (`StreakBadge`, `lib/src/widgets/streak_badge.dart`)
currently renders a single flame icon plus the streak count as a number,
e.g. "🔥 15". It doesn't visually communicate *how* those 15 days were
earned. #087 ("Streak on ice") already lets a missed day be auto-saved by a
streak-on-ice instead of resetting the streak, and gave that kind of day its
own icy-blue identity in the Streak Details calendar — but the compact Home
badge still shows every streak day the same way, with no sense of the
streak's length or shape at a glance.

## Goal

The Home streak badge shows one small icon per day of the current streak,
most recent day last, instead of a single static flame: a flame for a day
that was actually practiced, and an ice-cube icon for a day that was
auto-saved by a streak-on-ice (#087). The numeric streak count stays next to
the icon row so the exact total is always readable, even once the row is
too long to show every day. The badge is hidden entirely while there's no
active streak to show.

## Decisions

- **Scope: Home's streak badge only.** The Streak Details calendar (#087)
  already has its own established "icy-blue cell" treatment for frozen days
  and is unchanged by this issue.
- **One icon per day, oldest → newest, left → right.** The rightmost icon
  is always the most recent day counted in the streak (today, once today's
  activity is done — see below).
- **Flame vs. ice per day**: a day is rendered as a flame if it has normal
  practice activity, or as an ice-cube icon if it was saved by a
  streak-on-ice (`DailyActivitySource.streakOnIce`, #087) — reusing the same
  icy-blue color #087 established, just as a small icon here instead of a
  calendar-cell color.
- **Ice-cube icon, replacing the existing snowflake everywhere it
  appears.** The coin shop's "buy a streak-on-ice" button currently uses a
  snowflake (`Icons.ac_unit`, `lib/src/shop/coin_shop_screen.dart`) for this
  same concept. Rather than introduce a second, inconsistent icon, this
  issue also swaps that existing snowflake for the new ice-cube icon, so
  "streak on ice" looks the same (ice cube, icy-blue) everywhere it shows up
  in the app, including the new Home icon row.
- **Fit-to-width, crop the oldest first.** The row shows as many icons as
  fit the badge's available width on that device/screen; when the streak is
  longer than that, older days are dropped from the left first, so the row
  always ends with the most recent days visible. There's no fixed icon-count
  cap chosen in this issue — it adapts to available space.
- **Keep the numeric count, unchanged.** The existing streak-count number
  stays next to the icon row (current label/position aside from sharing
  space with the new row) so the exact streak length is never ambiguous,
  regardless of how much the icon row got cropped.
- **"Today not yet done" is unchanged.** Today's separate completion
  checkmark (`todayDone`) keeps working exactly as it does now — it's not
  folded into or replaced by the new per-day icon row; today only gets a
  flame/ice icon in the row once it's actually part of the counted streak,
  same as any other day.
- **Decorative icons, one accessible summary.** The icon row is exposed to
  screen readers as part of today's single existing `semanticsLabel`
  summary (e.g. "15 day streak"), not as 15 individually-announced icons —
  matching the a11y floor in #015 (no per-icon semantic noise).
- **Data source**: which days were flame vs. ice comes from the same
  per-day activity history #084's Streak Details calendar already reads
  (`DailyActivitySource` per day) — no new data is introduced, only reused
  further back toward Home.
- **Zero-streak state: hide the badge entirely.** Today, Home always shows
  the streak badge, even at `streakCount == 0` (e.g. a brand-new user), as
  a bare "0" next to a flame. This issue changes that: at `streakCount ==
  0`, the whole badge — icon row and numeric count together — is not shown
  on Home at all, rather than displaying an empty/zero state.
- **Minimum one icon guaranteed**: even in an extreme narrow-width case
  (e.g. #012's large-font accessibility mode), the row always keeps at
  least the most recent day's icon visible rather than cropping down to
  zero icons once the streak is at least 1.

## Acceptance criteria

1. Home's streak badge renders a row of small icons, one per day of the
   current streak, instead of a single static flame icon.
2. A day with normal practice activity renders as a flame icon; a day saved
   by a streak-on-ice (#087) renders as a distinct ice-cube icon, in the
   same icy-blue color #087 already established.
3. The coin shop's existing "buy a streak-on-ice" button
   (`lib/src/shop/coin_shop_screen.dart`) swaps its current snowflake
   (`Icons.ac_unit`) for the same new ice-cube icon, so the concept looks
   identical everywhere in the app. Its price, confirm dialog, and purchase
   logic are unchanged — only the icon glyph changes.
4. Icons are ordered oldest to newest, left to right; the rightmost icon is
   the most recently counted day.
5. The icon row's icon count adapts to the available width of the badge; on
   a narrower screen or a longer streak, the oldest days are cropped first
   so the most recent days always remain visible.
6. The numeric streak count (e.g. "15") is still shown next to the icon
   row, and always reflects the true total streak length, independent of
   how many icons the row had room to show.
7. At `streakCount == 0`, the entire streak badge (icon row and numeric
   count together) is not rendered on Home at all — matching today's "no
   streak yet" state with nothing shown, instead of today's bare "0".
8. Today's existing "done" checkmark behavior is unchanged — it's not
   replaced or altered by the new icon row.
9. Tapping the badge still opens the Streak Details screen, unchanged
   (only reachable once the badge is shown, i.e. `streakCount >= 1`).
10. The icon row is exposed to screen readers as part of the single
    existing streak summary label, not as individually announced icons.
11. Both English and German strings (if any new label text is needed) flow
    via `lib/l10n` arb params, per AGENTS.md.
12. Golden-test baselines (#019) covering the streak badge and the coin
    shop's streak-on-ice button are reviewed and regenerated to reflect the
    new multi-icon layout and the icon swap.

## Out of scope

- Any change to the Streak Details calendar's existing icy-blue cell
  treatment (#087) — it still uses color only, no icon; only Home's compact
  badge gets the new icon row.
- Any change to streak math, the streak-on-ice auto-apply trigger, or the
  coin-shop purchase logic/pricing (#087, #091, #107) — the coin shop is
  touched only to swap its icon glyph (see acceptance criterion 3).
- A fixed/hardcoded maximum icon count — the row adapts to available width
  instead.
- Changing what counts as "today done" or when today joins the streak.

## Dependencies

- Builds on #087 (Streak on ice) for the icy-blue ice identity and the
  per-day `DailyActivitySource` data.
- Builds on #084's per-day activity history (already used by the Streak
  Details calendar) as the source of which past days were flame vs. ice.

## Code review

- Home's icon row used `.maybeWhen(..., orElse: () => [])` on a provider
  that reloads on every profile write, flashing the row empty on each one.
  Fixed — switched to reading `.value` (sticky across reload) instead.
- `FoxIceCubeIcon`'s shine hardcoded `Colors.white`, nearly invisible
  against dark theme's already-light-pastel ice token.
  Fixed — the overlay now picks black/white via
  `ThemeData.estimateBrightnessForColor(color)`.
- The "crops oldest first" kit test used all-flame icons, so a
  crop-direction regression (newest-first instead of oldest-first) would
  still pass.
  Fixed — rewrote it with the newest day as the sole ice icon in the list.
- `_IceCubePainter` allocated two new `Paint` objects on every `paint()`
  call.
  Fixed — hoisted them to fields computed once per painter instance.
- A streak longer than `activityCalendarProvider`'s ~6-month window only
  gets icons for the days inside that window, while the numeric count
  stays exact.
  Not fixed — matches the same accepted v1 edge case
  `ActivityCalendarData.build`'s own doc already calls out for
  `isCurrentStreak`; documented inline in `home_screen.dart` instead.
- Neither `StreakBadge` nor `FoxIceCubeIcon` has golden-test (#019) pixel
  coverage, so a future visual regression wouldn't be caught.
  Not fixed — pre-existing gap for `StreakBadge`, and adding baselines
  across all 3 platforms is bigger than a small in-issue fix; tracked as
  #110 instead.

## Summary

Home's `StreakBadge` now renders a fit-to-width row of small flame/ice
icons (oldest → newest, crops oldest first, always ≥1 icon) next to the
unchanged numeric count, sourced from the existing `activityCalendarProvider`
data (no new query) and hidden entirely at `streakCount == 0` (mirrors
`CoinBadge`'s `coinsTotal > 0` gate). Added `FoxIceCubeIcon` (a custom-painted
icon — Flutter's bundled icon font has no ice-cube glyph) and swapped it in
everywhere the old `Icons.ac_unit` snowflake appeared (coin shop + the new
row). Follow-up: #110 (golden-test coverage for the two new/changed
widgets).
