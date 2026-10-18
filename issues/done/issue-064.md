# Issue 064: Lootbox draws from the full mascot pool, duplicates allowed

Status: done | Priority: P3 | Type: feature | Refined-at: 2026-10-18 | Completed-at: 2026-10-18

## Goal

Change the daily lootbox's reward pick so every mascot currently eligible
under #063's seasonal time-restriction has an equal chance of being drawn —
even if the user already owns it. Duplicates become possible; persist a
per-mascot instance count for a future feature to consume (no UI for it
yet).

## Context

Today, `MascotService.recordLessonCompletion`
(`lib/src/stats/mascot_service.dart:61-72`) restricts the random pick to
`catalog.where((entry) => !owned.contains(entry.id))` — once a mascot is
owned, it's permanently removed from the pool, and once every mascot is
owned, the draw is skipped entirely (`wonMascot: null`, no lootbox shown).

This issue removes the ownership filter: the pool becomes every catalog
entry that's time-eligible per #063's seasonal window (owned or not), drawn
uniformly at random. `OwnedMascots` (`lib/src/data/database.dart:117-124`)
currently has one row per owned mascot with a single `acquiredAt`
timestamp, upserted via `insertOnConflictUpdate` — that row model needs a
`count`, since a mascot can now be won repeatedly.

## Decisions

- **Pool**: every catalog entry passing #063's seasonal-window check
  (`MascotSeasonWindow`/the time-restriction lookup), regardless of
  ownership. No separate weighting for unowned vs. owned — same uniform
  `Random().nextInt(...)` pick as today, just over the unfiltered
  (time-filtered-only) list.
- **Lootbox trigger gate removed**: the pool is effectively never empty
  now (the default fox has no seasonal restriction, so it's always
  eligible), which makes the current "only trigger while at least one
  mascot remains unowned" gate dead weight. Drop that gate: the lootbox
  triggers on every 2nd-lesson-of-the-day completion,
  unconditionally — `wonMascot` is non-null whenever the time-eligible
  pool is non-empty (practically: always). Keep a defensive empty-pool
  check (return `wonMascot: null`) for the theoretical case of zero
  time-eligible entries, rather than assuming non-empty.
- **Schema**: rename `OwnedMascots.acquiredAt` → `firstAcquiredAt`
  (unchanged value semantics — set once, on the row's first insert, never
  overwritten) and add a new `IntColumn count`, defaulting to `1` on
  insert and incremented by 1 on every subsequent draw of an
  already-owned mascot. Requires a schema version bump (v8 → v9) with a
  migration: rename the column, add `count` defaulting existing rows to
  `1` (every existing row represents exactly one win today).
- **`MascotRepository.addOwnedMascot`**: stays the sole writer, but
  switches from a blind `insertOnConflictUpdate` (which clobbered
  `acquiredAt`) to an upsert that sets `firstAcquiredAt`/`count: 1` on
  insert and only bumps `count` (via `count + 1`) on conflict, leaving
  `firstAcquiredAt` untouched.
- **`getOwnedMascotIds()`/`watchOwnedMascotIds()`**: unchanged return
  shape (`List<String>` of owned ids) — ownership for the collection
  grid's equip/lock logic is still a simple "is there a row" check,
  independent of `count`. No new count-reading API is needed yet since
  nothing consumes it this issue (see UI scope below).
- **UI scope**: data/logic layer only. No collection-grid badge, no
  lootbox "you already have this" messaging, no new count-reading
  provider — the count is persisted for a later issue to surface.

## Acceptance criteria

- [ ] `MascotService.recordLessonCompletion`'s reward pool is every
  catalog entry passing the seasonal time-restriction check, regardless
  of `owned`/`unowned` status.
- [ ] Drawing an already-owned mascot is possible and increments its
  `OwnedMascots.count`; `firstAcquiredAt` is unchanged on that draw.
