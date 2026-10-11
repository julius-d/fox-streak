# FoxStreak

Learning app with gamification (XP + streak + levels). Flutter, Android-first, iOS + Windows ready. Local-only, no login (MVP).

- Package: `fox_streak_app` (`com.example.fox_streak_app`), display name `FoxStreak`
- State management: **Riverpod** (`flutter_riverpod`)
- Platforms: `android/`, `ios/`, `windows/` (from `flutter create`)
- Android: `minSdk 24`, Java 17, Kotlin JVM 17

## Prerequisites

- Flutter stable (3.47.6 verified) on PATH: `C:\Users\juliu\coding-tools\flutter\bin`
- For Android builds: Android Studio + Android SDK (`flutter doctor` must show Android toolchain ✓)
- For Windows builds: Visual Studio with "Desktop development with C++" workload
- For iOS builds: Xcode on macOS

## Commands

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter run -d windows      # Windows (needs VS)
flutter run                 # Android device/emulator (needs Android SDK)
flutter build apk --debug   # Android APK (needs Android SDK)
flutter build windows       # Windows release (needs VS)
```

## Formatting

```powershell
dart format .
```

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
