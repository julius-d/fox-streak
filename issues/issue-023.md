# Issue 023: App launcher icon from fox.png (Android + iOS + Windows)

Status: open | Priority: P2 | Type: branding | Refined-at: 2026-10-11

## Goal
Replace the default Flutter launcher icon with the FoxStreak fox (`assets/seed/fox.png`) on all three repo platforms (Android, iOS, Windows) using `flutter_launcher_icons`, including the modern icon set (Android adaptive, iOS no-alpha marketing, Windows ICO). Android 13+ monochrome/themed icon is intentionally omitted for MVP (needs a simplified silhouette — see Out of scope).

## Decisions (2026-10-11, with repo owner)
- Source: use `assets/seed/fox.png` as-is (503 KB detailed mascot illustration). No simplified icon variant, no designer rework in this issue. Accepted risk: fine details (thin tail, small eyes) may lose legibility at 48dp; transparent corners rely on tool padding/background fill.
- Scope: all three platforms — `android/`, `ios/`, `windows/` (keep-all-three rule).
- Method: `flutter_launcher_icons` dev-only CLI (`^0.14.4` in `dev_dependencies`). This is a codegen tool, not a runtime plugin, so the iOS + Windows compatibility rule holds and no runtime dependency is added. Config lives in `flutter_launcher_icons.yaml` at repo root (tool default); `pubspec.yaml` alternative is out.
- Full modern set (minus monochrome): Android adaptive foreground + background, iOS `remove_alpha_ios`, Windows ICO regeneration. Monochrome omitted: a detailed full-color mascot makes a poor Android 13+ themed icon (needs a single-color silhouette); follow-up owns a simplified asset.

## Acceptance criteria
- [ ] `dev_dependencies` contains `flutter_launcher_icons: ^0.14.4`; `flutter_launcher_icons.yaml` at root defines:
  - `image_path: "assets/seed/fox.png"` (global fallback)
  - Android: `android: true`, `min_sdk_android: 24` (matches pinned `minSdk 24`, not the tool default 21), `adaptive_icon_foreground: "assets/seed/fox.png"`, `adaptive_icon_background: "#FF9800"` (`Colors.orange` = `kFoxSeedColor` from #015), `adaptive_icon_foreground_inset: 16` (tool default, explicit). No `adaptive_icon_monochrome` for MVP (omitted — see Decisions).
  - iOS: `ios: true`, `remove_alpha_ios: true`, `background_color_ios: "#FF9800"` (fills transparency; App Store 1024 icon must have no alpha)
  - Windows (nested block, not flat keys):
    ```yaml
    windows:
      generate: true
      image_path: "assets/seed/fox.png"
      icon_size: 256 # max (48–256, default 48), for high-DPI crispness
    ```
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
- New/simplified icon artwork, rounded-background variant, final fox art (currently unscoped — #014 covers question images/lottie, not fox art), or a simplified monochrome silhouette for Android 13+ themed icons; if fox.png proves illegible at small sizes, file a follow-up for `assets/icon/fox-icon.png` (plus a silhouette variant for `adaptive_icon_monochrome`).
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
