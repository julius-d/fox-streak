# Issue 065: Lootbox can also award coins

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-18

## Goal

Give the daily lootbox a second possible reward: coins, won instead of a
mascot, shown with the newly-added `emoji_u1fa99_lottie.json` (🪙) reveal
animation. The amount won is randomly one of 5, 10, 15, ... 100 (weighted
toward smaller amounts). Coins are persisted to a new profile balance with
no spending mechanic yet — a later issue will let the user spend them on a
"streak on ice" (a streak-saving freeze).

## Decisions (2026-10-18, with repo owner)

- **Dependency on #064**: this issue assumes #064 (full-catalog mascot pool,
  duplicates allowed, mascot-pool-empty skip removed) has already landed.
  With #064 in place, every triggered lootbox always has a mascot available
  to win (barring #064's own defensive zero-time-eligible-entries edge
  case) — so the only way a triggered lootbox *doesn't* award a mascot is
  the new coin-flip below, not an empty pool.
- **Reward pick — 50/50 coin flip, same trigger**: the lootbox trigger
  itself is unchanged (2nd completed lesson of the local day, via
  `MascotService.recordLessonCompletion`). Once triggered, flip a coin: 50%
  mascot (today's #064 behavior — uniform random over the full time-eligible
  catalog), 50% coins (new). No combined reward in one lootbox — exactly
  one of the two.
- **Coin amount — weighted random over {5, 10, ..., 100}**: 20 equally-
  spaced values, linearly decreasing weight so smaller amounts are more
  likely: `weight(amount) = 105 - amount` (100 for 5 coins, down to 5 for
  100 coins; total weight 1050), picked via a cumulative-weight draw off a
  single `Random().nextInt(1050)` (or `nextDouble()`-scaled) call — same
  "accept an injectable `Random`" testability pattern `recordLessonCompletion`
  already uses for the mascot pick.
