# Issue 039: Shared default Android applicationId/iOS bundle id collides across worktrees on a shared emulator/simulator

Status: open | Priority: P3 | Type: tech-debt

## Goal
`android/app/build.gradle.kts`'s `applicationId` is still the Flutter
template default (`com.example.fox_streak_app`), and every git worktree in
this repo checks out the same value (it's not per-branch). When two
worktrees both run `flutter test`/`flutter run` with an Android
integration test against the same shared emulator at the same time, their
installs race: Flutter's tooling (or `pm install -r`) sees two different
builds claiming the same package name and one install step force-stops
and fully uninstalls the app mid-run from under the other process.

Found while manually verifying #035's native splash on `emulator-5554`:
a `flutter test integration_test/home_screen_test.dart` running
concurrently in a different worktree (`fox-streak-issue-037`) caused
`com.example.fox_streak_app` to be force-stopped and fully removed
(`ActivityManager: Force stopping ... pkg removed`) a few seconds after
this worktree's own manual install, right as this worktree was mid-launch.

## Acceptance criteria
- [ ] Each worktree/branch that can run Android integration tests gets a
      distinct `applicationId` (e.g. derived from the branch/worktree
      name, or a build-time override via `--dart-define`/Gradle property),
      OR some other mechanism (e.g. serializing Android test runs across
      worktrees, or a per-worktree emulator) that stops concurrent
      worktrees from fighting over the same installed package.
- [ ] iOS bundle id (`PRODUCT_BUNDLE_IDENTIFIER`, currently also the
      `com.example.fox_streak_app` default) gets the same treatment if the
      chosen fix is applicationId-based, since the same race is possible
      on a shared iOS Simulator.
- [ ] Whatever fix lands doesn't change the production `applicationId`
      used for real builds/releases (CI/release builds should keep a
      single stable id) — this is specifically about avoiding collisions
      between concurrent local dev worktrees.
- [ ] `flutter analyze`, `dart format`, `flutter test` stay clean.

## Out of scope
- Renaming the app's production applicationId/bundle id for branding
  reasons (separate decision, not this issue's concern — this issue is
  purely about dev-time concurrency safety).
- Fixing the particular test run that got caught by this race (no code
  was actually broken; it's an environment/tooling collision).

## Dependencies
- Surfaced during #035's manual Android emulator verification.
- Possibly related to #038 (`home_screen_test` failing on a connected
  device/emulator) — that issue root-caused its failures to a locale
  mismatch, not this collision, but both were hit on the same shared
  emulator infrastructure and are worth cross-checking if #038's fix
  doesn't fully explain its flakiness.
