# FoxStreak

[![CI](https://github.com/julius-d/fox-streak/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/julius-d/fox-streak/actions/workflows/ci.yml)

Learning app with gamification (XP + streak + levels). Flutter, Android-first, iOS + Windows ready. Local-only, no login (MVP).

- Package: `fox_streak_app` (`com.example.fox_streak_app`), display name `FoxStreak`
- State management: **Riverpod** (`flutter_riverpod`)
- Platforms: `android/`, `ios/`, `windows/` (from `flutter create`)
- Android: `minSdk 24`, Java 17, Kotlin JVM 17

## Prerequisites

- Flutter stable (3.47.6 verified) on PATH: `C:\Users\juliu\coding-tools\flutter\bin`
- For Android builds: Android Studio + Android SDK (`flutter doctor` must show Android toolchain ✓ — still missing on this machine, CI is the gate)
- For Windows builds: Visual Studio with "Desktop development with C++" workload (installed ✓ — Community 2026 18.10.3, verified 2026-10-11)
- For web runs: Chrome (installed ✓)
- For iOS builds: Xcode on macOS

## Commands

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run -d windows      # Windows (VS ✓, works locally)
flutter run -d chrome       # Web (Chrome ✓, works locally)
flutter run                 # Android device/emulator (needs Android SDK — still missing)
flutter build apk --debug   # Android APK (needs Android SDK — still missing; CI is the gate)
flutter build windows       # Windows release (VS ✓, works locally)
```

## Formatting

```powershell
dart format .
```

## CI

[![CI](https://github.com/julius-d/fox-streak/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/julius-d/fox-streak/actions/workflows/ci.yml)

CI (`.github/workflows/ci.yml`) runs a single `ci` job on `ubuntu-latest`
with Flutter `3.47.6` (stable) on `push` to `main` and `pull_request`
targeting `main`. Concurrency cancels superseded runs on the same ref.
Steps run in order — format → analyze → fix-hygiene → test → Android debug
build (a failing early step hides later steps' signals; accepted tradeoff for
one Flutter setup on this small MVP).

| CI step | Rerun locally |
|---|---|
| `flutter pub get` | `flutter pub get` |
| `dart format --output=none --set-exit-if-changed .` (check-only, never mutates) | same |
| `flutter analyze` (includes `riverpod_lint` + strict casts per #017) | `flutter analyze` |
| `dart fix --dry-run` hygiene gate (fails unless the output is `Nothing to fix!`) | `dart fix --dry-run` |
| `flutter test` (unit/widget in `test/` only, not `integration_test/`) | `flutter test` |
| `flutter build apk --debug` (unsigned smoke build) | same — needs the Android SDK; expected to fail locally (see AGENTS.md), CI is the gate |

Intentional-failure proof: a commit with a `dart format` violation fails the
`Check formatting` step as expected (red run URL recorded in the #018 closing
comment); the green `main` run URL is recorded there as well.

> **Format authority:** `dart format` check in CI is authoritative; `.gitattributes`/CRLF normalization is out of scope unless a CI-only format failure proves otherwise.

## Data layer (issue #002)

Local-only persistence with Drift + SQLite. No accounts.

- Schema/tables: `lib/src/data/database.dart` (`schemaVersion = 1`)
- Repositories: `lib/src/data/sets_repository.dart`,
  `lib/src/data/stats_repository.dart`
- Share codec (`.foxstreak.json` v1): `lib/src/data/set_json_codec.dart`
- Clock abstraction + day helpers: `lib/src/data/clock.dart`
  (reused by streak logic in #011)
- Riverpod wiring: `lib/src/data/providers.dart`
- First-launch seeds: `assets/seed/demo_*.foxstreak.json`
  (via `SeedLoader`; format documented in `assets/seed/README.md`)

Column ownership: `xp_total` is written exclusively by #010 `XpService`;
`streak_count`/`last_active_day` exclusively by #011 `StreakService`;
`StatsRepository.recordAttempt` writes `attempts` rows only.

Sharing deps (`share_plus`, `file_picker`) support Android/iOS/Windows;
picker/share UI is wired in #003.

## Codegen (Drift)

Generated files (`*.g.dart`) are committed. After editing
`lib/src/data/database.dart` (or any `@DriftDatabase` file), regenerate:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Project docs

- `issues/issue-001.md` — this bootstrap issue
- `issues/` — full backlog (#002 data model next)
