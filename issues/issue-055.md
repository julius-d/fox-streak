# Issue 055: Settings screen with haptics + sound toggles

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-17

## Goal

`foxHapticsEnabledProvider` (#015) and the new `foxSoundEnabledProvider`
(#053) both exist (or will exist) as default-on, mutable toggles with no
way for a user to actually flip them — there's no settings screen anywhere
in the app. Add a settings screen exposing both as switches, reachable from
a new overflow menu on Home, with the chosen values persisted across app
restarts.

## Decisions (2026-10-17, with repo owner)

- **Entry point**: Home's app bar currently has a single icon button
  (parental info, `Icons.info_outline`). Replace it with an `Icons.more_vert`
  menu button opening a menu with two entries, in this order: **For
  parents** (existing, navigates to `ParentalInfoScreen` as today) then
  **Settings** (new, navigates to the new `SettingsScreen`). This is a
  small change to `home_screen.dart`'s app bar `actions`, not a new nav
  pattern — same `MaterialPageRoute` push used by both destinations today.
- **Settings screen widgets**: plain Material `SwitchListTile` for each
  toggle (Haptics, Sound). No new kit widget — `SwitchListTile` already
  picks up `FoxStreakTheme`'s M3 color scheme with no hardcoded colors, and
  this is the only screen that needs a switch, so a dedicated #015 kit
  component isn't justified yet. Screen itself still follows #015's
  `Scaffold`/`FoxSpacing` conventions, same shape as `ParentalInfoScreen`.
- **Persistence**: add a new drift table (e.g. `AppSettings`: single row,
  `id` fixed to 0, `hapticsEnabled`/`soundEnabled` bool columns, both
  defaulting to `true`) via a schema v7 migration, plus a new
  `SettingsRepository` mirroring `StatsRepository`'s existing
  get-or-create-singleton-row pattern (`kProfileId` / `getProfile()` →
  analogous `kSettingsId` / `getSettings()`). A dedicated table (not reusing
  `ProfileStats`, not a new `shared_preferences` dependency) keeps app
  preferences conceptually separate from profile/XP/streak stats while
  reusing the existing SQLite file and test patterns
  (`NativeDatabase.memory()`, `test/data/`) — no new dependency.
- **Provider shape stays unchanged**: `foxHapticsEnabledProvider` and
  `foxSoundEnabledProvider` remain plain sync `NotifierProvider<..., bool>`,
  default `true` — no ripple into `FoxFeedback._buzz` or #053/#054's
  already-decided plumbing, which read them synchronously.
- **Hydration on startup**: the persisted values need to take effect before
  *any* screen can read the providers, not just when `SettingsScreen`
  happens to be opened. `HomeScreen` already gates its dashboard on an
  async `profileProvider` load (`profileAsync.when(loading/error/data)`) —
  extend that same startup gate to also load the persisted settings row and
  seed both notifiers via `.setEnabled()` before building `_HomeDashboard`.
  `SettingsScreen` itself just reads the already-hydrated provider values.
- **Writing a toggle**: each switch's `onChanged` calls both
  `provider.notifier.setEnabled()` (immediate in-memory effect, e.g. for a
  haptic/sound test-tap on the same screen) and `SettingsRepository`'s
  persist method (durability) — mirrors how `dailyGoalXp` edits already go
  straight through `StatsRepository`.

## Acceptance criteria

- [ ] Home's app bar icon button becomes an `Icons.more_vert` menu with two
      entries — "For parents" then "Settings" — replacing today's single
      direct-navigation icon; "For parents" still opens `ParentalInfoScreen`
      unchanged.
- [ ] A new `SettingsScreen` (full-screen route, #015 `Scaffold`/`FoxSpacing`
      conventions) is reachable via the new "Settings" menu entry.
- [ ] A `SwitchListTile` for haptics, wired to
      `foxHapticsEnabledProvider.setEnabled` + persisted via
      `SettingsRepository`.
- [ ] A `SwitchListTile` for sound, wired to
      `foxSoundEnabledProvider.setEnabled` (or whatever #053/#054 actually
      name it once landed) + persisted via `SettingsRepository`.
- [ ] Both default to on for a fresh install, matching current provider
      defaults.
- [ ] A toggle's value survives an app restart: flipping a switch, then
      relaunching, shows the switch in its last-set position and the
      corresponding provider seeded to that value — verified without ever
      opening `SettingsScreen` again (i.e. hydration happens on startup, not
      lazily on screen open).
- [ ] New drift table/migration (schema v7) + `SettingsRepository`, tested
      in `test/data/` the same way `StatsRepository` is (in-memory DB,
      get-or-create default row, update-and-read-back).
- [ ] New widget test(s): Home's menu shows both entries in order and
      navigates correctly; `SettingsScreen` renders both switches and
      toggling one updates the corresponding provider (via the existing
      test-override pattern, e.g. `test/widgets/kit_test.dart`'s style).
- [ ] Follows #015: `FoxSpacing`/theme-driven styling on the screen itself;
      new strings via `lib/l10n` arb params (DE + EN) — menu item labels,
      settings screen title, switch labels (+ optional short subtitles).
- [ ] `flutter analyze` / `dart format` / `dart fix --dry-run` /
      `flutter test` clean.

## Out of scope

- Any other settings (locale override, data export/reset, etc.) — scoped
  strictly to the two celebration-effect toggles for now.
- A new #015 kit switch widget — revisit if/when a second switch use case
  shows up elsewhere in the app.

## Dependencies

- Needs #053's `foxSoundEnabledProvider` (or #054's, whichever lands first
  / whichever sound toggle is introduced) to exist before wiring its
  switch.
- Builds on #015's `foxHapticsEnabledProvider`.
- Builds on #002's drift schema/migration pattern and #012's
  `StatsRepository` singleton-row pattern (reused for the new
  `SettingsRepository`).

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
