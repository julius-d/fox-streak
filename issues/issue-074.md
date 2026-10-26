# Issue 074: Rework set creation/import entry points and the card's three-dot menu

Status: open | Priority: P2 | Type: UX | Refined-at: 2026-10-26

## Goal

Make "create a new set" and "import a set" two equally visible top-level
actions from the Library overview's FAB, instead of import being hidden
inside a set's own overflow menu. Consolidate each set card down to just
play + a three-dot menu, moving "Share" into that menu (with an icon per
entry) and dropping the now-redundant overflow menu on the detail screen
entirely.

## Decisions (2026-10-26, with repo owner)

- **"New set" FAB becomes a speed-dial**: tapping `newSetFab` on
  `LibraryScreen` expands it in place into two labeled mini-FABs — "New
  set" (manual creation, today's existing flow into `SetEditorScreen` with
  no `existing` set) and "Import" (runs today's `importSetFromPicker`
  flow). A scrim appears behind the expanded mini-FABs; tapping the scrim,
  tapping the main FAB again (now showing a close "×" icon), or the device
  back gesture collapses it with no action. Tapping either mini-FAB runs
  that action and collapses the menu. This replaces today's single
  `FloatingActionButton.extended` that only opens the manual editor.
- **Import removed from `SetDetailScreen`'s overflow menu, and the whole
  menu goes with it**: today's `setOverflowMenu` `PopupMenuButton` in
  `SetDetailScreen`'s `AppBar.actions` currently has exactly two entries,
  "Share" and "Import". Import moves to the new Library FAB (previous
  decision); Share moves to the card's three-dot menu (next decision).
  With both gone, the overflow menu itself is removed from
  `SetDetailScreen`'s `AppBar` — no empty/one-item menu left behind.
- **Share moves to the card's three-dot menu**: `_SetCard`'s existing
  `setMenu-<id>` `PopupMenuButton` (today: Rename/Duplicate/Delete) gains a
  "Share" entry that calls today's `shareSet(ref, setId, title)`, with the
  same error handling (`shareFailed` snackbar on failure) `SetDetailScreen`
  uses today.
- **Card's pencil "edit" icon is removed; its destination moves into the
  three-dot menu instead**: `_SetCard`'s trailing row currently has three
  explicit affordances — play icon, a pencil `editSet-<id>` icon (opens
  `SetDetailScreen`'s item list), and the three-dot menu. The pencil icon
  is removed, leaving just play + three-dot on the row. Its destination
  isn't lost — a new "Edit items" entry is added to the three-dot menu that
  opens `SetDetailScreen`, same as the icon did. The row itself stays
  non-tappable (`ListTile.onTap` stays unset, per #042's existing
  tap-target reasoning — unchanged by this issue since there's still a
  three-dot menu and a play icon competing for the row).
- **Resulting three-dot menu on the card** (`setMenu-<id>`), each entry
  with a leading icon per the issue's explicit ask:
  1. Edit items (opens `SetDetailScreen`) — `Icons.edit_note`
  2. Rename (opens `SetEditorScreen`, title/description/creator/category —
     never items, unchanged) — `Icons.drive_file_rename_outline`
  3. Duplicate — `Icons.copy`
  4. Share — `Icons.share`
  5. Delete — `Icons.delete_outline`

  "Edit items" and "Rename" stay distinct entries — they open two different
  existing screens with different scopes (items vs. title/metadata) and
  neither subsumes the other.
- **No new confirmation/feedback beyond what exists today**: Share/Import
  keep today's exact error handling (`shareFailed`/`importFailed`
  snackbars, `SetImportException` message passthrough for import); no new
  success toast is added for either, matching today's behavior where the
  reactive set list is the only feedback for a successful import.

## Acceptance criteria

- [ ] Tapping `LibraryScreen`'s "New set" FAB expands it into two labeled
      mini-FABs, "New set" and "Import", behind a scrim.
