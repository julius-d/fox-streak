# AGENTS.md — fox-streak

Flutter learning app (FoxStreak). Local-only MVP, no backend/auth. Backlog lives in `issues/` (see `issues/` for the current range) — read the relevant issue before coding.

## Shell environment (Windows — read this first)

- Commands run in **PowerShell**, but `flutter`/`git` are **not** on the inherited `PATH`.
  Prefix every shell command with:
  ```powershell
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
  ```
- Flutter SDK: `C:\Users\juliu\coding-tools\flutter\bin\flutter.bat` (3.47.6, stable). Git: `C:\Program Files\Git\cmd\git.exe`.
- `winget` `msstore` source prompts interactively and fails headless — always pass `--source winget`.
- PowerShell surfaces git's stderr (`To https://…`) as `NativeCommandError` — a push is successful if output shows `main -> main`, regardless of that noise.

## Toolchains (verified 2026-10-11 via `flutter doctor -v`)

- `flutter doctor`: Flutter 3.47.6 ✓, Windows 11 ✓, **Android toolchain ✗
  (no Android SDK — the only missing piece)**, Chrome ✓, Visual Studio ✓
  (Community 2026 18.10.3 + Windows 10 SDK 10.0.26100.0), connected devices
  Windows + Chrome + Edge ✓, network ✓.
- What works: `flutter analyze`, `flutter test`, `dart format`,
  `flutter create --platforms=…`, `flutter run -d windows`,
  `flutter build windows`, `flutter run -d chrome` (web).
- Still blocked until user installs Android Studio + SDK: `flutter run` on an
  Android device/emulator and `flutter build apk` / `appbundle`
  (CI on `ubuntu-latest` is the build gate until then).

## Verify

```powershell
flutter analyze        # must be clean (includes riverpod_lint plugin)
dart format --output=none --set-exit-if-changed .  # must be clean (or: dart format . then git diff --exit-code)
dart fix --dry-run     # nothing auto-fixable left
flutter test           # data-layer tests (test/data/) + bootstrap widget test
```

Lints via `flutter_lints` + `riverpod_lint` surface through `flutter analyze`;
`dart fix --dry-run` is a fix-hygiene check, not a second ruleset.

## Data layer (issue #002, done)

- Drift + SQLite (`drift`, `drift_flutter`; codegen `drift_dev`+`build_runner`).
  Generated `*.g.dart` files are committed; regenerate with:
  ```powershell
  dart run build_runner build --delete-conflicting-outputs
  ```
- `lib/src/data/`: `database.dart`, `clock.dart`, `validation.dart`,
  `set_json_codec.dart`, `sets_repository.dart`, `stats_repository.dart`,
  `providers.dart`, `seed_loader.dart`. Tests in `test/data/` use
  `NativeDatabase.memory()` + overridable `Clock`.
- Ownership: `xp_total` ← #010 only; `streak_count`/`last_active_day` ← #011
  only; `recordAttempt` writes `attempts` rows only.

## Design language (issue #015)

- Tokens + theme live in `lib/src/theme/fox_streak_theme.dart`: `FoxStreakTheme.light()` / `.dark()` (orange seed, M3), `FoxSemanticColors` extension (success/error/XP-gold/streak-flame/info, AA-checked light + dark values), `FoxSpacing` / `FoxRadius` / `FoxButtonMetrics`, bold-heading/button type roles, system font only for MVP. Wired as `MaterialApp(theme:, darkTheme:)` in `main.dart`.
- **Reuse the kit, no ad-hoc styling.** `lib/src/widgets/` (`widgets.dart` barrel) owns chunky `FoxPrimaryButton` / `FoxSecondaryButton` / `FoxCheckButton` (48dp min, bold wrapping labels, hard-shadow press feel), `FoxFeedbackBanner`, `FoxProgressBar` (#010 composes level-progress on top), `FoxConfirmDialog`, `FoxEmptyState`, `FoxMascot` (`empty | lit | on-fire` placeholder, final art out of scope), `FoxCelebration` + `FoxFeedback` haptics (toggle `foxHapticsEnabledProvider`, default on). Feature screens compose these; new raw colors, button styles, or dialog patterns need a design reason.
- Fox placement: empty states, result celebrations, streak moments only — never random decoration. Motion: instant green/red + bouncy micro-moments, encouraging copy, no shaming; animation budget reserves room for #014 lottie (no lottie dep).
- A11y floor in kit: 48dp targets, screen-reader labels, wrapping (never clipped) labels; #012 owns the per-screen dark-mode / large-font / reader-flow pass. User-visible strings flow via `lib/l10n` arb params (DE + EN), never hardcoded in the kit.
- Each UI issue (#004–#014) carries a "follows #015" acceptance line pointing back here.

## Conventions

- **Conventional commits**, e.g. `feat: …`. Commit `pubspec.lock` (app, not package).
- Never commit `local.properties`, `.dart_tool/`, `.idea/`, `*.iml` — root `.gitignore` already excludes them; check `git status` before committing.
- State management: **Riverpod** (`flutter_riverpod`) with `ProviderScope` at root. Do not introduce Bloc.
- Package `fox_streak_app` (`com.example.fox_streak_app`); Android `minSdk 24` is pinned in `android/app/build.gradle.kts` — keep the pin, don't revert to `flutter.minSdkVersion`.
- Platforms in repo: `android/`, `ios/`, `windows/`. Keep all three; never add a plugin without iOS + Windows support.
- One tool call per message; batch independent calls as parallel messages in one turn.
