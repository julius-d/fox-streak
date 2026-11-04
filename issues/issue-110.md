# Issue 110: No golden-test coverage for FoxIceCubeIcon / StreakBadge

Status: open | Priority: P3 | Type: chore

## Goal

`test/golden/kit_golden_test.dart` (#019) snapshots every other #015 kit
widget in both `FoxStreakTheme.light()`/`.dark()`, but neither
`StreakBadge` (#011, reworked in #108 to a per-day icon row) nor the new
`FoxIceCubeIcon` (#108, a hand-drawn `CustomPainter` shape — Flutter's
bundled Material icon font has no literal ice-cube glyph) has a golden
baseline. A future tweak to `FoxIceCubeIcon`'s RRect radius, highlight
path, or fill math — or to `StreakBadge`'s layout — would pass every
existing test (they only assert `find.byType`/`find.byIcon`, not pixels)
without any pixel-level check catching a visual regression.

## Acceptance criteria

- [ ] `FoxIceCubeIcon` and `StreakBadge` each get a golden entry in
      `test/golden/kit_golden_test.dart`, light + dark, following that
      file's existing `_expectGolden` pattern.
- [ ] macOS baselines committed from a local run; Windows/Linux baselines
      regenerated per AGENTS.md's existing per-OS golden-test workflow
      (Linux needs the `workflow_dispatch` CI job on `ubuntu-latest`).

## Out of scope

- Any other kit widget's golden coverage.

## Found during

#108 (streak badge per-day icon row + shared ice-cube icon) — code review
flagged the gap; not fixed there since adding new golden baselines across
all three platforms is more than a "small and easy" addition to that
issue, and the gap pre-dates #108 for `StreakBadge` itself.
