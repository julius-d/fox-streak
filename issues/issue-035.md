# Issue 035: Native splash screen (Android/iOS) for cold-start black screen

Status: done | Priority: P3 | Type: polish | Completed-at: 2026-10-15

## Goal
Replace the stock `flutter create` launch background with a branded
`flutter_native_splash` screen so cold start doesn't show a plain
black/white rectangle while the Flutter engine spins up.

Found while investigating a "screen stays black for quite a while on
launch" report. Root cause: the repo never customized the Flutter
template's native launch screen —
`android/app/src/main/res/drawable/launch_background.xml` is still plain
white, and `android/app/src/main/res/values-night/styles.xml`'s
`LaunchTheme` parent (`Theme.Black.NoTitleBar`) resolves that same
background to solid black on a device in dark mode (the app's
`themeMode: ThemeMode.system` follows the OS). `ios/Runner/Base.lproj/
LaunchScreen.storyboard` is likewise the empty default. That native,
OS-drawn window is shown before the Flutter engine attaches and paints
its first frame, so nothing in Dart (not even a loading spinner) can
appear during it — the gap is just engine/VM startup time, stretched
further in debug builds (JIT, VM service attach). Already deferred once
as "separate change" in #023 (launcher icon issue) rather than fixed
there.

Not a data-layer bug: `SeedLoader.ensureSeeded` only runs lazily when the
Library screen opens, and `profileProvider` (`StreamProvider`) shows a
`CircularProgressIndicator` once Flutter is actually running — neither
contributes to the pre-first-frame black window.

## Acceptance criteria
- [x] `flutter_native_splash: ^2.4.8` added to `dev_dependencies` (dev-only
      codegen tool, like `flutter_launcher_icons` in #023 — no runtime
      plugin, so the "iOS + Windows + macOS plugin support" rule in
      AGENTS.md doesn't block this).
- [x] `flutter_native_splash.yaml` at repo root configures a branded splash
      (background color = `kFoxSeedColor` `#FF9800` from #015, centered
      `assets/fox.png`) for both `color` and `color_dark` variants, so dark
      mode gets the branded splash instead of a plain black rectangle.
- [x] `dart run flutter_native_splash:create` regenerates and commits the
      Android (`drawable*/launch_background.xml`, `values*/styles.xml`,
      Android 12+ `drawable*/android12splash.xml` + manifest entries) and
      iOS (`LaunchScreen.storyboard`, `Assets.xcassets` splash images)
      output.
- [x] Windows/macOS stay out of scope (desktop targets don't have an
      equivalent native-splash startup gap and `flutter_native_splash`
      doesn't generate for them) — repo's "keep all four platforms" rule
      doesn't apply here since this isn't a plugin/dependency being added
      to the Flutter app itself, just platform-specific native resources.
- [x] No runtime Dart code changes; `flutter analyze`, `dart format`,
      `dart fix --dry-run` clean; `flutter test` green (asset/config-only
      change).
- [x] Follows #015: splash background reuses the orange seed color, no
      ad-hoc brand color.

## Out of scope
- Removing or shortening actual engine/VM startup time (debug-mode JIT
  overhead is inherent to `flutter run`; release builds are already
  faster).
- Windows/macOS native splash (see acceptance criteria).
- Any animated/Lottie splash (would collide with the repo's "no lottie
  dep" rule — see #032).

## Dependencies
- Builds on #015 (`kFoxSeedColor` orange seed) and `assets/fox.png`.
- Related to #023, which deferred this exact scope ("Splash screen
  (`flutter_native_splash`) — separate change").

## Verify
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
flutter pub get
dart run flutter_native_splash:create
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
# Manual: cold-start on Android emulator in both light and dark OS mode,
# confirm branded splash (not black/white) appears instead of the gap.
```

## Summary
Added `flutter_native_splash` (dev-only) + `flutter_native_splash.yaml`
(orange `#FF9800` background, centered `assets/fox.png`, same values for
`color_dark`/`image_dark` and the Android 12+ `android_12` block), then ran
`dart run flutter_native_splash:create` to regenerate Android
drawables/styles (incl. `values-v31`/`values-night-v31` for Android 12+)
and iOS `LaunchScreen` assets/`Info.plist`. No Dart code touched.
Manually verified on the Android emulator (`flutter build apk --debug` +
`adb install`/`am start`): cold start now shows the branded orange fox
splash instead of the stock black/white rectangle (screenshots captured
mid-launch). Dark-mode styles/drawables were generated with the identical
orange color/image, so no separate black splash remains in dark mode.

## Code review
No findings. Reviewer checked yaml color/image consistency across
light/dark/android_12, verified generated native resources aren't
half-updated placeholders, confirmed splash PNGs keep real transparency
(so the orange native background shows through), and independently
re-ran `flutter analyze`/`dart format` rather than trusting this issue's
claims.
