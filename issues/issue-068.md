# Issue 068: Rename "Mascot" to "Pet" everywhere

Status: open | Priority: P2 | Type: tech-debt | Refined-at: 2026-10-26

## Goal

Rename the "Mascot" concept (the collectible Lottie animals won from the
daily lootbox, #059) to "Pet" throughout the app and codebase — user-facing
copy (DE + EN), Dart identifiers/files/folders, l10n keys, the database
schema, and the bundled asset directory — so the product vocabulary and the
code agree. #069 (rarity levels) and #071 (looping pet animation) are
already drafted using "Pet" against code that still says "Mascot"; this
issue is what makes that line up.

## Decisions (2026-10-26, with repo owner)

- **Full rename, not copy-only**: every "mascot"/"Mascot" occurrence becomes
  "pet"/"Pet" — Dart class/file/folder names, provider names, l10n keys and
  values, DB table/column names, and the asset directory. Nothing is left
  half-renamed; a future contributor shouldn't find "Mascot" in code behind
  a "Pet" label in the UI.
- **DB migration, not a reset**: `owned_mascots` and the `mascot_id`/
  `equipped_mascot_id` columns are renamed via a new migration step (next
  schema version after the existing v10) using `RENAME TABLE`/`RENAME
  COLUMN`, preserving any already-collected pets and the equipped choice on
  existing local databases — this is not a drop/recreate.
- **Asset directory renamed too**: `assets/noto-emoji/mascot/` becomes
  `assets/noto-emoji/other/`'s sibling `assets/noto-emoji/pet/` (`git mv` the
  directory, keep file contents/attribution untouched), with `pubspec.yaml`
  and the catalog's directory constant updated to match.
- **Rename mapping** (apply consistently; non-exhaustive sample of the
  largest renames — the implementer should grep for every remaining
  "mascot"/"Mascot" occurrence rather than relying on this list alone):

  | Old | New |
  | --- | --- |
  | `lib/src/mascot/` (module folder) | `lib/src/pet/` |
  | `mascot.dart` (barrel) | `pet.dart` |
  | `mascot_catalog.dart` / `MascotCatalog` / `MascotEntry` | `pet_catalog.dart` / `PetCatalog` / `PetEntry` |
  | `kMascotAssetDir` / `kDefaultMascotId` | `kPetAssetDir` / `kDefaultPetId` |
  | `mascot_providers.dart` | `pet_providers.dart` |
  | `mascotCatalogProvider` / `mascotCatalogLoaderProvider` / `mascotRandomProvider` | `petCatalogProvider` / `petCatalogLoaderProvider` / `petRandomProvider` |
  | `ownedMascotIdsProvider` / `equippedMascotProvider` | `ownedPetIdsProvider` / `equippedPetProvider` |
  | `mascot_collection_screen.dart` / `MascotCollectionScreen` | `pet_collection_screen.dart` / `PetCollectionScreen` |
  | `lootbox_reward.dart`'s `MascotReward` | `PetReward` |
  | `lib/src/stats/mascot_service.dart` / `MascotService` | `lib/src/stats/pet_service.dart` / `PetService` |
  | `lib/src/data/mascot_repository.dart` / `MascotRepository` | `lib/src/data/pet_repository.dart` / `PetRepository` |
  | `MascotRepository.addOwnedMascot` / `getOwnedMascotIds` / `watchOwnedMascotIds` | `addOwnedPet` / `getOwnedPetIds` / `watchOwnedPetIds` |
  | `StatsRepository.setEquippedMascot` / `setMascotLessonCounter` | `setEquippedPet` / `setPetLessonCounter` |
  | `lib/src/widgets/fox_mascot.dart` / `FoxMascot` widget | `fox_pet.dart` / `FoxPet` |
  | DB: table `owned_mascots`, class `OwnedMascots`, column `mascot_id` | table `owned_pets`, class `OwnedPets`, column `pet_id` |
  | DB: `profileStats.equippedMascotId` (column `equipped_mascot_id`) | `equippedPetId` (`equipped_pet_id`) |
  | l10n keys: `mascotSemanticLabel`, `mascotEquippedSemanticLabel`, `mascotLockedSemanticLabel`, `homeMascotSemanticLabel`, `mascotCollectionTitle` | `petSemanticLabel`, `petEquippedSemanticLabel`, `petLockedSemanticLabel`, `homePetSemanticLabel`, `petCollectionTitle` |
  | Widget key `foxMascot-${mascot.id}` | `foxPet-${pet.id}` |
  | `test/mascot/` folder, `mascot_catalog_test.dart`, `mascot_screens_test.dart`, `mascot_service_test.dart`, `mascot_repository_test.dart` | `test/pet/`, `pet_catalog_test.dart`, `pet_screens_test.dart`, `pet_service_test.dart`, `pet_repository_test.dart` |

- **User-facing copy, both languages**: every DE/EN arb *value* containing
  "mascot"/"Maskottchen" is reworded, not just the keys — e.g.
  `lootboxRevealedTitle` "You got a new mascot!" → "You got a new pet!"
  (DE: "Maskottchen" → "Pet"), `lootboxTapPrompt` "Tap to reveal your
  new mascot!" → "Tap to reveal your new pet!", `mascotCollectionTitle`
  "Your mascots" → "Your pets" (DE: "Deine Maskottchen" → "Deine Pets").
  German uses the English loanwords "Pet"/"Pets" (singular/plural)
  throughout, not a translated term like "Haustier" — consistent with
  other untranslated gaming terms already in the app's DE copy (e.g.
  "Streak", "Lootbox", "XP").
