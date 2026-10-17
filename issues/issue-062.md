# Issue 062: Loot box opening animation + Noto Emoji asset reorg

Status: open | Priority: P2 | Type: feature | Refined-at: 2026-10-17

## Goal

Give the daily lootbox (#059) a tap-gated opening animation using the newly
added `emoji_u1fa8e_lottie.json`, replacing today's static gift-box icon
placeholder (`Icons.card_giftcard` in `_ClosedLootbox`). Since
`MascotCatalog` auto-discovers *every* `*_lottie.json` file directly under
`assets/mascot/noto-emoji/` as a collectible mascot (#059's design),
dropping this new file into that same folder would make it wrongly pickable
as an 8th mascot — so this issue also splits that folder so one-off effect
assets never land in the scanned, collectible path.

## Decisions (2026-10-17, with repo owner)

- **New folder layout**: `assets/noto-emoji/mascot/` holds the 7 existing
  collectible files (scanned by `MascotCatalog`); `assets/noto-emoji/other/`
  holds `emoji_u1fa8e_lottie.json` for now. Future one-off effect
  animations (if any) also go in `other/`, referenced directly by filename
  in code — `other/` is never scanned or auto-discovered, unlike `mascot/`.
  `attribution.md` moves to the shared parent, `assets/noto-emoji/
  attribution.md`, since it covers every asset under both subfolders.
- **`pubspec.yaml`**: Flutter directory-asset declarations aren't
  recursive, so the single existing `assets/mascot/noto-emoji/` entry is
  replaced by three: `assets/noto-emoji/mascot/`, `assets/noto-emoji/
  other/`, and `assets/noto-emoji/` (so `attribution.md` stays bundled,
  same incidental precedent as `assets/sfx/attribution.md`).
- **Code path updates**: `MascotCatalog.kMascotAssetDir` becomes
  `'assets/noto-emoji/mascot/'`. A new constant (e.g.
  `kLootboxOpenAnimationAsset`) points `LootboxScreen` at
  `'assets/noto-emoji/other/emoji_u1fa8e_lottie.json'` directly — no
  catalog/manifest involvement, since this asset is not a collectible.
- **Lootbox interaction — play then reveal**: the closed lootbox renders
  the new Lottie frozen on its first frame until tapped. Tapping starts it
  playing once (no loop); only once it *finishes* does the screen advance
  to the existing reveal (`FoxCelebration` + `FoxMascot`). This replaces
  today's instant tap→reveal swap in `_LootboxScreenState` with a third,
  animation-gated "opening" state between "closed" and "revealed".
  Re-tapping while the animation is mid-flight is a no-op (no restart, no
  skip-ahead).
- **A11y**: the tap target's `Semantics(button: true, label: ...)` applies
  only in the closed state; the mid-animation "opening" state is not
  announced as interactive.

## Acceptance criteria

- [ ] `assets/mascot/noto-emoji/` no longer exists. The 7 existing mascot
  `*_lottie.json` files live in `assets/noto-emoji/mascot/`,
  `emoji_u1fa8e_lottie.json` lives in `assets/noto-emoji/other/`, and
  `attribution.md` lives in `assets/noto-emoji/attribution.md`.
- [ ] `pubspec.yaml` declares `assets/noto-emoji/mascot/`,
  `assets/noto-emoji/other/`, and `assets/noto-emoji/`; `flutter pub get`
  and `flutter analyze` are clean.
- [ ] `MascotCatalog.kMascotAssetDir` and every other reference to the old
  path (`README.md`, `test/mascot/mascot_catalog_test.dart`,
  `test/mascot/mascot_screens_test.dart`) point at the new mascot path.
- [ ] The mascot catalog still discovers exactly the 7 existing mascots
  (not 8) — a test asserts `other/emoji_u1fa8e_lottie.json` is excluded
  from the catalog.
- [ ] `LootboxScreen`'s closed state renders the new Lottie (via an
  `AnimationController`), frozen on frame 0 until tapped; tapping plays it
  once; the screen advances to the existing revealed-mascot view only on
  animation completion, not on tap. Tapping again while it's playing has
  no effect.
- [ ] The tap target's button semantics/label apply only in the closed
  state, not during the "opening" animation.
- [ ] `test/mascot/mascot_screens_test.dart` (and
  `test/golden/kit_golden_test.dart` if it renders the lootbox) are
  updated for the new closed-state visuals and the extra "opening" state.
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md's
  Verify section.

## Tasks

1. Move assets: the 7 mascot `*_lottie.json` files to
   `assets/noto-emoji/mascot/`, `emoji_u1fa8e_lottie.json` to
   `assets/noto-emoji/other/`, `attribution.md` to
   `assets/noto-emoji/attribution.md`; remove the now-empty
   `assets/mascot/` directory.
2. Update `pubspec.yaml`'s `assets:` list to the three new paths.
3. Update `MascotCatalog.kMascotAssetDir` and add a constant for the
   lootbox-opening asset path; update `README.md`'s attribution pointer
   and every hardcoded old-path reference in `test/mascot/*.dart`.
4. Add/update a `MascotCatalog` test asserting the catalog still returns
   exactly the 7 mascots and does not pick up anything from `other/`.
5. Rework `LootboxScreen`/`_ClosedLootbox` (or its replacement) to drive
   the new Lottie via an `AnimationController`: idle at frame 0, play once
   on tap, advance to the existing reveal on `AnimationStatus.completed`,
   ignore taps once already playing.
6. Update `test/mascot/mascot_screens_test.dart` (and golden baselines if
   touched) for the new closed/opening/revealed state machine.

## Out of scope

- Final hand-drawn/custom art for the lootbox — still a bundled Noto Emoji
  Lottie file, same precedent as #059's mascots.
- Any further `other/` effect animations beyond this one file — the folder
  exists for future use but nothing else populates it yet.
- Changing #059's reward-selection or persistence logic — this issue only
  touches the visual opening moment and the asset folder layout.

## Dependencies

- Builds on #059 (`LootboxScreen`, `MascotCatalog`, `FoxMascot`).
