# Issue 042: Starting a lesson is buried — sticky start button + direct-start from Library list

Status: done | Priority: P1 | Type: UX

Completed-at: 2026-10-16

## Goal

From a cold start (no sets yet), getting into your first lesson takes four
taps with no visible "play" affordance until the very last screen: Home →
"Browse sets" → "Try demo" → tap a set → scroll past the whole item list →
"Start lesson" footer button at the bottom of `SetDetailScreen`
(`lib/src/library/set_detail_screen.dart:174-180`, via `LessonEntryButton`,
`lib/src/lesson/lesson_screen.dart:32-63`). Found while manually verifying
the Home screen (#012) flow. Make the core loop ("start practicing")
reachable in one tap from the Library list, and make the detail screen's
start action visible without scrolling.

## Decisions

- **`SetDetailScreen` FAB redesign**: replace the single `addItemFab`
  (`FloatingActionButton.extended`, "Add item") with two stacked FABs —
  `FloatingActionButton.extended` for "Start lesson" (primary, bottom) +
  `FloatingActionButton.small` for "Add item" (secondary, stacked above it).
  This replaces the `SliverToBoxAdapter` footer entirely — `LessonEntryButton`
  as a standalone widget goes away (its logic moves inline, since it's now
  driven by the same `itemsAsync` the Scaffold already watches, not a
  separate widget).
- **Library list direct-start**: add a play icon to each `_SetCard`'s
  trailing row (`lib/src/library/library_screen.dart:134-211`) that pushes
  `LessonScreen` directly, skipping `SetDetailScreen` entirely. No
  `backLabel` override needed: `LessonScreen`'s default
  (`l10n.lessonBackToLibrary`) is already correct here, since Library sits
  directly beneath Lesson on the nav stack once `SetDetailScreen` is
  skipped.
- **Empty-set tap feedback is a snackbar, not a disabled button**: both new
  "start lesson" entry points (Library row play icon, `SetDetailScreen`'s
  "Start lesson" FAB) stay enabled even when the set has 0 items — tapping
  shows a `SnackBar` with `l10n.lessonEmptySetNote` ("Add items to start
  practicing!", already used as `SetDetailScreen`'s empty-items copy)
  instead of navigating. Avoids a disabled icon reading as "broken" to a
  young user, and reuses existing copy instead of adding a new l10n string.
- **Row stops being a tap target**: adding a play icon into the row created
  a three-way tap-target conflict (whole-row `onTap` → `onOpen`, the new
  play icon, and the overflow menu, all in/near the same `ListTile`).
  Resolve it by removing `ListTile.onTap`/`onOpen` entirely — the row itself
  is no longer tappable. Add a dedicated edit icon button (`Icons.edit` or
  similar, 48dp, tooltip) to the trailing row that does what `onOpen` used
  to do (push `SetDetailScreen`). So each row ends with three explicit,
  unambiguous icon buttons: play (start lesson), edit (open detail/item
  list), overflow menu (rename/duplicate/delete) — no implicit row tap.
- **Make room by dropping the per-set type icons**: `_SetCard` currently
  shows one icon per distinct item type (choice/freeText/phone/date, added
  in #003) next to the overflow menu. Remove that icon row — it's decorative
  (type is already visible once you open the set) and the row needs the
  space for the new play icon. `item_type_icons.dart`'s `iconForItemType`/
  `colorForItemType` stay in use by `SetDetailScreen`'s per-item rows; only
  `_SetCard`'s aggregate icon list goes.
- Not addressed here: Home's primary "Continue" button falling back to a
  second, identically-labelled "Browse sets" CTA when no attempts exist yet
  (duplicate button) is a separate, already-identified issue — out of scope,
  filed on its own.

## Acceptance criteria

- [x] `SetDetailScreen` shows a persistent (non-scrolling) "Start lesson"
      action at all times the screen is open, including with a long item
      list — no scrolling required to find it.
- [x] "Add item" remains reachable on `SetDetailScreen` (secondary FAB),
      unchanged behavior otherwise.
- [x] Each set row in the Library list has a play affordance that opens
      `LessonScreen` for that set directly, with no intermediate screen.
- [x] Both new "start lesson" entry points (Library row play icon,
      `SetDetailScreen`'s "Start lesson" FAB) stay tappable for sets with 0
      items; tapping shows a `l10n.lessonEmptySetNote` snackbar instead of
      navigating.
- [x] The set row itself is no longer a tap target (`ListTile.onTap`
      removed); opening `SetDetailScreen` only happens via the new explicit
      edit icon button.
- [x] Per-set type icons are removed from the Library list row; item count
      text stays.
- [x] 48dp min targets + screen-reader tooltips/semantics on both new icon
      buttons (play on Library row, both FABs on detail) — follows #015.
- [x] `flutter analyze`, `dart format`, `flutter test` stay clean.

## Tasks

1. `SetDetailScreen`: inline the "Start lesson" logic (currently
   `LessonEntryButton`) into a two-FAB `floatingActionButton` (extended
   "Start lesson" + small "Add item"); delete `LessonEntryButton` and its
   `SliverToBoxAdapter` footer slot. "Start lesson" stays enabled when
   `items` is empty; `onPressed` shows the `lessonEmptySetNote` snackbar
   instead of navigating in that case.
2. `library_screen.dart`/`_SetCard`: remove the per-type icon list and the
   `ListTile.onTap`/`onOpen` wiring; add a play `IconButton` (48dp, tooltip)
   that pushes `LessonScreen(setId: set.id, items: items)` when the set has
   items, or shows the `lessonEmptySetNote` snackbar when it doesn't; add a
   separate edit `IconButton` (48dp, tooltip) that pushes `SetDetailScreen`
   (today's `onOpen` target) — both alongside the existing overflow menu.
3. Update `library_screen.dart`'s header comment (currently claims "type
   icons" as a feature) and any stale references to `LessonEntryButton`
   elsewhere in comments.
4. Tests: widget test for `SetDetailScreen`'s two FABs (visible without
   scrolling, "Start lesson" shows the empty-set snackbar when empty,
   navigates when items exist); widget test for Library's play icon (shows
   the empty-set snackbar when count=0, navigates straight to
   `LessonScreen` when items exist, skips `SetDetailScreen`).

## Out of scope

- Home screen's duplicate "Browse sets" CTA when no attempts exist yet —
  separate issue.
- Any change to `SetDetailScreen`'s per-item type icons (unaffected).
- Redesigning the Library empty state ("Try demo" CTA) — unchanged.

## Dependencies

- Builds on #003 (Library/`SetDetailScreen`, `done`) and #015 (widget kit /
  FAB + a11y conventions). Removes a #003-shipped behavior (per-set type
  icons) by design.
- Surfaced during #012's (Home dashboard) manual verification.

## Summary

- `SetDetailScreen`: single `addItemFab` → two stacked FABs
  (`startLessonFab` extended + `addItemFab` small), `LessonEntryButton`
  deleted. Empty set shows the snackbar, not a disabled button.
- `library_screen.dart`/`_SetCard`: per-type icon list and row `onTap`
  removed; new `playSet-<id>` and `editSet-<id>` 48dp icon buttons added.
- Shared `startLessonFromSet()` (`lesson_screen.dart`) is the single
  navigate-or-snackbar entry point for both the Library play icon and
  `SetDetailScreen`'s FAB.
- Tests: 5 new widget tests (`set_detail_screen_test.dart`,
  `library_screen_test.dart`), 1 new integration test
  (`issue042_sticky_start_test.dart`); 2 existing integration tests
  (flow1, flow4) updated for the row no longer being a tap target.
  Full suite (340 widget/unit tests) + integration tests pass;
  `flutter analyze`/`dart format`/`dart fix --dry-run` clean.

## Code review

1. Both new entry points read `items` via `itemsAsync.asData?.value`, which
   collapses to `[]` during the brief loading/error window right after
   navigating in — a tap in that window could fire a false "empty"
   snackbar for a non-empty set.
   Fixed: extracted shared `startLessonFromSet()` that checks
   `itemsAsync.isLoading` first (no-op during that window) and reads
   `itemsAsync.value` (preserves last-known data) instead.
2. `addItemFab` (`FloatingActionButton.small`, 40dp) falls below the 48dp
   a11y floor on desktop: `ThemeData.materialTapTargetSize` defaults to
   `shrinkWrap` on macOS/Windows/Linux (vs. `padded` on mobile), unlike the
   sibling `IconButton`s which set an explicit `minimumSize`.
   Fixed: added `materialTapTargetSize: MaterialTapTargetSize.padded`
   explicitly on `addItemFab`.
3. `_startLesson` (navigate-or-snackbar) was duplicated near-verbatim in
   `set_detail_screen.dart` and `library_screen.dart`, risking future drift
   between the two entry points.
   Fixed: both now call the shared `startLessonFromSet()`.
4. `_SetCard` read the same `itemsAsync` twice via two different accessors
   (`.when` for the subtitle, `.asData?.value` for the tap handler).
   Fixed as a side effect of #1/#3: the tap handler now takes the raw
   `AsyncValue` directly instead of a pre-collapsed list.
5. The new integration spec defined its own local `playButtonFor` finder
   instead of adding it to `helpers.dart`, where the analogous
   `editSetButton` already lives and the doc comment already names the
   `playSet-<id>` key.
   Fixed: added shared `playSetButton()` to `helpers.dart`; the spec uses
   it instead of a local closure.
