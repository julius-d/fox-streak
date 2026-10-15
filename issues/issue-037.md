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

## Summary (expanded mid-implementation, see below)
Initial fix (label overlap only) was superseded by a fuller rework the user
asked for after reviewing the first pass: the single-line "fit-to-shrink"
label was unreadable once squeezed into the ring, so the scope grew into a
redesign rather than a layout patch.

Final shape of `FoxGoalRing`:
- **Two-line label**: `primaryLabel` (e.g. "14 XP") + `secondaryLabel`
  (e.g. "today") replace the old single `centerLabel` — the goal amount
  itself is no longer restated in text, since the ring's fill already
  conveys it. New l10n keys `homeGoalRingXp` / `homeGoalRingToday` (en/de,
  arb + hand-written `app_localizations.dart`); `homeGoalRingValue` (the
  full "N / M XP today" ratio) stays for `semanticsValue` so screen readers
  still get the exact numbers.
- **Overflow-aware fill**: `value` is no longer clamped to `1.0`. Each
  whole number is one completed "lap"; laps beyond the first nest inward
  as additional filled circles (fitness-tracker style) instead of just
  looking "full". Pure lap math extracted into `@visibleForTesting`
  top-level functions (`foxGoalRingLapGeometry`,
  `foxGoalRingVisibleNestedLaps`) for direct unit testing.
- **Custom-painted ring**: replaced `CircularProgressIndicator` with a
  `CustomPainter` (needed for the multi-lap draw and partial-lap arcs);
  thinner stroke (10 -> 7), default `size` bumped 96 -> 120 to leave room
  for nested laps without crowding the label.
  **Still rounded**: every arc/lap keeps `StrokeCap.round` end-caps.
- **Animated fill**: wrapped in `TweenAnimationBuilder` (700ms,
  `easeOutCubic`) so the ring eases to its new value instead of snapping,
  including rolling into a new lap.
- Label is still constrained via `Padding` + `FittedBox(scaleDown,
  maxLines: 1)` to the clear center the painter always keeps free of
  nested laps — same overlap-safety guarantee as the original fix, now
  sized from a `size`-relative fraction instead of a fixed margin.
- Public API changed (`centerLabel` -> `primaryLabel`/`secondaryLabel`);
  the one call site (`home_screen.dart`) was updated.

Tests: widget tests for label rendering/semantics, label-fits-in-bounds at
default and 3x text scale, overflow-past-100% animates without throwing;
unit tests for both extracted lap-geometry functions (below/exactly/past
one lap, negative-value clamp, nested-lap capping). Updated
`integration_test/home_screen_test.dart` to assert the real post-lesson
Home screen shows the new "N XP" / "today" label end-to-end.

Visually checked via a scratch golden-image render (ring shape/overflow
nesting/stroke) and the real integration test run on `-d macos` (confirmed
pre-existing #038 is Android-emulator/locale-specific — this test passes
cleanly on macOS, where the fresh #037 label assertions also pass).

Filed #038 (pre-existing, unrelated `home_screen_test.dart` integration-test
failure on the Android emulator, reproduces on unmodified `main`) rather
than fixing it here.

## Code review
- The square padding box (`EdgeInsets.all(labelMargin)`) has corners
  slightly past the inner clear circle, so a near-square-aspect label
  could theoretically poke a nested lap.
  Not fixed: no real risk for this app's actual labels ("NN XP" /
  "today" are both much wider than tall); revisit if the label shape
  changes.
- The widget test hardcodes `ringSize`/`labelClearRadius` literals
  instead of deriving them from `FoxGoalRing`'s private constants.
  Not fixed: duplication is intentional so the test is an independent
  check, not a tautology against the implementation.
- At an exact integer lap boundary (e.g. 1.9999 -> 2.0001) the outer
  sweep hard-resets from ~full to ~0 instead of rolling over smoothly.
  Not fixed: inherent to the chosen lap semantics, identical at every
  boundary, and masked by the 700ms ease — cosmetic, not a logic bug.
- A full (100%) sweep with `StrokeCap.round` can show a faint seam
  where the rounded start/end caps meet at the top.
  Not fixed: pre-existing quirk shared with the old
  `CircularProgressIndicator`-based ring, not a new regression.
- The rewritten "goal ring ... announces" widget test checks
  `CustomPaint` exists but no longer inspects the actual painted
  value/color like the old `CircularProgressIndicator`-based test did.
  Not fixed: the extracted `foxGoalRingLapGeometry`/
  `foxGoalRingVisibleNestedLaps` unit tests cover the math directly;
  accepted as a reasonable tradeoff of moving to a `CustomPainter`.
