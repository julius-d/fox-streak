# Issue 037: XP goal ring center label can overlap/clip the ring arc

Status: done | Priority: P3 | Type: bug
Completed-at: 2026-10-15

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
- [x] The center label is constrained to fit within the ring's inner
      diameter (box size minus `2 * strokeWidth` plus a small margin) at
      the default system font size, with no visual overlap onto the arc.
- [x] Behavior at larger device text-scale settings (accessibility large
      fonts) degrades gracefully — e.g. via `FittedBox`/`maxLines: 1` with
      scale-down, not unbounded clipping — rather than crashing or
      silently overflowing past the ring.
- [x] No change to `FoxGoalRing`'s public API (`value`, `centerLabel`,
      `size`, etc.) beyond internal layout — existing call site in
      `home_screen.dart` keeps working unmodified.
- [x] A widget test renders `FoxGoalRing` with a long/two-digit
      `centerLabel` (e.g. "30 / 30 XP today") at both default and a scaled
      text-scale factor, and asserts the label's rendered size stays within
      the ring's inner bounds (no `RenderFlex overflow`/clipped paint
      outside the expected box).
- [x] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
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

## Summary
`FoxGoalRing`'s center label is now wrapped in `Padding` (margin = stroke
width + 4) + `FittedBox(fit: scaleDown)` with `maxLines: 1`, so it's always
confined to a fixed box inside the ring's inner diameter and shrinks to fit
rather than overflowing at large text-scale. No public API change. Added a
widget test (`test/widgets/kit_test.dart`) asserting the label's bounding
box stays within the inner diameter at both default and 3x text scale.

Filed #038 (pre-existing, unrelated `home_screen_test.dart` integration-test
failure on device/emulator, reproduces on unmodified `main`) rather than
fixing it here.

## Code review
- The square padding box (`EdgeInsets.all(strokeWidth + 4)`) has corners
  slightly past the inner circle, so a near-square-aspect label could
  theoretically poke the arc.
  Not fixed: no real risk for this app's actual labels ("NN / NN XP
  today" is always much wider than tall); revisit if the label shape
  changes.
- The new widget test hardcodes `ringSize`/`strokeWidth` literals instead
  of deriving them from `FoxGoalRing`'s (private) constant.
  Not fixed: duplication is intentional so the test is an independent
  check, not a tautology against the implementation.
