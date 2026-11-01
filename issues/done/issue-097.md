# Issue 097: Wrap PetService's counter + reward writes in one transaction

Status: done | Priority: P3 | Type: chore
Completed-at: 2026-11-01

Note: originally filed as #092, renumbered to #097 — #092 was already
taken by an unrelated, already-done issue (date/free-text exercise
keyboard-stability fix); see #096 for the backlog numbering-collision bug
this surfaced.

## Context

Found during #085's (Wheel of Fortune) code review. `PetService
.recordLessonCompletion` (`lib/src/stats/pet_service.dart`) does several
sequential, unguarded `await`s against `StatsRepository`/`PetRepository`:
`setPetLessonCounter`, then (independently) `addCoins` for the wheel,
then `addCoins` or `addOwnedPet` for the lootbox. If the app process dies
or a write throws partway through (e.g. after `setPetLessonCounter`
commits but before the reward write runs), the day's completion counter
has already advanced past the trigger count, but the reward itself (coins
or an owned pet) is silently and permanently lost — that counter value
never recurs.

`StatsRepository` already has a `transaction` helper
(`stats_repository.dart`) used elsewhere for exactly this kind of
multi-write atomicity. This isn't new in #085 — the lootbox's own
counter+reward writes (#059/#065) have the same gap — #085 just added a
second instance of the same pattern (the wheel's counter+coins writes).

## Goal

Wrap each of `recordLessonCompletion`'s write sequences (counter bump +
wheel coins; counter bump + lootbox reward) in a single
`StatsRepository.transaction` call so a crash/throw between them can
never advance the counter without the reward landing (or vice versa).

## Out of scope

- Any change to the trigger cadences or reward tables themselves.
- `PetService.equip` (single write already, nothing to wrap).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

`recordLessonCompletion` now wraps `setPetLessonCounter` + whichever reward
write follows (`addCoins` for the wheel/lootbox coin branches, or
`addOwnedPet` for the lootbox pet branch) in one `StatsRepository
.transaction` call. All rng draws and the (DB-free) catalog load happen
before the transaction so the write-lock covers only the DB calls. Three new
tests in `pet_service_test.dart` use throwing `StatsRepository`/
`PetRepository` subclasses to force a write failure right after the counter
bump and assert the whole transaction rolls back.

## Code review

- `_loadCatalog()` was originally awaited inside the transaction closure,
  needlessly extending the write-transaction's lifetime across unrelated
  async I/O.
  Fixed: rng decisions + catalog load now happen before
  `_statsRepo.transaction(...)`; only the actual DB writes run inside it.
