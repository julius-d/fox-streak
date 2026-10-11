# Issue 023: App launcher icon from fox.png (Android + iOS + Windows)

Status: open | Priority: P2 | Type: branding | Refined-at: 2026-10-11

## Goal
Replace the default Flutter launcher icon with the FoxStreak fox (`assets/seed/fox.png`) on all three repo platforms (Android, iOS, Windows) using `flutter_launcher_icons`, including the modern icon set (Android adaptive + themed, iOS no-alpha marketing, Windows ICO).

## Decisions (2026-10-11, with repo owner)
- Source: use `assets/seed/fox.png` as-is (503 KB detailed mascot illustration). No simplified icon variant, no designer rework in this issue. Accepted risk: fine details (thin tail, small eyes) may lose legibility at 48dp; transparent corners rely on tool padding/background fill.
- Scope: all three platforms — `android/`, `ios/`, `windows/` (keep-all-three rule).
- Method: `flutter_launcher_icons` dev-only CLI (`^0.14.4` in `dev_dependencies`). This is a codegen tool, not a runtime plugin, so the iOS + Windows compatibility rule holds and no runtime dependency is added. Config lives in `flutter_launcher_icons.yaml` at repo root (tool default); `pubspec.yaml` alternative is out.
- Full modern set: Android adaptive foreground + background + Android 13+ monochrome, iOS `remove_alpha_ios`, Windows ICO regeneration.

## Acceptance criteria
- [ ] `dev_dependencies` contains `flutter_launcher_icons: ^0.14.4`; `flutter_launcher_icons.yaml` at root defines:
  - `image_path: "assets/seed/fox.png"` (global fallback)
  - Android: `android: true`, `min_sdk_android: 24` (matches pinned `minSdk 24`, not the tool default 21), `adaptive_icon_foreground: "assets/seed/fox.png"`, `adaptive_icon_background: "#FF9800"` (`Colors.orange` = `kFoxSeedColor` from #015), `adaptive_icon_foreground_inset: 16`, `adaptive_icon_monochrome: "assets/seed/fox.png"`
  - iOS: `ios: true`, `remove_alpha_ios: true`, `background_color_ios: "#FF9800"` (fills transparency; App Store 1024 icon must have no alpha)
  - Windows: `generate: true`, `image_path: "assets/seed/fox.png"`, `icon_size: 256` (max, for high-DPI crispness)
- [ ] `dart run flutter_launcher_icons` regenerates and commits: `android/app/src/main/res/mipmap-*/ic_launcher.png` + adaptive `mipmap-anydpi-v26/` XMLs, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` (incl. 1024 marketing without alpha), `windows/runner/resources/app_icon.ico`
- [ ] No runtime code changes; `flutter analyze`, `dart format`, `dart fix --dry-run` clean; `flutter test` green (no new tests required — asset-only change)
- [ ] Follows #015: adaptive/iOS-fill background reuses the #015 orange seed (`kFoxSeedColor`); no ad-hoc brand color

## Tasks
1. Add `flutter_launcher_icons: ^0.14.4` to `dev_dependencies`, `flutter pub get`.
2. Write `flutter_launcher_icons.yaml` per acceptance criteria.
3. Run `dart run flutter_launcher_icons`, verify each platform output (mipmaps, AppIcon set, ICO) and that the fox is centered/padded, not clipped (iOS rounded mask, Android adaptive safe zone).
4. Manual QA: `flutter run -d windows` shows new taskbar/window icon; `flutter run -d chrome` unaffected (web icons out of scope); Android/iOS visual check deferred to CI/device (no Android SDK locally).
5. Commit generated binaries + config + `pubspec.lock` (app convention).

## Out of scope
- New/simplified icon artwork, rounded-background variant, or final fox art (owned by #014); if fox.png proves illegible at small sizes, file a follow-up for `assets/icon/fox-icon.png`.
- Web (`web/manifest.json` icons + favicon) and macOS/Linux targets.
- App display-name rename (`android:label="fox_streak_app"` → FoxStreak) — separate change.
- Splash screen (`flutter_native_splash`) — separate change.

## Dependencies
- Builds on #001 (platforms exist) and #015 (orange seed `#FF9800` as icon background).
- Final art may revisit this in #014.

## Verify
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
flutter pub get
dart run flutter_launcher_icons
flutter analyze        # must be clean
dart format --output=none --set-exit-if-changed .  # must be clean
dart fix --dry-run     # nothing auto-fixable left
flutter test           # must be green
# Manual: flutter run -d windows (icon visible); Android APK / iOS via CI (no local Android SDK)
```
