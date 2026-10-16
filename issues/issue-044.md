# Issue 044: Golden (screenshot) tests for key screens

Status: open | Priority: P3 | Type: test

## Goal
#019 added golden tests for the #015 widget kit's isolated components (buttons, banners, progress bar, dialogs, mascot), but component-level goldens can't catch composition bugs — overlapping elements, spacing breaking under real data, scroll/overflow issues — which is where visual regressions actually tend to show up once widgets are combined into real screens. Add a small, deliberately limited set of screen-level golden tests on top of #019's coverage.

## Decisions (proposed — needs confirmation)
- **Scope stays small on purpose**: screen goldens are far more expensive than widget goldens (real state/data fixtures, async loading, scrolling), and #019 already showed the per-OS baseline maintenance cost (3 platforms × N screens × light/dark adds up fast). Pick a handful of high-value, visually-stable screens rather than exhaustive coverage; expand later only if this catches real regressions.
- **Proposed screens + states** (confirm or adjust):
  - `HomeScreen` (`lib/src/home/home_screen.dart`): fresh-install/empty state, and a populated state with streak + XP progress visible.
  - `LibraryScreen` (`lib/src/library/library_screen.dart`): empty state, and a populated list.
  - Lesson result screen (`lib/src/lesson/lesson_result.dart`): perfect score and a partial/wrong-answer score.
  - Each snapshotted once per `FoxStreakTheme.light()`/`.dark()` (matching #019), **not** per-platform-and-theme-and-screen combinatorics beyond that.
- **Reuse #019's precedent exactly**: plain `flutter_test`/`matchesGoldenFile`, no new dependency; per-OS baseline folders `test/golden/goldens/<macos|windows|linux>/` resolved via `Platform.operatingSystem`; pinned `devicePixelRatio`; keyed `RepaintBoundary` capture.
- **Fixture pattern**: reuse the existing screen-test pattern already used in `test/home/home_screen_test.dart` / `test/library/library_screen_test.dart` — in-memory Drift DB (`AppDatabase.forTesting(NativeDatabase.memory())`) + `FakeClock`, wired via `ProviderScope` overrides, seeded per scenario (empty vs. populated). Use the existing bounded `settle()` helper instead of `pumpAndSettle()` (drift `watch()` streams spin under fake async per that file's existing NOTE).
- **New-screen rule going forward**: screens built after this issue lands are not retroactively required to add goldens here; follow #019's "Follows #015" precedent and let feature issues opt in per-screen if the screen is design-sensitive enough to warrant it.

## Acceptance criteria
- [ ] Confirm the proposed screen/state list above (or adjust) before implementing
- [ ] Golden tests exist for each confirmed screen/state, under both `FoxStreakTheme.light()` and `.dark()`
- [ ] Baselines generated and committed per-OS (`test/golden/goldens/<platform>/`), including `linux/` via the `update-goldens.yml` `workflow_dispatch` job (no local Linux machine available)
- [ ] `flutter test` picks up the new tests with no CI change (same precedent as #019)
- [ ] No new test dependency added
- [ ] `flutter analyze` / `dart format` stay clean with the new test files

## Out of scope
- Exhaustive screen coverage (every screen × every state) — explicitly rejected per the "scope stays small" decision above
- Golden coverage for exercise screens (#006–#009) and set/item editors — candidates for a future follow-up if this issue proves valuable, not bundled in here
- Large-font / `textScaleFactor` golden variants — same deferral as #019
- Device e2e / real-device screenshot comparison — #016's territory (`integration_test`, no Patrol)

## Dependencies
- Builds on #019 (done — establishes the golden-test pattern, per-OS baseline folders, and the `update-goldens.yml` fallback job this issue reuses)
- Builds on #012 (Home), #003/#013 (Library), #005–#009 (lesson result) for the screens being snapshotted
- Blocks nothing; purely additive test coverage

## Verify
```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
# Only when intentionally changing a snapshotted screen's visuals:
# flutter test --update-goldens test/golden
```
