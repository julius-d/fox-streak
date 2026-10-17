# Issue 057: Settings screen: edit daily XP goal + display name

Status: open | Priority: P3 | Type: feature | Refined-at: 2026-10-17

## Goal

`SettingsScreen` (#055) currently only has the haptics/sound switches.
Extend it with two more editable fields: the daily XP goal
(`dailyGoalXp`, shown as the Home goal-ring target) and the display name
(`displayName`, shown in Home's greeting). Both already have backend
support — `StatsRepository.updateDailyGoal(int xp)` and
`StatsRepository.setDisplayName(String? name)` both exist and are tested,
but `updateDailyGoal` has no UI caller anywhere today, and
`setDisplayName` is only reachable via Home's tap-to-rename greeting, not
Settings. Also bump the fresh-install default daily goal from 30 to 100.

## Decisions (2026-10-17, with repo owner)

- **Widget shape**: add two `ListTile`s to `SettingsScreen`, above or below
  the existing switches, each opening an edit dialog on tap — mirroring
  Home's existing hand-rolled `_EditNameDialog` (`AlertDialog` with a
  `TextField`, `FoxSecondaryButton`/`FoxPrimaryButton` for cancel/save).
  No new kit dialog widget; this reuses the one dialog pattern that
  already exists rather than introducing a stepper/slider.
- **Display name**: Settings gets its own "Display name" `ListTile`
  (current value as subtitle, or a placeholder when unset) that opens the
  same kind of dialog as Home's, writing through
  `StatsRepository.setDisplayName`. This is a **second entry point**
  alongside Home's existing tap-to-rename greeting — both coexist and
  write to the same `displayName` column, no change to Home's behavior.
- **Daily XP goal**: Settings gets a "Daily XP goal" `ListTile` (current
  value as subtitle, e.g. "100 XP") that opens a dialog with a numeric
  `TextField` (`keyboardType: TextInputType.number`), writing through
  `StatsRepository.updateDailyGoal`.
- **Validation**: the dialog itself must enforce **10–500 XP inclusive**
  before enabling its save action (e.g. disable the primary button, or
  show inline validation text, for out-of-range or non-numeric input) —
  tighter than `updateDailyGoal`'s existing `>= 0` check, so the stricter
  bound lives in the UI layer, not the repository.
- **Default bump, fresh installs only**: change `kDefaultDailyGoalXp` in
  `stats_repository.dart` from `30` to `100`. No migration for existing
  profile rows — an install that already has `dailyGoalXp = 30` keeps that
  value until the user changes it via the new Settings UI. No new drift
  schema version needed (reusing existing columns, not adding any).
- **Persistence pattern**: both dialogs follow the same immediate-write
  pattern already used by the haptics/sound switches and Home's
  tap-to-rename — call the repository method directly on save, then let
  the existing `profileProvider`/`watchProfile` stream refresh dependent
  UI (Home's greeting, goal ring). No new provider needed.

## Acceptance criteria

- [ ] `SettingsScreen` has a "Display name" `ListTile` that opens an
      edit dialog (prefilled with the current name), saves via
      `StatsRepository.setDisplayName`, and reflects the updated value
      immediately (including in Home's greeting, without needing to
      reopen Home).
- [ ] `SettingsScreen` has a "Daily XP goal" `ListTile` that opens an edit
      dialog (prefilled with the current goal), saves via
      `StatsRepository.updateDailyGoal`, and reflects the updated value
      immediately (including Home's goal-ring target).
- [ ] The daily XP goal dialog rejects non-numeric input and values
      outside 10–500 inclusive — save is disabled or blocked, with
      feedback, until the value is valid.
- [ ] Home's existing tap-to-rename greeting is unchanged and still works
      independently of the new Settings entry — both write the same
      `displayName` column.
- [ ] `kDefaultDailyGoalXp` is `100`; a fresh profile row (new install)
      gets `dailyGoalXp = 100`. No migration touches existing rows.
- [ ] New strings via `lib/l10n` arb params (DE + EN): both `ListTile`
      labels/subtitles, both dialog titles/hints, and any validation
      message — following the `settings*`/`homeEditName*` naming
      pattern already in `app_en.arb`/`app_de.arb`.
- [ ] New/updated tests: `stats_repository_test.dart` already covers
      `updateDailyGoal`/`setDisplayName` at the repository level — add
      widget/integration coverage for the two new `SettingsScreen` fields
      (open dialog, edit, save, value reflected), following #055's
      `integration_test/issue055_settings_test.dart` style.
- [ ] `flutter analyze` / `dart format` / `dart fix --dry-run` /
      `flutter test` clean.

## Out of scope

- Migrating existing installs' `dailyGoalXp` from 30 to 100.
- Removing or changing Home's tap-to-rename greeting.
- Any new kit-level dialog/stepper widget (#015) — revisit if a third
  settings field needs editing and the duplicated dialog boilerplate
  becomes worth abstracting.

## Dependencies

- Builds on #055's `SettingsScreen` and `SettingsRepository` pattern.
- Builds on #012's `StatsRepository.updateDailyGoal`/`setDisplayName` and
  Home's `_EditNameDialog` precedent.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```
