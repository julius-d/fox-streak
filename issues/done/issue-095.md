# Issue 095: Extract a shared reward-reveal dial/animation widget

Status: done | Priority: P3 | Type: chore
Completed-at: 2026-11-01

Note: originally filed as #093, renumbered to #095 before completion — #093
was already taken by an unrelated, already-done issue (docs/question-set
format); see #096 for the backlog numbering-collision bug this surfaced.

## Context

Found during #085's (Wheel of Fortune) code review. `WheelScreen`'s
`_WheelDial` (`lib/src/lesson/wheel_screen.dart`) and `LootboxScreen`'s
`_LootboxAnimation` (`lib/src/pet/lootbox_screen.dart`) independently
implement the same shape: an interactive-vs-revealed visual, gated by
whether a tap handler is present, wrapped in an `InkWell` +
`Semantics(button: true, label: ...)` when interactive and a plain
`Semantics(label: ..., image: true)` when not, both sized to at least
`FoxButtonMetrics.minSize`. `wheel_screen.dart`'s own doc comment already
calls out the duplication ("mirrors `LootboxScreen`'s
`_LootboxAnimation`") but neither was extracted into the shared
`lib/src/widgets/` kit. A future a11y tweak (hit-target size,
`excludeSemantics`, tap feedback) applied to one and not the other would
leave the two reward screens inconsistent.

## Goal

Extract the shared interactive/revealed-gating + `InkWell`/`Semantics`
wrapper shape into one `lib/src/widgets/` kit widget, parameterized by
the actual visual (Lottie for the lootbox, `CustomPaint` wheel for
`WheelScreen`) and the interactive/non-interactive label. Update both
`LootboxScreen` and `WheelScreen` to use it.

## Out of scope

- Any visual/behavioral change to either screen — this is a pure
  extraction, no new UI.
- The streak-saved/XP-up screens, which don't share this
  interactive-reveal shape.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

Added `FoxRevealTapTarget` (`lib/src/widgets/fox_reveal_tap_target.dart`):
gated by `onTap`, with an optional `semanticLabel` for the non-interactive
case (`null` renders the child unwrapped, matching `LootboxScreen`'s
mid-animation state exactly). `_WheelDial` and `_LootboxAnimation` now
both delegate to it; no visual/behavioral change, all existing keys
(`wheelSpinButton`, `lootboxOpenButton`, `wheelDial`, `lootboxAnimation`)
preserved. New widget tests cover all three gating branches.

## Code review

No findings — reviewer confirmed both call sites' branches (interactive,
non-interactive-with-label, non-interactive-without-label) are reproduced
exactly, and existing key-based tests still pass.
Not applicable — nothing needed fixing.
