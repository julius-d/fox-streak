# AGENTS.md — fox-streak

Flutter learning app (FoxStreak). Local-only MVP, no backend/auth. Backlog lives in `issues/` (see `issues/` for the current range) — read the relevant issue before coding.

## Shell environment

Developers work on both Windows and macOS. Commands below are plain
`flutter`/`dart`/`git` and run the same on either — assuming those are on
`PATH`.

- **Windows (PowerShell)**: if a fresh shell doesn't inherit `flutter`/`git`
  on `PATH`, prefix the command:
  ```powershell
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
  ```
  `winget`'s `msstore` source prompts interactively and fails headless —
  always pass `--source winget`. PowerShell surfaces git's stderr
  (`To https://…`) as `NativeCommandError` — a push is successful if output
  shows `main -> main`, regardless of that noise.
- **macOS (zsh/bash)**: Flutter/git are normally on `PATH` already (Homebrew
  or the SDK installer); no prefix needed.

## Toolchains

Toolchain status is per-machine — run `flutter doctor -v` locally rather than
trusting a stale snapshot. As a reference, a Windows dev machine verified
2026-10-11: Flutter 3.47.6 ✓, Android toolchain ✗ (no Android SDK), Chrome ✓,
Visual Studio ✓ (C++ workload, for `flutter build windows`). macOS machines
additionally need Xcode for iOS/macOS runs and builds, and don't have a
Windows target. Android builds (`flutter build apk`/`appbundle`) need the
Android SDK on either OS; CI (`ubuntu-latest`) is the build gate until a dev
machine has it.

## Verify

```shell
flutter analyze        # must be clean (includes riverpod_lint plugin)
dart format --output=none --set-exit-if-changed .  # must be clean (or: dart format . then git diff --exit-code)
dart fix --dry-run     # nothing auto-fixable left
flutter test           # data-layer tests (test/data/), bootstrap widget test, golden tests (test/golden/, #019)
```

Lints via `flutter_lints` + `riverpod_lint` surface through `flutter analyze`;
`dart fix --dry-run` is a fix-hygiene check, not a second ruleset.

## Data layer (issue #002, done)

- Drift + SQLite (`drift`, `drift_flutter`; codegen `drift_dev`+`build_runner`).
  Generated `*.g.dart` files are committed; regenerate with:
  ```shell
  dart run build_runner build
  ```
- `lib/src/data/`: `database.dart`, `clock.dart`, `validation.dart`,
  `set_json_codec.dart`, `sets_repository.dart`, `stats_repository.dart`,
  `providers.dart`, `seed_loader.dart`. Tests in `test/data/` use
  `NativeDatabase.memory()` + overridable `Clock`.
- Ownership: `xp_total` ← #010 only; `streak_count`/`last_active_day` ← #011
  only; `recordAttempt` writes `attempts` rows only.

## Design language (issue #015)

- Tokens + theme live in `lib/src/theme/fox_streak_theme.dart`: `FoxStreakTheme.light()` / `.dark()` (orange seed, M3), `FoxSemanticColors` extension (success/error/XP-gold/streak-flame/info, AA-checked light + dark values), `FoxSpacing` / `FoxRadius` / `FoxButtonMetrics`, bold-heading/button type roles, system font only for MVP. Wired as `MaterialApp(theme:, darkTheme:)` in `main.dart`.
- **Reuse the kit, no ad-hoc styling.** `lib/src/widgets/` (`widgets.dart` barrel) owns chunky `FoxPrimaryButton` / `FoxSecondaryButton` / `FoxCheckButton` (48dp min, bold wrapping labels, hard-shadow press feel), `FoxFeedbackBanner`, `FoxProgressBar` (#010 composes level-progress on top), `FoxConfirmDialog`, `FoxEmptyState`, `FoxPet` (renders the equipped collectible pet's Lottie, final art out of scope), `FoxCelebration` + `FoxFeedback` haptics (toggle `foxHapticsEnabledProvider`, default on). Feature screens compose these; new raw colors, button styles, or dialog patterns need a design reason.
- Fox placement: empty states, result celebrations, streak moments only — never random decoration. Motion: instant green/red + bouncy micro-moments, encouraging copy, no shaming; animation budget reserves room for #014 lottie.
- A11y floor in kit: 48dp targets, screen-reader labels, wrapping (never clipped) labels; #012 owns the per-screen dark-mode / large-font / reader-flow pass. User-visible strings flow via `lib/l10n` arb params (DE + EN), never hardcoded in the kit.
- Each UI issue (#004–#014) carries a "follows #015" acceptance line pointing back here.

## Golden tests (issue #019)

- `test/golden/kit_golden_test.dart` snapshots each #015 kit widget under
  both `FoxStreakTheme.light()` and `.dark()` (plain
  `flutter_test`/`matchesGoldenFile`, no new dependency). `flutter test`
  already runs them — no separate command.
- **Baselines are per-OS**: `test/golden/goldens/<macos|windows|linux>/*.png`.
  Even with no custom fonts loaded (text renders via `flutter_test`'s
  placeholder font either way), Skia's text rasterization still differs
  subtly across OSes — confirmed 2026-10-16, 1.3-5.2% pixel diffs on every
  text-bearing widget between macOS- and `ubuntu-latest`-rendered goldens.
  A single cross-platform baseline set isn't viable; the test resolves the
  subfolder from `Platform.operatingSystem` at run time, matching how
  Flutter's own golden-test infra (Flutter Gold) keeps one baseline per
  platform instead of trying to eliminate the difference.
- When a kit widget's visuals intentionally change, regenerate your
  platform's baselines only (scope the run so you don't touch other
  widgets' goldens):
  ```shell
  flutter test --update-goldens test/golden
  ```
  Review the diffed PNGs before committing — an unexpected change here
  usually means an unintended visual regression, not a baseline to update.
  The `linux/` baselines can only be regenerated on `ubuntu-latest` itself
  (a `workflow_dispatch` CI job, per #019's fallback plan) — not from a
  macOS or Windows dev machine.

## Conventions

- **Conventional commits**, e.g. `feat: …`. Commit `pubspec.lock` (app, not package).
- Never commit `local.properties`, `.dart_tool/`, `.idea/`, `*.iml` — root `.gitignore` already excludes them; check `git status` before committing.
- State management: **Riverpod** (`flutter_riverpod`) with `ProviderScope` at root. Do not introduce Bloc.
- Package `fox_streak_app` (`com.example.fox_streak_app`); Android `minSdk 24` is pinned in `android/app/build.gradle.kts` — keep the pin, don't revert to `flutter.minSdkVersion`.
- Platforms in repo: `android/`, `ios/`, `windows/`, `macos/`. Keep all four; never add a plugin without iOS + Windows + macOS support.
- One tool call per message; batch independent calls as parallel messages in one turn.
