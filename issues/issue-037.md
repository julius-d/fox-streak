# Issue 037: XP goal ring center label can overlap/clip the ring arc

Status: open | Priority: P3 | Type: bug

## Goal
Fix `FoxGoalRing`'s center label (`lib/src/widgets/fox_goal_ring.dart`) so
the "{earnedXp} / {goalXp} XP today" text (`homeGoalRingValue` in
`lib/l10n/app_en.arb` / `app_de.arb`) never visually overlaps or clips
against the circular progress arc.

Root cause: the widget's `Stack` fills the whole `size` (default 96px) box
with `SizedBox.expand(child: CircularProgressIndicator(...))` and centers
the `centerLabel` `Text` directly on top via `alignment: Alignment.center`
— there is no `Padding`/width constraint/`FittedBox` shrinking the text's
layout box to the ring's inner diameter (~`size - 2 * strokeWidth`, i.e.
~76px), and no `maxLines`/`overflow` set. The real string is wider than a
plain "30 of 30 XP" guess — e.g. "30 / 30 XP today" — and device text-scale
settings aren't accounted for either, so two-digit/two-digit values (or any
larger font scale) can spill past the arc. `HomeScreen`
(`lib/src/home/home_screen.dart`) always instantiates the ring at the
default 96px size with no override, so this isn't a one-off call-site
issue.

Found alongside #036 while investigating a user report of the ring's text
overlapping the wheel.

## Acceptance criteria
- [ ] The center label is constrained to fit within the ring's inner
      diameter (box size minus `2 * strokeWidth` plus a small margin) at
      the default system font size, with no visual overlap onto the arc.
- [ ] Behavior at larger device text-scale settings (accessibility large
      fonts) degrades gracefully — e.g. via `FittedBox`/`maxLines: 1` with
      scale-down, not unbounded clipping — rather than crashing or
      silently overflowing past the ring.
- [ ] No change to `FoxGoalRing`'s public API (`value`, `centerLabel`,
      `size`, etc.) beyond internal layout — existing call site in
      `home_screen.dart` keeps working unmodified.
- [ ] A widget test renders `FoxGoalRing` with a long/two-digit
      `centerLabel` (e.g. "30 / 30 XP today") at both default and a scaled
      text-scale factor, and asserts the label's rendered size stays within
      the ring's inner bounds (no `RenderFlex overflow`/clipped paint
      outside the expected box).
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
      `dart fix --dry-run`, `flutter test` stay clean/green.

## Out of scope
- #036 (the separate staleness bug where the ring shows a previous day's
  "full" `todayXp`/`dailyGoalXp` values instead of resetting for a new,
  inactive day) — not fixed here.
- Any redesign of the ring's visual style, size, or stroke width beyond
  what's needed to fit the label — follows #015's existing kit, no new
  colors/shapes.
- `FoxLevelProgressBar` or any other widget's label layout — unrelated to
  this ring.

## Dependencies
- Builds on #015 (`FoxProgressBar`/ring kit) and #010 (goal ring usage on
  Home).
- Touches `lib/src/widgets/fox_goal_ring.dart`; no `lib/src/data/` or
  `lib/src/home/home_screen.dart` changes expected beyond the new test.

## Verify
```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
# Manual: on a device/emulator with system font scale set to the largest
# accessibility setting, open Home and confirm the goal ring's label stays
# inside the ring, not overlapping the arc.
```
