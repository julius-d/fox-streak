# Issue 059: Collectible mascots via daily lootbox

Status: open | Priority: P2 | Type: feature | Refined-at: 2026-10-17

## Goal

Every user starts owning a single mascot (the fox). Twice a day, completing
a lesson nudges them toward a lootbox: after the 2nd completed lesson of
the calendar day, a new lootbox screen (shown once per day, after the
result screen) lets them win another mascot from an extensible pool of
animated Lottie animals bundled under `assets/mascot/noto-emoji/`. Owned
mascots persist; tapping the mascot on the Home screen opens a collection
screen where the user can switch which one is currently equipped. This
replaces today's single state-based placeholder `FoxMascot` (empty/lit/
on-fire) everywhere it appears.

## Decisions (2026-10-17, with repo owner)

- **Lottie dependency**: #059 adds the `lottie` pub.dev package itself
  (pick a version, verify iOS/Android/Windows/macOS support per AGENTS.md's
  no-plugin-without-3-platform-support rule) rather than waiting on #032.
  #032 (lottie question images) can reuse this same dependency later.
- **Extensible catalog, not a hardcoded enum/list**: mascots are discovered
  at *runtime* from every `assets/mascot/noto-emoji/*_lottie.json` file via
  Flutter's `AssetManifest` — never a hardcoded Dart list. `pubspec.yaml`
  declares the whole directory (`assets/mascot/noto-emoji/`), matching the
  existing `assets/seed/`/`assets/sfx/` folder-level convention, so the
  catalog picks up new files automatically. **Adding a mascot later means
  dropping one more `..._lottie.json` file into that folder — no Dart,
  schema, or pubspec change needed.** The attribution file is excluded by
  filtering filenames to the `_lottie.json` suffix.
- **Stable mascot ID = filename stem** (e.g. `emoji_u1f98a_lottie` for
  `emoji_u1f98a_lottie.json`), used as the primary/foreign key everywhere
  (owned-mascots table, equipped-mascot column) — never an array index, so
  the DB survives files being added later.
- **No per-mascot l10n names.** Hardcoding a translated name per animal
  would defeat extensibility (every new file would need new arb entries).
  Noto-emoji filenames encode the Unicode codepoint(s) in hex (e.g.
  `u1f98a` → 🦊, `u1f426_200d_1f525` → 🐦‍🔥); decode that back into the
  literal emoji character at runtime and use it as both the visible label
  and the a11y/semantic label, via one generic arb template (e.g.
  `mascotSemanticLabel(emoji)` → "Mascot {emoji}" / "Maskottchen {emoji}").
- **Starting/default mascot**: every profile starts owning and equipped
  with exactly one mascot, `emoji_u1f98a_lottie.json` (🦊) — matching
  existing fox branding (app name, launcher icon).
- **`FoxMascot`'s `empty`/`lit`/`on-fire` states are retired app-wide**,
  replaced by rendering the user's currently equipped Lottie mascot as-is
  (no state variants), in every spot that used the old painter: Home,
  lesson result screen, onboarding's 3-slide explainer, and the
  library/set-detail empty states (`FoxEmptyState`). Kit golden
  (`kit_golden_test.dart`) and widget tests (`kit_test.dart`) update to
  match — this is one issue, not split, since the collection feature and
  the state-system retirement are tightly coupled (there's no sense
  showing a collectible mascot that also still carries fox-only mood
  states).
