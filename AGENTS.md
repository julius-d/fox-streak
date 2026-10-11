# AGENTS.md — fox-streak

Flutter learning app (FoxStreak). Local-only MVP, no backend/auth. Backlog lives in `issues/` (`issue-001.md` … `issue-013.md`) — read the relevant issue before coding.

## Shell environment (Windows — read this first)

- Commands run in **PowerShell**, but `flutter`/`git` are **not** on the inherited `PATH`.
  Prefix every shell command with:
  ```powershell
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
  ```
- Flutter SDK: `C:\Users\juliu\coding-tools\flutter\bin\flutter.bat` (3.47.6, stable). Git: `C:\Program Files\Git\cmd\git.exe`.
- `winget` `msstore` source prompts interactively and fails headless — always pass `--source winget`.
- PowerShell surfaces git's stderr (`To https://…`) as `NativeCommandError` — a push is successful if output shows `main -> main`, regardless of that noise.

## Toolchains (know what's missing)

- `flutter doctor`: Android toolchain ✗ (no Android SDK), Visual Studio ✗, Chrome ✗. Windows device attached ✓.
- What works without them: `flutter analyze`, `flutter test`, `flutter create --platforms=…`, `dart format`.
- Blocked until user installs: `flutter run`/`build apk` (needs Android Studio + SDK), `flutter build windows` (needs VS + C++ workload).

## Verify

```powershell
flutter analyze        # must be clean
flutter test           # widget test: bootstrap home renders
dart format .          # formatter (no separate lint step; lints via flutter_lints in analysis_options.yaml)
```

## Conventions

- **Conventional commits**, e.g. `feat: …`. Commit `pubspec.lock` (app, not package).
- Never commit `local.properties`, `.dart_tool/`, `.idea/`, `*.iml` — root `.gitignore` already excludes them; check `git status` before committing.
- State management: **Riverpod** (`flutter_riverpod`) with `ProviderScope` at root. Do not introduce Bloc.
- Package `fox_streak_app` (`com.example.fox_streak_app`); Android `minSdk 24` is pinned in `android/app/build.gradle.kts` — keep the pin, don't revert to `flutter.minSdkVersion`.
- Platforms in repo: `android/`, `ios/`, `windows/`. Keep all three; never add a plugin without iOS + Windows support.
- One tool call per message; batch independent calls as parallel messages in one turn.
