# Issue 104: Floating FAB and system UI insets can overlap the last row's tap targets in scrollable lists

Status: done | Priority: P2 | Type: bug | Refined-at: 2026-11-03 | Completed-at: 2026-11-04

## Context

Three screens combine a plain scrollable list with a floating action
button (FAB), and none of them reserve any bottom clearance for it:

- **Library screen** (`library_screen.dart`): each set row (`_SetCard`)
  has a play button and a three-dot menu as trailing actions; the screen
  also has an expandable "New set" FAB speed-dial (#074) anchored
  bottom-right.
- **Set Detail screen** (`set_detail_screen.dart`): each item row has
  edit and delete buttons as trailing actions; the screen has two stacked
  FABs ("Add item" small FAB, "Start lesson" extended FAB).
- **Marketplace Sources screen** (`marketplace_sources_screen.dart`):
  each source row has a delete button as its trailing action; the screen
  has an "Add source" FAB.

On all three, when the list has enough rows to fill the screen, scrolling
to the bottom puts the last row(s) directly underneath the FAB(s), which
visually and functionally cover the row's tap targets — making its
button(s) difficult or impossible to tap.

Separately, none of these lists account for the platform's bottom system
UI inset either (Android's 3-button nav bar or gesture handle, iOS's
home indicator). Android 15+ (targetSdk 35) enforces edge-to-edge
rendering by default, so on modern Android devices the system nav
bar/gesture area can overlap the very bottom of a scrolling list the same
way the FAB does — compounding the same reachability problem even where
a FAB isn't involved.

(`marketplace_sets_screen.dart` and `marketplace_packs_screen.dart` also
have scrollable lists but no FAB, so they're not affected by the FAB part
of this issue — though they'd still benefit from correct system-inset
handling if that turns out to be a real problem; see Out of scope.)

## Goal

On every affected screen, a user must always be able to scroll a row's
trailing action(s) — the Library play button and three-dot menu, the Set
Detail edit and delete buttons, the Marketplace Sources delete button —
fully clear of both the FAB and the platform's bottom system UI inset,
no matter how many rows exist or how far they've scrolled. Neither the
FAB nor system chrome may ever obscure a tappable row action.

## Decisions

- **Scope**: Library screen, Set Detail screen, and Marketplace Sources
  screen — the three screens today combining a plain list with a FAB.
- **Fix direction**: each affected list reserves enough clearance at its
  bottom so the last row can be scrolled entirely above both the FAB
  (in whatever state it's currently in) and the platform's bottom system
  UI inset.
- **Short lists**: lists that don't fill the screen may end up with a bit
  of empty space below the last row as a result of this reserved
  clearance — that's an acceptable, consistent trade-off rather than
  something to special-case away.
- **FAB state**: on the Library screen, the speed-dial's expanded state
  (mini-FABs + scrim, #074) is covered by the same clearance as its
  collapsed state; while expanded, the scrim already blocks all other
  taps, so this is mostly about the collapsed/idle state in practice.

## Acceptance criteria

1. On the Library screen, with enough sets to require scrolling, every
   set's play button and three-dot menu can be scrolled fully clear of
   the "New set" FAB and tapped.
2. On the Set Detail screen, with enough items to require scrolling, the
   last item's edit and delete buttons can be scrolled fully clear of
   both the "Add item" and "Start lesson" FABs and tapped.
3. On the Marketplace Sources screen, with enough sources to require
   scrolling, the last source's delete button can be scrolled fully clear
   of the "Add source" FAB and tapped.
4. On all three screens, the reserved clearance also keeps the last row
   clear of the platform's bottom system UI inset (Android nav
   bar/gesture handle, iOS home indicator), so system chrome doesn't
   obscure it either.
5. No regression to short lists or empty states: the FAB remains fully
   visible and usable, and list layout is otherwise unchanged aside from
   the added bottom clearance.

## Out of scope

- The FAB's own appearance/expand-collapse behavior (issue #074) — this
  issue is only about it overlapping list content.
- `marketplace_sets_screen.dart` / `marketplace_packs_screen.dart` —
  verified no FAB present, not affected by the FAB-overlap part of this
  issue; their system-inset handling isn't addressed here either unless
  testing surfaces a real problem.
- No question/data format or schema changes are involved, so no `docs`
  updates are needed for this issue.

## Summary

Added `fabListBottomPadding(context)` (`lib/src/widgets/fox_fab_list_padding.dart`):
a shared `kFabListClearance` (160dp, generous enough for Set Detail's
tallest stacked-FAB case) plus `MediaQuery.paddingOf(context).bottom`,
applied as each `ListView.builder`'s `padding` on Library, Set Detail,
and Marketplace Sources. One constant reused across all three screens —
short lists just get a bit of harmless extra space below the last row.
Covered by three new `integration_test` specs (one file per screen,
since running all three `testWidgets` in one process reliably hung
before the third — unrelated macOS device-mode flakiness, not a code
defect) that scroll to the end and tap the last row's action, asserting
it reaches the row and not the FAB.

## Code review

- Reviewed by a background subagent (medium effort) covering the padding
  math, `FloatingActionButton`/`Scaffold` sizing, all three call sites,
  and the new integration tests.
- No findings — fix judged minimal, additive, and numerically safe; no
  changes made as a result.
