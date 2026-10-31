# Issue 088: StreakBadge's tap target is short of the 48dp a11y floor

Status: open | Priority: P3 | Type: bug

## Context

Issue #084 made Home's `StreakBadge` (#011,
`lib/src/widgets/streak_badge.dart`) tappable (wrapped in an `InkWell`,
`lib/src/home/home_screen.dart`), opening the new `StreakDetailsScreen`.
Found during #084's code review: the badge's rendered height is its icon
(24dp) plus `FoxSpacing.sm` (8dp) padding top and bottom = 40dp — short of
AGENTS.md's documented 48dp a11y floor (`FoxButtonMetrics.minSize`), which
every other tappable kit widget (buttons, the pet avatar, `CoinBadge`'s
sibling-shaped but non-tappable layout) enforces.

Not fixed directly in #084: `StreakBadge` is also rendered non-interactively
elsewhere (the lesson result/streak-saved screens), and it has its own
golden-test coverage (`test/golden/kit_golden_test.dart`) — resizing it
touches more than just Home's new tap target and needs its own baseline
regeneration pass, so it's tracked separately rather than folded in.

## Goal

Give the Home tap target a 48dp minimum hit area without changing
`StreakBadge`'s own visual size elsewhere (e.g. wrap the `InkWell` in a
`ConstrainedBox`/`SizedBox` with `minHeight: FoxButtonMetrics.minSize`, or
pad the `InkWell` itself) — same look, compliant hit area.

## Acceptance criteria

- [ ] Home's streak-badge tap target is >= 48dp tall.
- [ ] `StreakBadge`'s rendered/visual size is unchanged on Home and on the
      lesson result/streak-saved screens (no golden-test diffs there).
- [ ] A widget test asserts the tap target's height/hit-area meets the
      48dp floor.

## Out of scope

- Resizing `StreakBadge`'s own icon/padding/visual layout.

## Dependencies

- Follows #084 (made the badge tappable) and #015/#011 (the a11y floor and
  `StreakBadge` itself).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
