# Issue 090: Disable sound playback by default in integration tests

Status: open | Priority: P3 | Type: chore | Refined-at: 2026-10-31

## Goal

Running an `integration_test/*.dart` spec on a real device/desktop
(`flutter test integration_test/flowX_..._test.dart -d macos`, per
CONTRIBUTING.md) should never play audible sound on the developer's
machine, even though these specs boot the real `FoxStreakApp`/`LessonScreen`
with the real `audioplayers`-backed sound player wired in.

## Context

`lib/src/widgets/fox_sound.dart` gates every chime behind
`foxSoundEnabledProvider` (default `true`) before calling
`foxSoundPlayerProvider`'s `AudioPlayersSoundPlayer`, which genuinely plays
`assets/sfx/koiroylers-correct-356013.mp3` / `level_up.mp3` through the
platform audio channel — real audio, not a test double, when nothing
overrides it.

Widget tests under `test/` consistently override this (e.g.
`_DisabledSound`/`_FakeSoundPlayer` in `test/lesson/lesson_shell_test.dart`),
so `flutter test` is already silent. `integration_test/` is inconsistent:

- One spec, `level_up_result_test.dart`, overrides `foxSoundPlayerProvider`
  with its own counting fake (it needs to assert on call counts).
- The shared harness `integration_test/helpers.dart`
  (`pumpFoxStreakApp`/`pumpLessonScreen`) — used by `flow1`-`flow4` and
  roughly a dozen `issueNNN_*_test.dart` specs — does not override the
  sound seam at all.
- About a dozen other specs build their own `ProviderScope` directly
  (`home_screen_test.dart`, `multiple_choice_exercise_test.dart`,
  `lesson_double_tap_test.dart`, `choice_freetext_dispatch_test.dart`,
  `date_exercise_test.dart`, `lesson_overflow_menu_test.dart`,
  `xp_level_result_test.dart`, `streak_result_test.dart`,
  `issue066_progress_bar_animation_test.dart`,
  `issue072_progress_bar_remount_test.dart`,
  `issue084_streak_details_test.dart`, `home_coin_badge_test.dart`,
  `home_greeting_test.dart`) and also don't override it.

Any of these that drive a lesson through one or more correct answers
(and `flow2`/`flow3`/`issue078` in particular, which complete whole
lessons) plays the real correct-answer chime once per correct answer on
the host running the test — confirmed by the reporting developer on macOS.

## Decisions

- **Scope**: disable sound in every `integration_test/*.dart` spec, not
  just the shared helper — both the helper-based specs and the ones with
  their own `ProviderScope`.
- **Mechanism**: override `foxSoundEnabledProvider` to `false` by default
  (same pattern as `_DisabledSound` in `test/lesson/lesson_shell_test.dart`:
  a `NotifierProvider.overrideWith` subclass whose `build()` returns
  `false`). This short-circuits the `if (ref.read(foxSoundEnabledProvider))`
  gates in `feedback_effects.dart`/`xp_up_screen.dart` before any call
  reaches `foxSoundPlayerProvider`, so the real `AudioPlayersSoundPlayer`
  never touches a platform audio channel — no fake `FoxSoundPlayer` class
  needed for this.
  - Rejected: overriding `foxSoundPlayerProvider` with a shared no-op fake
    instead. Works too, but is strictly more code (a fake class plus the
    override) for the same outcome, since no spec other than
    `level_up_result_test.dart` needs to assert on play-call counts — and
    that one keeps its own counting fake either way.
- **One shared override, not per-file duplication**: add a single exported
  override (e.g. `integrationTestSilentSound`, a
  `foxSoundEnabledProvider.overrideWith(() => _DisabledSound())` value) to
  `integration_test/helpers.dart`. Every other spec imports this one
  symbol rather than each defining its own private `_DisabledSound` class
  — one place to change later, no boilerplate repeated across ~13 files.
  - `pumpFoxStreakApp()` and `pumpLessonScreen()` include it in their
    `ProviderScope.overrides` directly, so every spec built on the shared
    harness is silent by default with no per-spec opt-in required.
  - Each of the dozen specs that construct `ProviderScope` directly
    (listed in Context) imports `integrationTestSilentSound` from
    `helpers.dart` and adds it to their own `overrides` list.
- **`level_up_result_test.dart`**: leave as-is. It already proves sound
  playback is suppressed by its own counting `FakeSoundPlayer` override and
  doesn't use the shared helper; this issue doesn't need to touch it, and
  its existing coverage of the "sound call happened" path stays intact.

## Acceptance criteria

- [ ] `integration_test/helpers.dart` exports one shared
  `integrationTestSilentSound` override (`foxSoundEnabledProvider`
  defaulted to `false`), and `pumpFoxStreakApp()`/`pumpLessonScreen()`
  include it in their `ProviderScope.overrides` by default.
- [ ] Every `integration_test/*.dart` spec that builds its own
  `ProviderScope` (see the list in Context) imports and includes
  `integrationTestSilentSound` in its `overrides` list, except
  `level_up_result_test.dart` (already silenced via its own fake player).
- [ ] No `integration_test/*.dart` spec defines its own duplicate
  `_DisabledSound`-style class — `integrationTestSilentSound` is the only
  definition.
- [ ] Running `flutter test integration_test/flow2_lesson_playthrough_test.dart
  -d macos` (or any other affected spec) locally on macOS produces no
  audible sound. This is a manual check — CI does not run
  `integration_test/` today (only compiles it as part of `flutter test`),
  so there's no automated gate for "stays silent."
- [ ] `flutter analyze`, `dart format --output=none --set-exit-if-changed .`,
  `dart fix --dry-run`, and `flutter test` are all clean per AGENTS.md.

## Out of scope

- Haptics (`foxHapticsEnabledProvider`) — not reported as an issue and
  left untouched.
- Changing the production default of `foxSoundEnabledProvider` (stays
  `true` for real app usage) or any change to `fox_sound.dart` itself.
- `level_up_result_test.dart`'s existing counting-fake approach.

## Dependencies

None — purely an `integration_test/` harness change.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
flutter test integration_test/flow2_lesson_playthrough_test.dart -d macos
```