- [ ] Drawing a not-yet-owned mascot still inserts a new row
  (`firstAcquiredAt` = now, `count` = 1), same as today.
- [ ] The lootbox's "only while something remains unowned" trigger gate
  is removed; the 2nd lesson of the day always triggers the lootbox
  (barring the defensive zero-time-eligible-entries edge case).
- [ ] `OwnedMascots.acquiredAt` is renamed to `firstAcquiredAt`; schema
  version bumps to 9 with a migration that renames the column, adds
  `count` (defaulting existing rows to `1`), and is covered by a
  migration test (existing rows survive with `count == 1` and their old
  `acquiredAt` value preserved under the new name).
- [ ] `mascot_repository_test.dart` is updated: repeated
  `addOwnedMascot` calls for the same ID now increment `count` rather
  than silently no-op-ing on ownership, and `firstAcquiredAt` stays
  pinned to the first call's timestamp across repeats.
- [ ] `mascot_service_test.dart`'s "only unowned entry left" style
  assertions are updated/replaced to reflect that owned entries are
  drawable too; add a test that an already-fully-owned catalog still
  produces a `wonMascot` (previously this returned `null`).
- [ ] No UI/widget files change (collection grid, lootbox reveal screen)
  — verified by scoping the diff to the data layer + `MascotService` +
  tests.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. In `lib/src/data/database.dart`: rename `OwnedMascots.acquiredAt` to
   `firstAcquiredAt`, add `IntColumn get count => integer().withDefault(const Constant(1))()`,
   bump `schemaVersion` to 9, add the v9 migration (rename column, add
   `count` column) under `onUpgrade`'s `if (from < 9)` block.
2. Regenerate Drift codegen: `dart run build_runner build`.
3. In `lib/src/data/mascot_repository.dart`: update `addOwnedMascot` to
   upsert `count: count + 1` on conflict (via a custom
   `insertOnConflictUpdate` with a SQL expression, or a manual
   select-then-update) while leaving `firstAcquiredAt` untouched on
   conflict.
4. In `lib/src/stats/mascot_service.dart`: drop the `owned`/`unowned`
   filtering in `recordLessonCompletion` — build the pool from the
   catalog filtered only by #063's seasonal-eligibility check; keep the
   empty-pool defensive `wonMascot: null` fallback.
5. Update `test/data/mascot_repository_test.dart` for the renamed column
   and the new count-incrementing upsert behavior.
6. Update `test/stats/mascot_service_test.dart`: replace "only unowned
   entry left" assertions with pool-includes-owned-entries assertions;
   add a fully-owned-catalog-still-wins test.
7. Add a migration test (existing migration test file, or a new one) for
   v8 → v9 covering the rename + count backfill.

## Out of scope

- Any UI surfacing of the count (collection-grid badges, lootbox
  duplicate messaging, etc.) — deferred to a future issue.
- Weighting the draw (e.g. favoring unowned mascots) — stays uniform
  random across the full time-eligible pool.
- Any change to #063's seasonal-window logic itself.

## Dependencies

- Builds on #059 (`MascotService`, `OwnedMascots`, `MascotRepository`)
  and #063 (seasonal time-restriction check feeding the pool filter).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Code review

- Reviewed with the `code-review` skill (medium effort) after implementation.
  No findings — reviewer called out clean migration handling and test coverage.

## Summary

- Schema v8 -> v9: `owned_mascots.acquired_at` renamed to `first_acquired_at`,
  `count` added (default 1), migrated with a dedicated test.
- `recordLessonCompletion`'s pool is now every season-eligible catalog entry
  regardless of ownership; `MascotRepository.addOwnedMascot` upserts via
  `DoUpdate` (insert sets `firstAcquiredAt`/`count: 1`, conflict bumps
  `count` only).
- `integration_test/issue059_mascot_lootbox_test.dart` switched to a
  default-fox-free fixture catalog to stay deterministic now that the real
  catalog's draw can hit an already-owned entry.