- **Historical issue files are untouched**: already-`done` issues (#059,
  #062–#065) describe what was built *at the time* using the vocabulary
  that was current then — they are not retroactively edited to say "pet".
  `integration_test/issue059_mascot_lootbox_test.dart` keeps its
  issue-number-tagged filename as a historical pointer, but every Dart
  identifier/string literal inside it is renamed like everywhere else.
- **AGENTS.md's design-language section updated**: its #015 kit-widget list
  currently names `FoxMascot` (with its already-retired `empty | lit |
  on-fire` states, stale since #059) — update that bullet to `FoxPet`.
- **"Seasonal mascot" wording (#063) becomes "seasonal pet"**: code
  comments/doc comments referencing the seasonal-window exclusion are
  reworded alongside the identifiers they describe; #063's own `done` issue
  file is left as historical, per the point above.

## Acceptance criteria

- [ ] No occurrence of "mascot"/"Mascot"/"Maskottchen" remains in `lib/`,
  `test/`, `integration_test/`, `pubspec.yaml`, `README.md`, or
  `AGENTS.md` (`grep -ri mascot` across those paths returns nothing except
  inside `issues/done/*.md` and issue-number-tagged historical filenames).
- [ ] New schema version renames `owned_mascots` → `owned_pets`,
  `mascot_id` → `pet_id`, `profileStats.equipped_mascot_id` →
  `equipped_pet_id` via `RENAME TABLE`/`RENAME COLUMN` (not a
  drop-and-recreate); a migration test confirms a pre-migration DB's owned
  rows and equipped value survive the upgrade unchanged (only the
  table/column names differ).
- [ ] `assets/noto-emoji/mascot/` is renamed to `assets/noto-emoji/pet/`
  (`git mv`, file contents unchanged); `pubspec.yaml`'s asset declaration
  and the catalog's directory constant point at the new path.
- [ ] Every DE + EN arb *value* that said "mascot"/"Maskottchen" now says
  "pet" (EN) or "Pet"/"Pets" (DE, loanword — not "Haustier"); arb *keys*
  are also renamed per the mapping above.
- [ ] `lib/src/mascot/` and its files, `lib/src/widgets/fox_mascot.dart`,
  `lib/src/data/mascot_repository.dart`, `lib/src/stats/mascot_service.dart`,
  and `test/mascot/` are moved/renamed per the mapping; no leftover
  `mascot_*.dart` filename.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.
- [ ] Existing `fox_pet_*`/pet-collection/lootbox golden and widget tests
  pass under the renamed keys/classes with no unintended visual change
  (goldens are not expected to need regeneration — only identifiers moved).

## Tasks

1. Rename the asset directory: `git mv assets/noto-emoji/mascot
   assets/noto-emoji/pet`; update `pubspec.yaml`'s asset entry and
   `kMascotAssetDir`/its new name.
2. Rename the module folder and files: `lib/src/mascot/` → `lib/src/pet/`,
   plus `lib/src/widgets/fox_mascot.dart` → `fox_pet.dart`,
   `lib/src/data/mascot_repository.dart` → `pet_repository.dart`,
   `lib/src/stats/mascot_service.dart` → `pet_service.dart`. Rename every
   class/function/constant/provider inside per the mapping table, updating
   all importers.
3. `lib/src/data/database.dart`: add the next schema version; rename
   `OwnedMascots` → `OwnedPets` (and its `mascot_id` column → `pet_id`) and
   `profileStats.equippedMascotId` → `equippedPetId` via a migration step
   using `RENAME TABLE`/`RENAME COLUMN`; update the column-ownership doc
   comment and the migration-history comment block.
4. Regenerate Drift codegen: `dart run build_runner build`.
5. l10n: rename every `mascot*`/`*Mascot*` arb key to its `pet`/`Pet`
   equivalent in both `app_en.arb` and `app_de.arb`, and reword every arb
   *value* that mentions "mascot"/"Maskottchen"; regenerate
   `app_localizations*.dart`.
6. Update every call site across `lib/` (Home, lesson result screen,
   onboarding, `FoxEmptyState`, lootbox/collection screens) for the renamed
   classes/providers/l10n getters.
7. Rename `test/mascot/` → `test/pet/` and the individual test files per
   the mapping; rename `test/data/mascot_repository_test.dart` and
   `test/stats/mascot_service_test.dart` to their `pet_*` equivalents;
   update every identifier/string literal referenced inside, including
   `integration_test/issue059_mascot_lootbox_test.dart` (filename
   unchanged, contents renamed). Add the migration test from the
   acceptance criteria.
8. Update `pubspec.yaml`'s mascot-dependency comment, `README.md`'s
   attribution line, and `AGENTS.md`'s #015 kit-widget bullet
   (`FoxMascot` → `FoxPet`).
9. Run the full Verify sequence; fix any straggling `mascot` references
   `grep -ri mascot` turns up outside the historical exclusions.

## Out of scope

- Any behavior change to the lootbox, rarity, or collection mechanics
  themselves — this issue only renames, matching #067/#069's note that
  reward odds/pools are untouched by adjacent issues.
- Editing already-`done` issue files (#059, #062–#065) or
  issue-number-tagged historical test filenames to say "pet".
- Renaming the app itself, its package ID, or anything unrelated to the
  collectible-animal feature (e.g. the `fox_streak_app` package name, the
  "FoxStreak" brand, or the fox launcher icon/branding stay as-is — only the
  *collectible* concept is a "pet" now, not the app's own fox mascot
  identity).

## Dependencies

- Builds on #059 (introduced the Mascot module/schema being renamed here),
  #063 (seasonal exclusion), #064 (full-catalog pool), #065 (coin-flip
  reward).
- Unblocks #069 (rarity levels for Pets) and #071 (looping pet animation),
  both already drafted using "Pet" vocabulary against code that currently
  says "Mascot".

## Verify

```shell
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
