# Issue 069: Rarity levels for pets

Status: done | Priority: P2 | Type: feature | Refined-at: 2026-10-26 | Completed-at: 2026-10-26

## Goal

Give every collectible pet a rarity tier (Common/Uncommon/Epic/Legendary/
Mythic) that drives how likely it is to be won from the lootbox, and surface
that rarity — plus a distinct "Seasonal" label for the two time-gated pets —
on the collection screen and in the lootbox-reveal text. This replaces the
generic "new mascot" wording, which is already inaccurate today since the
reward can be coins instead of a pet (#065).

## Decisions (2026-10-26, with repo owner)

- **Depends on #068 (Mascot → Pet rename)**: this issue is sequenced after
  #068 and is written against today's `Mascot...` symbols/files (that rename
  hasn't defined its scheme yet). If #068 lands first, apply every task
  below to the renamed `Pet...` equivalents instead — same structure, just
  renamed.
- **Rarity tiers and odds**: Common 55%, Uncommon 30%, Epic 10%, Legendary
  4%, Mythic 1% (sums to 100%). This percentage is the tier's share of a
  *mascot* draw specifically — it does not change #065's existing 50/50
  coin-vs-mascot flip, which still happens first and is unaffected. Within a
  tier, every currently-eligible pet in that tier splits the tier's
  percentage evenly (mirrors how #064's existing uniform draw already
  behaves when a seasonal pet enters/leaves the pool).
- **Static, hardcoded pet catalog**: replaces `MascotCatalog.load`'s current
  runtime `AssetManifest` folder-scan (today's `lib/src/mascot/mascot_catalog.dart`)
  with an explicit, hardcoded list — one entry per pet, each declaring its
  id, asset path, rarity, sort order, and (for the two seasonal pets) its
  season window. Adding a new pet from here on means adding an entry to this
  list, not just dropping a Lottie file into the folder — this intentionally
  reverses #059's original "drop a file in, it just appears" design.
  `test/mascot/mascot_catalog_test.dart`'s "adding a fake extra asset
  surfaces it with no catalog code change" test is removed, since it tests
  the exact behavior this issue reverses.
- **New test: folder ↔ catalog sync**: no runtime assertion/throw for an
  unlisted asset (there's no "runtime discovery" left to assert against) —
  instead, a unit test lists the real files in
  `assets/noto-emoji/mascot/` and fails if any file has no matching entry in
  the hardcoded catalog (or vice versa), catching a forgotten registration
  at test time.
- **Sort order**: each catalog entry carries an explicit `sortOrder` int,
  used (ascending) for both the hardcoded list's own order and the
  collection screen's grid order — replacing today's alphabetical-by-id
  sort. The default fox gets `sortOrder: 0` and so always appears first on
  the collection screen.
- **Per-pet rarity assignment** (today's 11 pets):

  | Pet | Rarity (draw weight) | Card label |
  |---|---|---|
  | 🦊 fox (default starter, `sortOrder: 0`) | Common | Common |
  | 🐇 rabbit | Common | Common |
  | 🐝 bee | Common | Common |
  | 🐥 chick | Common | Common |
  | 🕷️ spider (seasonal, Oct 25 – Nov 1) | Common | **Seasonal** |
  | ☃️ snowman (seasonal, Dec 6 – 26) | Common | **Seasonal** |
  | 🦀 crab | Uncommon | Uncommon |
  | 🦉 owl | Uncommon | Uncommon |
  | 🐖 pig | Uncommon | Uncommon |
  | 🦖 T-Rex | Epic | Epic |
  | 🐦‍🔥 phoenix | Mythic | Mythic |

  Legendary (4%) currently has no pet — reserved for a future addition.
- **Seasonal pets draw at Common odds, labelled "Seasonal"**: spider and
  snowman are rarity `Common` for draw-weight purposes, sharing the 55%
  Common slice with fox/rabbit/bee/chick whenever their season window is
  open (unchanged eligibility rule — still excluded from the pool entirely
  outside their window, per #063). Their card label and lootbox-reveal text
  always say "Seasonal", never "Common" — on owned *and* locked tiles,
  regardless of whether their window is currently open.
- **Empty-tier fallback (Legendary today)**: if a draw's weighted roll lands
  in a tier with zero currently-eligible pets, redraw by redistributing that
  slice proportionally across the tiers that do have an eligible pet, so
  every triggered lootbox still awards something. (Not reachable today with
  the table above — Legendary only matters once a pet is ever added to it,
  or if Mythic's lone pet (phoenix) isn't an issue since it's never
  seasonal — but the logic must handle it generically, not just today's
  specific gap.)
- **Collection screen card display**: each tile (owned or locked/greyed)
  shows its rarity/seasonal label as text under the pet — label only, no
  percentage (keeps the exact odds non-public). Locked tiles show the label
  too, per the original request — seeing "Mythic" on a locked tile is
  intentional, not a spoiler bug.
- **Owned-count badge**: a tile for a pet owned more than once shows a small
  "×N" badge in its top-right corner (e.g. "×2"). The count already exists
  in the DB (`OwnedMascots.count`, written by #064) but isn't exposed to the
  UI yet — this issue adds that read path.
- **Lootbox revealed title drops "new"**: `lootboxRevealedTitle` ("You got a
  new mascot!" / "Du hast ein neues Maskottchen bekommen!") is reworded to
  name the won pet's rarity/seasonal label instead, e.g. "You got a
  Legendary mascot!" / "Du hast ein legendäres Maskottchen bekommen!", or
  "You got a Seasonal mascot!" / "Du hast ein saisonales Maskottchen
  bekommen!" — grammatically correct in both locales (English a/an per
  tier, German adjective declension agreeing with "Maskottchen"). Scoped to
  this *revealed* title only; `lootboxCoinsRevealedTitle` (the coins
  outcome) is untouched.
- **Lootbox tap prompt also drops "new mascot"**: `lootboxTapPrompt` ("Tap
  to reveal your new mascot!" / "Tippe, um dein neues Maskottchen
  aufzudecken!") is reworded to be reward-agnostic, e.g. "Tap to reveal your
  reward!" / "Tippe, um deine Belohnung aufzudecken!" — the pre-open prompt
  can't say "mascot" at all, since the reward might be coins (#065), so the
  old wording was already wrong independent of rarity.

## Acceptance criteria

- [ ] The pet catalog is a static, hardcoded list (no more
  `AssetManifest`-based folder scan) with one entry per pet declaring id,
  asset path, rarity, `sortOrder`, and season window (where applicable).
- [ ] A new test confirms every file in `assets/noto-emoji/mascot/` has a
  matching catalog entry and vice versa; it fails if either side is out of
  sync.
- [ ] `MascotCatalog.load`'s old "surfaces an added asset with no catalog
  code change" extensibility test is removed (contradicts the new design).
- [ ] The lootbox mascot draw (`MascotService.recordLessonCompletion`'s
  mascot branch) is rarity-weighted per the table above instead of uniform
  across the whole pool; the pre-existing 50/50 coin-vs-mascot flip (#065)
  is unaffected.
- [ ] A seasonal pet draws at Common odds while its window is open, and is
  excluded from the pool otherwise — unchanged eligibility, new odds.
- [ ] A draw landing in a tier with no eligible pet redistributes to
  eligible tiers rather than awarding nothing.
- [ ] The collection screen (`mascot_collection_screen.dart`) orders pets by
  `sortOrder` ascending (fox first), not alphabetically by id.
- [ ] Every collection-screen tile — owned or locked — shows its rarity
  label, or "Seasonal" for spider/snowman, under the pet; no percentage
  shown.
- [ ] A tile for a pet owned more than once shows a "×N" badge (e.g. "×2")
  in its top-right corner; a pet owned exactly once shows no badge.
- [ ] `lootboxRevealedTitle` names the won pet's rarity/seasonal label
  instead of "new", correctly declined in both `app_en.arb` and
  `app_de.arb`; `lootboxCoinsRevealedTitle` is unchanged.
- [ ] `lootboxTapPrompt` no longer mentions "new" or "mascot" specifically,
  in both `app_en.arb` and `app_de.arb`.
- [ ] New/updated tests cover: the rarity-weighted draw's distribution
  (e.g. statistical/seeded-`Random` assertions per tier), the seasonal-as-
  Common-when-active behavior, the empty-tier redistribution, `sortOrder`
  ordering, the owned-count badge, and the reworded reveal/tap-prompt
  strings.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. In `lib/src/mascot/mascot_catalog.dart`: replace the `AssetManifest`-based
   `MascotCatalog.load` with a static `List` of pet definitions (id, asset
   path, rarity enum, `sortOrder`, optional season window) — keep
   `decodeMascotEmoji`/`MascotEntry`'s shape where it still fits, fold
   `kMascotSeasonWindows` into the per-pet definition instead of a separate
   lookup map.
2. Add a `PetRarity` (or similarly named) enum: `common`, `uncommon`,
   `epic`, `legendary`, `mythic`, with the fixed tier weights (55/30/10/4/1)
   and a way to mark the two seasonal entries as "display as Seasonal, draw
   as Common".
3. In `lib/src/stats/mascot_service.dart`'s `recordLessonCompletion`:
   replace the uniform `pool[rng.nextInt(pool.length)]` pick with a
   weighted draw by rarity tier (eligible pets only), including the
   empty-tier redistribution fallback.
4. In `lib/src/data/mascot_repository.dart` / `lib/src/mascot/mascot_providers.dart`:
   add a read path for per-pet owned `count` (today's `OwnedMascots.count`
   is written but never read back) for the collection screen's badge.
5. In `lib/src/mascot/mascot_collection_screen.dart`: sort by `sortOrder`,
   add the rarity/seasonal label under each tile (owned and locked), and the
   "×N" owned-count badge.
6. In `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: add rarity/seasonal
   label strings (for cards), reword `lootboxRevealedTitle` to use them, and
   reword `lootboxTapPrompt` to drop "new mascot".
7. In `lib/src/mascot/lootbox_screen.dart`: pass the won pet's rarity/
   seasonal label into the revealed-title lookup.
8. Update/replace tests in `test/mascot/mascot_catalog_test.dart`,
   `test/stats/mascot_service_test.dart`, `test/mascot/mascot_screens_test.dart`,
   and `test/data/mascot_repository_test.dart` per the acceptance criteria.

## Out of scope

- The Mascot → Pet rename itself (#068) — a dependency of this issue, not
  part of its work.
- Any change to the coin-flip mechanics/odds (#065) or the lootbox trigger
  cadence (#067) — this issue only changes the mascot half of an
  already-triggered draw.
- Any change to the seasonal window dates themselves (#063).
- Adding any new pet or Lottie asset, or filling today's empty Legendary
  tier with a real pet.
- Any other visual redesign of the collection grid beyond the rarity/
  seasonal label and the owned-count badge.

## Dependencies

- **#068** (Mascot → Pet rename) must land first; this issue is written
  against today's pre-rename names as a placeholder (see first Decision).
- Builds on #059 (`MascotCatalog`, `MascotService`, `LootboxScreen`), #063
  (seasonal windows), #064 (full-pool draw + owned `count`), and #065 (coin
  flip) — compatible with #067 (multiple lootboxes/day) as already noted in
  that issue's own text.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

## Summary

- `lib/src/pet/pet_catalog.dart`: `MascotCatalog.load`'s `AssetManifest`
  scan replaced by a static `PetCatalog.entries` list (11 hardcoded
  entries, `PetRarity` enum with fixed 55/30/10/4/1 weights, `sortOrder`,
  per-entry `PetSeasonWindow?`). New `drawPet` does the weighted draw with
  built-in empty-tier redistribution (skips tiers with no eligible pet).
- `PetService.recordLessonCompletion` now calls `drawPet` instead of a
  uniform pool pick; seasonal filtering moved from a global
  `kPetSeasonWindows` map to `PetEntry.isInSeasonAt`.
- `PetRepository.watchOwnedPetCounts` (+ `ownedPetCountsProvider`) exposes
  `OwnedPets.count` to the UI for the first time.
- `PetCollectionScreen` sorts by `sortOrder`, shows a rarity/seasonal
  label under every tile (owned or locked), and a "×N" badge when
  `count > 1`.
- `lootboxRevealedTitle`/`lootboxTapPrompt` (DE+EN) reworded via ICU
  `select` on the won pet's `rarityKey` (`common`/.../`seasonal`);
  `lootboxCoinsRevealedTitle` untouched.
- New `integration_test/issue069_pet_rarity_test.dart` drives the real app
  through two forced-deterministic lootbox wins, asserting the reworded
  strings and the collection screen's rarity labels + owned-count badge.

## Code review

- Reviewed with the `code-review` skill (medium effort) after
  implementation, covering the full diff.
- No findings survived verification. One soft candidate (the "×N" badge
  text being a hardcoded literal instead of routed through l10n) was
  checked against `set_detail_screen.dart`'s existing precedent for
  hardcoded interpolated `Text`, and dismissed as consistent with
  established practice, not fixed.
