# Issue 001: Flutter project bootstrap (Android-first, iOS-ready + Windows)

Status: done | Priority: P0 | Type: setup

## Goal
Create Flutter project so we can build Android APK now and iOS/Windows later with no rework.

## Decisions
- Package `fox_streak_app` (`com.example.fox_streak_app`), display `FoxStreak`
- State management: Riverpod (`flutter_riverpod` ^3.4.3)
- Platforms in repo: `android/`, `ios/`, `windows/` (Flutter 3.47.6)
- Android: `minSdk 24` pinned in `android/app/build.gradle.kts`, Java 17, Kotlin JVM 17
- Lints: `flutter_lints` via `analysis_options.yaml`; `dart format` for formatting

## Verified 2026-10-04
- [x] `flutter analyze` → No issues found
- [x] `flutter test` → All tests passed (bootstrap home renders)
- [x] `flutter create --platforms=ios` and `--platforms=windows` folders present
- [ ] `flutter run` / `flutter build apk --debug` — BLOCKED: Android SDK missing (`flutter doctor`: Android toolchain X). Needs Android Studio.
- [ ] `flutter build windows` — BLOCKED: Visual Studio with C++ workload missing. Folder exists, build needs VS.

## README
See root `README.md` for setup, run, test, build commands (Android + Windows + iOS notes).

## Out of scope
Backend, auth, cloud sync. Local-only (see #002).