- **Persistence — new `profileStats.coinsTotal` column**: sole writer is
  `MascotService` (same call site as the mascot reward), via a new
  `StatsRepository.addCoins(amount)` mirroring `addXp`'s
  read-profile/write-delta shape. Schema version bump (document the actual
  next-available version at implementation time — #064 claims v9, so this
  lands as v10 unless #064's numbering has shifted by then); migration adds
  `coinsTotal` defaulting existing rows to `0`.
- **No spending, no UI balance yet**: `coinsTotal` only accumulates. No
  "streak on ice" mechanic, no coin-balance indicator on Home or anywhere
  else — same "persisted for a future issue to consume" precedent as
  #064's `OwnedMascots.count`. The "streak on ice" framing is motivation
  only, out of scope for this issue.
- **Reveal visual**: `LootboxScreen`'s tap-to-open opening animation
  (`emoji_u1fa8e_lottie.json`, the gift box, #062) is unchanged regardless
  of which reward is won — the coin-vs-mascot outcome only affects what's
  shown *after* the box finishes opening. On a coin win, the revealed state
  shows the new coin Lottie (`assets/noto-emoji/other/emoji_u1fa99_lottie.json`,
  played once or looped — implementer's call, no interaction gating needed
  since it's not tappable) plus the amount won, in place of
  `FoxMascot`/the emoji label. Coin Lottie lives in `other/`, not
  `mascot/`, for the same reason `emoji_u1fa8e` does (#062): it's a one-off
  effect, not a collectible, and must stay excluded from `MascotCatalog`'s
  scan.
- **Copy**: new l10n strings (DE + EN) for the coin-reveal heading/body
  (e.g. "You won {amount} coins!") and the coin Lottie's a11y label (e.g.
  "{amount} coins"), following the existing `lootboxRevealedTitle`/
  `mascotSemanticLabel` arb pattern.

## Acceptance criteria

- [ ] `MascotService.recordLessonCompletion`'s return type expresses three
  outcomes: no reward (not yet triggered), a won mascot, or a won coin
  amount — e.g. a small sealed/union result type rather than two separate
  nullable fields that could both be non-null.
- [ ] On trigger, the mascot-vs-coin pick is a 50/50 draw (via an injectable
  `Random`, matching the existing mascot-pick seam); on the coin branch, the
  amount is drawn from {5,10,...,100} with weight `105 - amount` per value.
- [ ] `profileStats.coinsTotal` is added (new schema version, migration
  defaults existing rows to `0`), written exclusively by `MascotService`
  via a new `StatsRepository.addCoins(amount)`; `database.dart`'s
  column-ownership doc comment is updated to list it alongside the existing
  #059 mascot-collection columns.
- [ ] A won coin amount is persisted (added to `coinsTotal`) in the same
  call that would otherwise persist a won mascot — never both in one
  trigger.
- [ ] `LootboxScreen`'s revealed state renders the coin Lottie
  (`assets/noto-emoji/other/emoji_u1fa99_lottie.json`) + the amount won
  when the outcome is coins, and the existing `FoxMascot` + emoji label
  when the outcome is a mascot; the opening (closed→opening) phase and its
  Lottie are unchanged for both outcomes.
- [ ] New DE + EN l10n strings for the coin-reveal heading/body copy and the
  coin Lottie's semantic label; no hardcoded strings.
- [ ] `test/mascot/mascot_catalog_test.dart`'s exact-7(-or-N)/excludes-`other/`
  assertion still passes with `emoji_u1fa99_lottie.json` present in `other/`
  (i.e. the coin asset is not picked up as an 8th/9th collectible).
- [ ] `mascot_service_test.dart`: new tests for the 50/50 branch (fixed
  `Random` seeds/fakes forcing each branch), the weighted coin-amount draw
  (distribution sanity, e.g. amount 5 drawn more often than 100 over many
  seeded trials, or a direct check of the cumulative-weight table), and
  `coinsTotal` accumulating correctly across repeated wins.
- [ ] A migration test covers the new `coinsTotal` column (existing rows
  default to `0`).
- [ ] `test/mascot/mascot_screens_test.dart` covers both reveal variants
  (coin reveal vs. mascot reveal).
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. In `lib/src/data/database.dart`: add `IntColumn get coinsTotal =>
   integer().withDefault(const Constant(0))()` to `ProfileStats`, bump
   `schemaVersion`, add the migration step, update the column-ownership
   doc comment.
2. Regenerate Drift codegen: `dart run build_runner build`.
3. In `lib/src/data/stats_repository.dart`: add `addCoins(int amount)`
   mirroring `addXp`'s shape (read profile, write delta).
4. In `lib/src/stats/mascot_service.dart`: introduce the reward result
   type (mascot | coins | none); add the 50/50 coin-flip + weighted
   coin-amount draw (both via the existing injectable `Random` parameter);
   call `StatsRepository.addCoins` on the coin branch instead of
   `MascotRepository.addOwnedMascot`.
5. Add a constant for the coin reveal asset path
   (`kLootboxCoinRevealAsset` or similar) next to `kLootboxOpenAnimationAsset`
   in `lootbox_screen.dart`.
6. Rework `LootboxScreen`'s revealed-state branch to switch on the reward
   result type, rendering the coin Lottie + amount or the existing
   `FoxMascot` + emoji path.
7. l10n: add the coin-reveal copy + semantic-label arb keys (DE + EN).
8. Update/add tests per the acceptance criteria above (`mascot_service_test.dart`,
   `mascot_screens_test.dart`, `mascot_catalog_test.dart`, a migration test).

## Out of scope

- Spending coins ("streak on ice" or any other sink) — a future issue.
- Any UI surfacing of the coin balance (Home, settings, etc.) — deferred,
  same precedent as #064's unsurfaced `count`.
- Changing the lootbox's trigger condition (still the 2nd lesson of the
  day) or #064's mascot-pool/duplicate logic itself.
- Any weighting of *which* mascot is won — unchanged, uniform random per
  #064.

## Dependencies

- Depends on #064 (full-catalog mascot pool, no empty-pool skip) landing
  first — this issue's design assumes a triggered lootbox always has a
  mascot available, so coins are purely a 50/50 alternative outcome, never
  a fallback for an empty mascot pool.
- Builds on #059 (`MascotService`, `LootboxScreen`, lootbox trigger) and
  #062 (opening-animation state machine, `other/` asset-folder convention
  that the new coin Lottie also follows).
- Motivates (but does not implement) a future "streak on ice" / streak-
  freeze feature that will spend `coinsTotal`.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
