# Issue 067: Multiple lootboxes per day

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-26

## Goal

Let a user earn more than one lootbox per day. The first lootbox still
appears on the 2nd completed set of the day (today's behavior, unchanged);
after that, another lootbox triggers every 3 additional completed sets,
with no daily cap.

## Decisions (2026-10-26, with repo owner)

- **Cadence — 2, 5, 8, 11, ...**: the existing trigger
  (`MascotService.recordLessonCompletion`, firing when the day-scoped
  `lessonsCompletedToday` counter hits exactly `2`) is unchanged for the
  first box. Every 3rd set after that also triggers a lootbox: set #5, #8,
  #11, and so on, for as many sets as the user finishes that local day —
  uncapped.
- **"Finished" = any completed set**: counts toward the +3 the same way
  the existing counter already works — `_completeLesson` bumps
  `lessonsCompletedToday` on every lesson completion regardless of how
  many answers were correct. No new correctness/score threshold is
  introduced; "successfully finished" in the original draft just means
  "the set was completed," not "completed above some score."
- **Reward odds unchanged, every trigger**: a repeat lootbox (3rd, 4th, ...
  of the day) draws from the exact same pool with the exact same odds as
  the first — uniform random mascot pick (#064), 50/50 coin flip (#065),
  and whatever rarity weighting #069 eventually adds all apply identically
  regardless of which trigger count produced the box. No diminishing
  returns, no coins-only fallback, no cap-driven downgrade.
- **Reveal UX unchanged, every trigger**: exactly like today, each trigger
  pushes `LootboxScreen` immediately after that set's result screen
  (`LessonController._completeLesson` → `LessonScreen`), before continuing
  to whatever the caller would otherwise navigate to. A user who finishes
  several sets back-to-back sees several lootbox reveals back-to-back —
  no batching/queueing of multiple pending boxes into one screen.
- **Day boundary unchanged**: the local-day reset of `lessonsCompletedToday`
  (via `toLocalDayString`) is untouched — the count (and therefore the
  2/5/8/11/... sequence) restarts at a new local day exactly as it does
  today.

## Acceptance criteria

- [ ] `MascotService.recordLessonCompletion` triggers a lootbox when
  `newCount == 2`, and again whenever `newCount > 2` and
  `(newCount - 2) % 3 == 0` — i.e. on 2, 5, 8, 11, ... for the current
  local day.
- [ ] No daily cap: a user who finishes enough sets in one local day can
  trigger arbitrarily many lootboxes.
- [ ] Each triggered lootbox is independently reward-rolled with the same
  pool/odds as today (uniform mascot pick / #065's 50/50 coin flip) —
  rolling the Nth box of the day never special-cases N.
- [ ] Each trigger still pushes `LootboxScreen` immediately after that
  set's result screen, unchanged from today's single-trigger flow;
  back-to-back triggers (e.g. finishing set #5 right after set #2 in the
  same sitting isn't possible, but #5 then #8 in two later sittings is)
  each show their own reveal in turn.
- [ ] The local-day reset behavior for `lessonsCompletedToday` is
  unchanged — the 2/5/8/11/... sequence restarts each new local day.
- [ ] `mascot_service_test.dart`: new tests cover triggering at 5, 8, and
  11 (not just 2), confirm no trigger at 3, 4, 6, 7, etc., and confirm an
  arbitrarily high count (e.g. 50) still triggers correctly on its
  matching multiple.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. In `lib/src/stats/mascot_service.dart`, replace the `newCount != 2`
   early-return in `recordLessonCompletion` with a check that also fires on
   `newCount > 2 && (newCount - 2) % 3 == 0`.
2. Update the method's doc comment (currently describes "the count
   reaching exactly 2") to describe the repeating 2/5/8/11/... sequence.
3. Update `lootbox_screen.dart`'s and `lesson_controller.dart`'s comments
   that describe the trigger as "the 2nd lesson completion"/"twice-a-day"
   to match the new repeating cadence.
4. Add/extend tests in `mascot_service_test.dart` per the acceptance
   criteria.

## Out of scope

- Any change to reward odds, pools, or rarity (#064/#065/#069) — this
  issue only changes how often a lootbox triggers, not what it can award.
- Any UI change to how a lootbox is revealed (still the same
  closed→opening→revealed `LootboxScreen` flow, still pushed immediately).
- Batching/queueing multiple pending lootboxes into one screen.
- Any change to the local-day boundary logic itself.

## Dependencies

- Builds on #059 (`MascotService`, `LootboxScreen`, the original
  twice-a-day trigger) — this issue generalizes that trigger's cadence,
  nothing else.
- Compatible with #064 (full-catalog mascot pool) and #065 (coin-flip
  reward) as already-landed/independent reward-mechanic changes; also
  compatible with #069 (rarity weighting) once that lands — none of them
  need to change for this issue.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