- [ ] Tapping the "New set" mini-FAB opens `SetEditorScreen` with no
      `existing` set (today's create flow), then collapses the speed-dial.
- [ ] Tapping the "Import" mini-FAB runs `importSetFromPicker`, surfaces
      `importFailed`/`SetImportException` errors via snackbar on failure,
      and collapses the speed-dial either way (including picker-cancel,
      which stays a no-op).
- [ ] Tapping the scrim, the main FAB again, or the back gesture while
      expanded collapses the speed-dial without running either action.
- [ ] `SetDetailScreen`'s `AppBar` no longer has an overflow/three-dot menu
      (the `setOverflowMenu` `PopupMenuButton` and its Share/Import entries
      are gone).
- [ ] Each set card (`_SetCard`) shows exactly two trailing affordances: the
      play icon and the three-dot menu — the pencil `editSet-<id>` icon is
      gone.
- [ ] The card's three-dot menu has exactly these five entries, each with a
      leading icon: Edit items, Rename, Duplicate, Share, Delete.
- [ ] "Edit items" opens `SetDetailScreen` for that set (same destination
      the removed pencil icon used to open).
- [ ] "Share" runs today's `shareSet` flow with the existing
      `shareFailed`-snackbar error handling, now triggered from the card's
      menu instead of `SetDetailScreen`'s.
- [ ] The card row itself remains non-tappable (`ListTile.onTap` unset) —
      unchanged from #042.
- [ ] 48dp min tap targets + screen-reader tooltips/semantics on the new
      mini-FABs, matching the a11y floor the rest of the kit follows
      (#015).
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
      `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
      Verify section.

## Tasks

1. `lib/src/library/library_screen.dart`: replace `newSetFab`'s single
   `FloatingActionButton.extended` with a small stateful speed-dial
   (expanded `bool` + `AnimatedSwitcher`/`AnimatedScale` or similar,
   following existing patterns already used for FAB layout in
   `set_detail_screen.dart`) showing two mini-FABs on expand — "New set"
   (`Icons.edit` or similar + `l10n.newSet`, pushes `SetEditorScreen()`)
   and "Import" (`Icons.file_upload` or similar + a new `l10n.importSet`
   label reused from `SetDetailScreen`'s current menu, runs
   `importSetFromPicker`). Add a `ModalBarrier`/`GestureDetector` scrim
   behind the expanded mini-FABs that collapses on tap.
2. `lib/src/library/library_screen.dart` / `_SetCard`: remove the
   `editSet-<id>` `IconButton`; add "Edit items" (→ `onOpen`, i.e. push
   `SetDetailScreen`) and "Share" (→ `shareSet`, with the
   `shareFailed`-snackbar handling moved over from
   `set_detail_screen.dart`) entries to the `setMenu-<id>`
   `PopupMenuButton`; add a `leading: Icon(...)` to all five entries per
   the Decisions list above.
3. `lib/src/library/set_detail_screen.dart`: remove the `setOverflowMenu`
   `PopupMenuButton` from `AppBar.actions` entirely (and its now-unused
   `shareSet`/`importSetFromPicker` imports/error-handling, now that both
   moved to `library_screen.dart`).
4. `lib/l10n/app_en.arb` / `app_de.arb`: add any new label(s) needed for
   the mini-FABs/menu entries not already covered by existing
   `newSet`/`importSet`/`shareSet`/`rename`/`duplicate`/`delete` strings
   (e.g. an "Edit items" label, distinct from the existing `editSet`
   string which is `SetEditorScreen`'s AppBar title with a different
   meaning).
5. Update `integration_test/helpers.dart`'s `editSetButton` finder (and
   any other helper referencing the removed pencil icon or the detail
   screen's overflow menu) to match the new card menu structure.
6. Update tests: `test/library/library_screen_test.dart`,
   `test/library/set_detail_screen_test.dart`,
   `test/library/share_actions_test.dart`,
   `integration_test/flow1_library_crud_test.dart`,
   `integration_test/flow4_share_roundtrip_test.dart`,
   `integration_test/issue042_sticky_start_test.dart` — anywhere these
   reference the removed pencil icon, the detail screen's overflow menu,
   or drive share/import through their old entry points.
7. Add new tests for the speed-dial's expand/collapse behavior (scrim tap,
   FAB-again tap, back gesture) and for the card menu's new "Edit items"
   and "Share" entries.

## Out of scope

- Any change to `SetEditorScreen` (manual create/rename form) or
  `importSetFromPicker`/`shareSet`'s underlying logic — only their entry
  points move.
- Any change to the per-item edit/delete icons on `SetDetailScreen`
  (unaffected).
- Any visual redesign of the card itself beyond the trailing-row/menu
  changes described here.

## Dependencies

- Builds on #003 (Library/`SetDetailScreen`) and #008 (share/import
  wiring, error copy).
- Interacts with #042's "row is not a tap target" decision but doesn't
  reverse it — the row stays non-tappable; only the pencil icon moves into
  the three-dot menu instead of disappearing.
- Follows #015's widget-kit a11y conventions (48dp targets, tooltips) for
  the new mini-FABs.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
