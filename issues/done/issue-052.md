# Issue 052: Fix category picker wrapping on narrow phone screens

Status: done | Priority: P3 | Type: bug | Refined-at: 2026-10-17 | Completed-at: 2026-10-17

## Goal

The set-creation/edit screen's category picker (`set_editor_screen.dart`,
`SegmentedButton<String>` with `vocab`/`math`/`geography`/`general`
segments, added by #045) looks broken on narrow phones: Material lays out
all 4 icon+label segments stretched to equally share the available width,
and at phone widths there isn't enough room per segment, so longer labels
wrap mid-word (e.g. "Geography"/"Geografie" renders as 3 lines, something
like "Geo" / "grap" / "hy"). Existing widget tests use the default 800×600
test surface, so this never showed up there — it only reproduces at real
phone widths.

## Decision (2026-10-17, with repo owner)

- Wrap the `SegmentedButton` in a horizontally **scrollable** row
  (`SingleChildScrollView(scrollDirection: Axis.horizontal)`, or
  equivalent) instead of letting it stretch to the available width. This
  keeps every segment at its natural intrinsic width — icon + label on one
  line — rather than Material's current unconditional column-wrap when a
  stretched segment is narrower than its label.
- Each segment's label stays single-line (no text wrapping) at any screen
  width; on narrow phones some segments may be scrolled off-screen and
  reachable by swiping, instead of wrapping or shrinking.
- Target minimum width: **360dp** (smallest common Android phone size) —
  all 4 segments must render single-line labels with no overflow/wrap at
  that width, verified both in `en` and `de` (German labels are generally
  longer: "Geografie", "Allgemein").
- Keep the existing 48dp min segment size from the #015 kit
  (`FoxButtonMetrics.minSize`) — unchanged by this fix.
- Scrollability needs to be visually discoverable (not just functional) —
  e.g. the row should show a segment partially cut off at the edge when
  more content exists, rather than looking like exactly 4 segments fit
  with nothing to scroll to. Exact treatment (fade edge, partial segment,
  etc.) is an implementation detail left to whoever picks this up.

## Acceptance criteria

- [x] Category picker in `set_editor_screen.dart` is wrapped in a
      horizontally scrollable container; segments keep their intrinsic
      (unstretched) width.
- [x] No segment label wraps to multiple lines at any screen width, in
      both `en` and `de`.
- [x] At 360dp width, all 4 segments are reachable (by scrolling if
      needed) with single-line labels and no horizontal overflow error.
- [x] When the row overflows, there's a visible cue that more content is
      scrollable (e.g. a partially visible next segment).
- [x] 48dp min segment size (#015 a11y floor) preserved.
- [x] New widget test: renders `SetEditorScreen` at a narrow surface size
      (360dp wide) and asserts the category segments render without
      wrapping/overflow (e.g. assert each label `Text` renders on a single
      line, or assert no `RenderFlex` overflow error is thrown) — this is
      a general regression guard against this class of narrow-screen
      layout bug, not just this one picker.
- [x] `flutter analyze` / `dart format` / `dart fix --dry-run` /
      `flutter test` clean.

## Out of scope

- Redesigning the category picker's visual style (chips vs. segmented
  button vs. grid) — this issue only fixes the wrapping/overflow bug within
  the existing `SegmentedButton` pattern.
- Auditing other screens for similar narrow-width wrapping bugs — may be
  worth a follow-up issue if more are found, but not pulled in here.

## Dependencies

- Builds on #045 (introduced the `SegmentedButton` category picker) and
  follows the #015 kit's a11y floor (48dp min target size).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

Wrapped the category `SegmentedButton` in `SingleChildScrollView(scrollDirection:
Axis.horizontal)` so segments keep their intrinsic single-line width instead
of being stretched by the enclosing `ListView`. New widget test
(`test/library/set_editor_screen_test.dart`) pumps at 360dp in en/de; new
integration test (`issue052_category_picker_scroll_test.dart`) scrolls to and
selects the off-screen "General" segment through the real app. Screenshots:
`issue052-category_picker_{en,de}_360dp.png`.

## Code review

- Fix makes the picker always use its intrinsic (unstretched) width, even on
  screens wide enough that the old stretched layout spanned the full row.
  Not fixed — this is the explicit behavior the issue's Decision section
  calls for ("instead of letting it stretch to the available width"), not a
  width-conditional one.
- `softWrap: false` on segment labels was redundant (layout already
  guarantees single-line) and would silently clip instead of wrap if a
  future change ever reintroduced a tight width, conflicting with the kit's
  "never clipped" a11y floor. Fixed — removed.
- Reviewer flagged "no visual scroll affordance" on narrow screens.
  Not fixed — already satisfied: the 360dp screenshots show the next
  segment cut off at the edge, which is the exact treatment the issue's
  Decision section suggested.
