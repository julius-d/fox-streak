# Issue 042: Starting a lesson is buried — sticky start button + direct-start from Library list

Status: open | Priority: P1 | Type: UX

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

- [ ] `SetDetailScreen` shows a persistent (non-scrolling) "Start lesson"
      action at all times the screen is open, including with a long item
      list — no scrolling required to find it.
- [ ] "Add item" remains reachable on `SetDetailScreen` (secondary FAB),
      unchanged behavior otherwise.
- [ ] Each set row in the Library list has a play affordance that opens
      `LessonScreen` for that set directly, with no intermediate screen.
- [ ] Both new "start lesson" entry points (Library row play icon,
      `SetDetailScreen`'s "Start lesson" FAB) stay tappable for sets with 0
      items; tapping shows a `l10n.lessonEmptySetNote` snackbar instead of
      navigating.
- [ ] The set row itself is no longer a tap target (`ListTile.onTap`
      removed); opening `SetDetailScreen` only happens via the new explicit
      edit icon button.
- [ ] Per-set type icons are removed from the Library list row; item count
      text stays.
- [ ] 48dp min targets + screen-reader tooltips/semantics on both new icon
      buttons (play on Library row, both FABs on detail) — follows #015.
- [ ] `flutter analyze`, `dart format`, `flutter test` stay clean.

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
