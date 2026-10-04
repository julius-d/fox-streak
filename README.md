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

## Project docs

- `issues/issue-001.md` — this bootstrap issue
- `issues/` — full backlog (#002 data model next)
