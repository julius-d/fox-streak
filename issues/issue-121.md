# Issue 121: Packs — group sets into packs and download full packs from the Marketplace

Status: open | Priority: P2 | Type: enhancement | Refined-at: 2026-11-08

## Goal

With many sets the library becomes a long flat list that is hard to
oversee. The Marketplace already organizes sets into packs; the app should
use the same concept locally. Every set lives in exactly one pack, the
library groups sets by pack, and the Marketplace offers full packs for
download instead of single sets.

## Desired behavior

### Library

- Every set belongs to exactly one pack. There are no pack-less sets.
- The library shows sets grouped in collapsible sections, one section per
  pack: a header with the pack title (and set count) and the pack's sets
  below it. Tapping the header expands/collapses it. The expanded/collapsed
  state is remembered across app restarts.
- With only one pack (own or downloaded) the library looks as it does
  today: a plain set list, no section header, no collapse control.
- Pack order: own packs first (by creation date), then downloaded packs
  (by download date). Stable; it does not reorder with usage.
- An empty own pack is still shown, with a short hint and an "Add set"
  action. (A downloaded pack is never empty.)
- Long pack titles wrap, never clip.

### Creating a set

- When creating a new set, the learner chooses the pack it goes into. The
  default selection is the pack last used (or the only pack).
- In the same place the learner can create a new pack (title only) for the
  set being created; it is selected right away.
- Downloaded packs cannot be chosen: own sets can only be added to own
  (self-created) packs.
- Importing a set from a file or share also asks for a target pack, in the
  same way, with the same default. The set file format itself stays
  pack-free (no pack info in export/share).
- Bundled sample sets (seed) go into "My sets".

### Marketplace

- The Marketplace pack screen offers "Download pack" as the main action.
  The pack's sets are shown as a read-only preview (title, description,
  item count, category, and the existing set preview); there is no
  per-set import any more.
- Downloading creates a local pack with the Marketplace pack's title and
  description and downloads all its sets into it. Progress is visible.
  The download is all-or-nothing: if any set fails (e.g. offline), nothing
  half-done remains, the learner is told, and can retry.
- A downloaded pack is identified by (source URL, pack id). The same pack
  is never downloaded twice into two local packs: the action is replaced
  by the pack's state — new / update available / up to date.
  Deleting a downloaded pack makes a later download count as new.
- Updating a pack updates all its sets. If the learner edited some local
  sets, one summary dialog lists those sets and the learner confirms the
  overwrite or skips them. Sets added upstream arrive with the update;
  sets removed upstream stay locally (never silently deleted). A failed
  update leaves the already-downloaded sets intact.

### Existing data on devices (migration)

- On first start after the update, packs are created from origin:
  - Sets that were imported from the Marketplace go into a pack matching
    their Marketplace pack (one local downloaded pack per source + pack),
    titled like the Marketplace pack when known.
  - All other sets (created, file-imported, seeded) go into an own pack
    "My sets" (DE: "Meine Sets").
- No set, item, progress or XP is lost or changed by the migration. Update
  detection for previously imported sets keeps working.
- A device with only own sets ends up with a single pack and sees no UI
  change in the library.

### Pack management

- Own packs can be renamed and deleted. Downloaded packs can be deleted
  but not renamed.
- Deleting a pack that contains sets asks for confirmation and states how
  many sets go with it. Deleting the last remaining pack is allowed; an
  empty "My sets" pack is then recreated, so there are never zero packs.
- A set can be moved to another own pack. Sets of downloaded packs stay in
  their pack, and own sets cannot be moved into a downloaded pack. Sets of
  downloaded packs remain editable as today.
- Lessons and practice entry points are per set and unchanged.

## Acceptance criteria

- [ ] Every set belongs to one pack; library shows collapsible per-pack
      sections (own first, then downloaded), with no header/collapse when
      only one pack exists (own or downloaded).
- [ ] Collapse state persists across restarts.
- [ ] Empty own pack shows a hint and an "Add set" action.
- [ ] Set creation and file import have a pack picker with inline "new
      pack"; downloaded packs are not selectable; seed sets land in
      "My sets".
- [ ] Marketplace offers full-pack download only; per-set import removed;
      read-only set preview kept.
- [ ] Pack download is all-or-nothing, shows progress, offers retry on
      failure, and never creates a duplicate local pack for the same
      (source, pack id).
- [ ] Pack states new / update available / up to date work; update shows
      one summary of locally edited sets (confirm or skip), keeps sets
      removed upstream, and leaves existing sets intact if it fails.
- [ ] Migration groups existing sets by origin as described, loses no
      data, keeps update detection for imported sets, and is covered by a
      test starting from a pre-update database.
- [ ] Rename (own packs only), delete with confirmation (set count shown),
      auto-recreated "My sets" after deleting the last pack, and move-set
      between own packs work; moves into/out of downloaded packs are not
      offered.
- [ ] Section headers have 48dp targets and a screen-reader label stating
      collapsed/expanded; DE + EN strings via arb; dark mode and large
      font covered; follows #015 (kit, no ad-hoc styling).
- [ ] Tests for data layer (migration, pack repository), library
      grouping incl. the single-pack case, creation picker, and pack
      download flow incl. failure rollback.
- [ ] No change to the question-set file format or marketplace API, so no
      `docs`/schema update needed (set files stay pack-free).
