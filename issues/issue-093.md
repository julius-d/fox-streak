# Issue 093: Extract a shared reward-reveal dial/animation widget

Status: open | Priority: P3 | Type: chore

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
