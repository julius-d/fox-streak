# Issue 048: App shows raw package name (`fox_streak_app`) instead of a display name

Status: open | Priority: P3 | Type: bug | Refined-at: 2026-10-17

## Goal

The app's user-visible name leaks the raw Dart/package identifier
`fox_streak_app` (underscores, `_app` suffix) instead of a proper display
name, on every platform except iOS (which already has a decent, if
inconsistent, override):

- **Android** (`android/app/src/main/AndroidManifest.xml`): `android:label="fox_streak_app"` —
  shows under the home-screen icon and in app switcher/settings.
- **Windows**: `windows/runner/Runner.rc` — `ProductName`, `FileDescription`,
  `InternalName` are all `"fox_streak_app"`; `windows/runner/main.cpp:30`
  sets the window title to `L"fox_streak_app"`.
- **macOS**: `macos/Runner/Configs/AppInfo.xml` — `PRODUCT_NAME = fox_streak_app`
  (per its own comment, this is also the Flutter window title).
- **iOS** (`ios/Runner/Info.plist`): `CFBundleDisplayName` is already
  `"Fox Streak App"` (someone fixed this one, inconsistently with the
  others), but `CFBundleName` is still the raw `"fox_streak_app"`.

Fix the display name everywhere it's user-visible, consistently, without
touching app identity (bundle ID / applicationId / Dart package name).

## Decisions

- Display name is **"Fox Streak"** everywhere (replacing iOS's current
  "Fox Streak App" too, for consistency across platforms).
- All four platforms get fixed in this issue (not Android-only), since the
  same raw-name defect exists on Windows and macOS, and iOS needs
  normalizing.
- App identity stays untouched: `applicationId`/bundle ID
  `com.example.fox_streak_app`, pubspec package name `fox_streak_app`, and
  the Windows binary filename (`fox_streak_app.exe`, from `BINARY_NAME` in
  `windows/CMakeLists.txt`) are unaffected by this issue — only
  user-visible display strings change. `Runner.rc`'s `OriginalFilename`
  stays `"fox_streak_app.exe"` since it must match the actual binary, not
  the display name.
- `com.example` company-name placeholders (Windows `CompanyName`,
  `LegalCopyright`) are left as-is — separate, pre-existing concern, not
  part of "the name of the app".

## Acceptance criteria

- [ ] Android: `android:label` in `AndroidManifest.xml` is `"Fox Streak"`.
- [ ] iOS: `CFBundleDisplayName` and `CFBundleName` in `Info.plist` are both
      `"Fox Streak"`.
- [ ] macOS: `PRODUCT_NAME` in `macos/Runner/Configs/AppInfo.xml` is
      `"Fox Streak"`.
- [ ] Windows: `ProductName`, `FileDescription`, and `InternalName` in
      `windows/runner/Runner.rc` are `"Fox Streak"`; the window title string
      in `windows/runner/main.cpp` is `L"Fox Streak"`.
- [ ] `applicationId`/bundle identifiers, `pubspec.yaml`'s `name:`, and the
      Windows binary filename (`BINARY_NAME`/`OriginalFilename`) are
      unchanged.
- [ ] Manually verified on at least one platform per dev machine (per
      AGENTS.md toolchain notes, not every platform is buildable from every
      machine): launcher icon label / taskbar / window title shows
      "Fox Streak", not "fox_streak_app" or "Fox Streak App".
- [ ] `flutter analyze` / `dart format` / `dart fix --dry-run` /
      `flutter test` stay clean (no Dart source expected to change).

## Out of scope

- Renaming `applicationId`/bundle ID or the Dart package name
  (`fox_streak_app`) — app-store/install identity, a much larger concern;
  AGENTS.md explicitly pins the current package name.
- The `com.example` company-name placeholder (Windows `CompanyName`,
  `LegalCopyright`; Android/iOS bundle-id vendor segment).
- Localizing the app name per DE/EN — native app display names are a single
  fixed platform-level string, not routed through `lib/l10n`; no l10n entry
  needed.
- The app launcher icon itself (unaffected, no icon asset referenced here).

## Dependencies

- None — touches only platform scaffold config generated at project
  creation (#001), no app code.

## Verify

```shell
flutter analyze
dart format --output=none --set-exit-if-changed .
dart fix --dry-run
flutter test
```

Plus manual check per platform (build/run and confirm the displayed name):
`flutter run -d android`, `-d macos`, `-d windows` (Windows dev machine
only), `-d ios` (macOS with Xcode only).
