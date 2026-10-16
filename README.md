# FoxStreak

[![CI](https://github.com/julius-d/fox-streak/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/julius-d/fox-streak/actions/workflows/ci.yml)

Learning app with gamification (XP + streak + levels). Flutter, Android-first, iOS + Windows + macOS ready. Local-only, no login (MVP). Developed on both Windows and macOS.

- Package: `fox_streak_app` (`com.example.fox_streak_app`), display name `FoxStreak`
- State management: **Riverpod** (`flutter_riverpod`)
- Platforms: `android/`, `ios/`, `windows/`, `macos/` (from `flutter create`)
- Android: `minSdk 24`, Java 17, Kotlin JVM 17

## Prerequisites

- Flutter stable (3.47.6 verified) on `PATH`
- For Android builds: Android Studio + Android SDK (`flutter doctor` must show Android toolchain ✓)
- For Windows builds: Visual Studio with "Desktop development with C++" workload (Windows only)
- For macOS/iOS builds: Xcode (macOS only)
- For web runs: Chrome

## Commands

```shell
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run -d windows      # Windows desktop (Windows only)
flutter run -d macos        # macOS desktop (macOS only)
flutter run -d chrome       # Web
flutter run                 # Android device/emulator (needs Android SDK)
flutter build apk --debug   # Android APK (needs Android SDK; CI is the gate otherwise)
flutter build windows       # Windows release (Windows only)
```

> **Windows (PowerShell) note:** if a fresh shell doesn't inherit `flutter`/`git` on `PATH`, prefix the commands above with:
> ```powershell
> $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
> ```

## Formatting

```shell
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

Closing-proof convention: an issue closed on CI evidence records a green run
whose URL cites a `push`-triggered run with its `headSha` actually on `main`
(not a PR-branch check run), a red run URL that names the specific failing
step (not just "job failed"), and — if the red proof needed a revert — the
revert's own run must be green before the revert merges. See the #018
closing comment for the recorded proof (and its #020 correction).

> **Format authority:** `dart format` check in CI is authoritative; `.gitattributes`/CRLF normalization is out of scope unless a CI-only format failure proves otherwise.

## Device e2e (issue #016)

Four critical-flow `integration_test` specs (`integration_test/flow1_*`
through `flow4_*`), using only the Flutter SDK `integration_test` +
`flutter_test` stack (no Patrol, no new deps). Shared boot/settle helpers
live in `integration_test/helpers.dart`.

- Flow 1 — Library CRUD (#002/#003/#004)
- Flow 2 — Lesson play-through (#005-#009), incl. quit-leaves-no-dead-end
- Flow 3 — XP + streak tiers and day-boundary behavior (#010/#011)
- Flow 4 — Share round-trip (#002/#008); `share_plus`/`file_picker` are
  stubbed at the platform-interface level (`SharePlatform`/
  `FilePickerPlatform`) — no real share sheet or file dialog ever opens.

Each isolated in an in-memory DB + overridable `Clock` — never the real
on-device `fox_streak` database — with no network access.

```shell
flutter test integration_test/flow1_library_crud_test.dart -d macos
flutter test integration_test/flow2_lesson_playthrough_test.dart -d macos
flutter test integration_test/flow3_xp_streak_test.dart -d macos
flutter test integration_test/flow4_share_roundtrip_test.dart -d macos
```

Run each file individually (not the whole `integration_test/` dir in one
invocation) — this repo's macOS runs have known cross-test relaunch
flakiness at app-foreground time; each flow passes reliably standalone.
`-d windows` works too; the primary gate is any one real device/desktop
run (not the `flutter test integration_test` host-check, which only
compiles).

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

```shell
dart run build_runner build --delete-conflicting-outputs
```

## Project docs

- `issues/issue-001.md` — this bootstrap issue
- `issues/` — full backlog (#002 data model next)