- **Result-screen outcome feedback**: since the mascot no longer varies by
  score/milestone, outcome feedback relies entirely on the already-shipped
  XP count-up, score %, confetti+chime (#053), and `StreakBadge` — no
  replacement state mechanic is added.
- **Lootbox trigger**: once per local calendar day (`toLocalDayString`,
  same convention as streak), after the **2nd** completed lesson of that
  day — any score counts, same "lesson completed" event that already
  feeds XP (`XpService.applyLessonResult`) and streak
  (`StreakService.recordActivity`). The 3rd+ completions that day don't
  retrigger it. This needs its own day-scoped counter — it cannot reuse
  `profileStats.lastActiveDay` (StreakService-owned-write per
  `database.dart`'s column-ownership rule) — so a new service added by
  this issue owns a new `lessonsCompletedToday` (+ day marker) column,
  written only from the same lesson-completion call site, without
  touching `xpTotal`/`todayXp`/`streakCount`/`lastActiveDay`.
- **Reward selection**: uniformly random among mascots in the catalog not
  yet owned. If the user already owns the entire current catalog, the
  lootbox screen is skipped that day — the result-screen flow goes
  straight through as it does today.
- **Lootbox screen**: shown once, after the result screen, on the
  triggering day only — tap-to-open reveal, then shows the won mascot's
  Lottie animation + its emoji label, with a single continue action
  (same before/after navigation targets as today's result screen).
- **Collection/equip screen**: tapping the mascot on Home opens a grid of
  the *entire* catalog — owned mascots are tappable to equip; not-yet-owned
  ones are shown greyed out/silhouetted with a lock affordance (visible but
  inert) so the user can see there's more to collect.
- Fix the stray trailing space in the already-added
  `assets/mascot/noto-emoji/attribution.md` filename (currently
  `attribution.md ` — a typo from when the asset was added).
- Add a short attribution line to the root `README.md` crediting Google's
  Noto Emoji animated assets (CC BY 4.0), pointing at the existing
  `assets/mascot/noto-emoji/attribution.md` for details.

## Acceptance criteria

- [ ] `lottie` added to `dependencies`, verified to build/run on Android,
  iOS, Windows, and macOS.
- [ ] `pubspec.yaml` declares `assets/mascot/noto-emoji/` as a directory
  asset (not individual files).
- [ ] A mascot catalog is built at runtime from `AssetManifest`, filtering
  to `assets/mascot/noto-emoji/*_lottie.json`; each entry's ID is its
  filename stem; adding a new `..._lottie.json` file requires no other
  code change (covered by a test — see Tasks).
- [ ] New schema (next `schemaVersion`): an owned-mascots table (mascot ID
  + acquired timestamp) and `profileStats` gains `equippedMascotId`
  (default `emoji_u1f98a_lottie`) + a day-scoped lesson-count column (owned
  exclusively by the new service, per `database.dart`'s ownership
  convention); fresh profiles seed one owned row for the default mascot.
- [ ] Completing a lesson increments the day-scoped lesson counter
  (resetting on a new local day); on the count reaching exactly 2 *and*
  at least one mascot remains unowned, the lootbox screen is shown once,
  after the result screen, before continuing to the caller's original
  destination (Home/Library, same as today's "back" labels, #034).
- [ ] Lootbox screen: tap-to-open interaction, reveals a uniformly-random
  not-yet-owned mascot, persists it as owned, shows its Lottie + emoji
  label, single continue action.
- [ ] If the full catalog is already owned when the trigger fires, the
  lootbox screen is skipped entirely.
- [ ] Tapping the mascot on Home opens a collection screen: full catalog
  grid, owned mascots tappable to set `equippedMascotId`, unowned ones
  rendered locked/greyed (not tappable).
- [ ] Home, lesson result screen, onboarding, and `FoxEmptyState`
  (library/set-detail) all render the equipped mascot's Lottie animation
  instead of the retired `FoxMascot` `empty`/`lit`/`on-fire` painter.
  `FoxMascotState` enum and `_FoxPainter` are removed.
- [ ] A11y: equipped-mascot label uses the generic `mascotSemanticLabel`
  arb template with the decoded emoji character — no per-animal arb keys.
- [ ] Follows #015: kit tokens/spacing for the new lootbox/collection
  screens, no ad-hoc styling; all new strings via `lib/l10n` arb params
  (DE + EN).
- [ ] `assets/mascot/noto-emoji/attribution.md` filename no longer has a
  trailing space; root `README.md` gets a one-line attribution pointer.
- [ ] `test/golden/kit_golden_test.dart` and `test/widgets/kit_test.dart`
  updated for the retired `FoxMascot` states.
- [ ] Unit + widget tests green (see Tasks).

## Tasks

1. Add `lottie` dependency; smoke-test rendering one of the bundled
   `..._lottie.json` files on each of the 4 platforms (manual QA per
   AGENTS.md's toolchain notes — no Android SDK locally, defer Android/iOS
   device checks to CI where noted elsewhere in this repo).
2. `pubspec.yaml`: declare `assets/mascot/noto-emoji/` as a directory
   asset.
3. New `MascotCatalog`/`MascotRepository`-style module: enumerate
   `assets/mascot/noto-emoji/*_lottie.json` via `AssetManifest`, derive
   stable IDs from filename stems, decode each ID's hex codepoint(s) into
   its emoji character. Unit test: adding a fake extra asset to the
   manifest surfaces it with no catalog code change.
4. Schema: add the owned-mascots table + `profileStats.equippedMascotId` +
   day-scoped lesson-count column via the next migration step; update
   `database.dart`'s migration doc comment + column-ownership note; seed
   fresh profiles with the default fox mascot owned + equipped.
5. New service (e.g. `MascotService`) hooking into the existing lesson-
   completion call site: bumps the day-scoped lesson counter, resets it on
   a new local day, and on hitting exactly 2 (with an unowned mascot
   available) picks a uniformly-random unowned mascot and records it as
   owned — without writing any #010/#011-owned column.
6. New lootbox reveal screen + navigation wiring: inserted after the result
   screen, only on the triggering day, with the existing before/after
   destinations preserved.
7. New collection/equip screen: full-catalog grid, locked styling for
   unowned entries, tap-to-equip for owned entries, wired from a tap target
   on Home's mascot.
8. Retrofit `FoxMascot` call sites (Home, lesson result, onboarding,
   `FoxEmptyState`) to render the equipped mascot's Lottie instead of a
   state; remove `FoxMascotState` + `_FoxPainter`; update onboarding copy/
   slide data that referenced specific states.
9. l10n: arb keys for the lootbox/collection screens' copy + the generic
   `mascotSemanticLabel(emoji)` template (DE + EN).
10. Rename `assets/mascot/noto-emoji/attribution.md ` → `attribution.md`;
    add the README.md attribution line.
11. Update `test/golden/kit_golden_test.dart` + `test/widgets/kit_test.dart`
    for the retired states; add tests for the catalog, lootbox trigger
    (day rollover, exactly-2 gate, full-collection skip), reward
    persistence, and the collection/equip screen.

## Out of scope

- Final hand-drawn mascot art — these are the bundled Noto Emoji Lottie
  files as-is, not custom illustrations.
- Any lootbox monetization, ads, or paid currency — purely a free daily
  reward.
- #032's lottie *question images* rendering — this issue only adds/
  verifies the `lottie` dependency; wiring it into exercise cards is #032's
  own scope.
- A shop, trading, or duplicate-reward mechanic — one mascot per catalog
  entry, ever.

## Dependencies

- Unblocks #032 (can reuse the `lottie` dependency added here).
- Builds on #015 (kit tokens/widgets for the new screens), #010/#011
  (column-ownership convention the new day-scoped counter must respect),
  #053 (confetti/chime now carries all result-screen outcome feedback).

## Verify

```powershell
flutter pub get
flutter analyze        # must be clean
dart format --output=none --set-exit-if-changed .  # must be clean
dart fix --dry-run     # nothing auto-fixable left
flutter test           # must be green, incl. updated goldens
```
