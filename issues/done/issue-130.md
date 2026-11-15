# Issue 130: Linux AppImage in the multi-platform release

Status: done | Type: build | Refined-at: 2026-11-14
Completed-at: 2026-11-15

## Goal

Every GitHub release (`Multi-Platform Release` workflow) currently ships an
Android APK, a macOS DMG and a Windows ZIP. Linux users should get a download
of their own: a single **AppImage** file they can download and start, with no
install steps and no build from source.

## Decisions (2026-11-14, with repo owner)

- Format: AppImage only (no tar.gz / .deb / Flatpak / Snap).
- Architecture: x86_64 only.
- Minimum system: Ubuntu 24.04 LTS and distros of similar age (e.g. Fedora
  40+, Debian 13+). Older distros (Ubuntu 22.04, Debian 12) are not supported.
- App-menu entry: through the standard AppImage tools (Gear Lever,
  AppImageLauncher), with no in-app "Add to menu" feature. The AppImage
  carries the name and icon those tools need.
- No separate checksum file, same as the other release assets.

## Desired behavior

1. **One extra asset per release**: next to the APK, DMG and ZIP, each release
   has `fox-streak-<version>-linux-x86_64.AppImage`, with the same version and
   the same naming scheme as the other assets.
2. **Download and run**: on a stock Ubuntu 24.04+ desktop (or similar-aged
   Fedora/Debian), the user downloads the file, marks it executable and starts
   it. Nothing needs to be installed first. In particular, no
   `libfuse2`, which current Ubuntu no longer ships. The app opens with the
   "Fox Streak" name and fox icon, as in #129.
3. **Menu integration**: when the user integrates the AppImage with Gear Lever
   or AppImageLauncher, the app-menu entry shows "Fox Streak" with the fox
   icon.
4. **Same app**: the AppImage is the same build and version as the other
   platforms in that release (the in-app version matches the release tag).
5. **Updating keeps progress**: replacing an older AppImage with a newer one
   keeps all progress, streaks, XP and sets (data lives outside the file, see
   #129).
6. **All-or-nothing release**: if the Linux build fails, no release is
   published, same as when Android, macOS or Windows fails today.
7. **Release notes help Linux users**: the release page has a short Linux
   section covering:
   - how to start it (make executable, then run)
   - the minimum system (Ubuntu 24.04+ or similar)
   - optional app-menu integration via Gear Lever / AppImageLauncher
   - what it relies on from the system: a file dialog helper (zenity) for
     import/save, and system sound support (otherwise the app is just silent).
8. **Release summary** lists the Linux AppImage alongside the other uploaded
   assets.

## Acceptance criteria

- [ ] A release run publishes `fox-streak-<version>-linux-x86_64.AppImage` alongside APK/DMG/ZIP.
- [ ] The downloaded AppImage starts on a stock Ubuntu 24.04 LTS desktop after `chmod +x`, with no extra installs (no `libfuse2`).
- [ ] The app shows the "Fox Streak" name and fox icon, and reports the release version.
- [ ] Integrated via Gear Lever or AppImageLauncher, the menu entry shows "Fox Streak" with the fox icon.
- [ ] Replacing the AppImage with a newer release keeps existing progress.
- [ ] A failing Linux build blocks the whole release (no partial release).
- [ ] The release notes contain the Linux section (start hint, minimum system, menu integration, zenity/sound expectations) in addition to the changelog.
- [ ] Release summary output mentions the AppImage.

## Notes for implementation

- Classic AppImages need `libfuse2` at runtime, which stock Ubuntu 24.04
  lacks. The static AppImage runtime avoids this and is needed for the
  "no extra installs" criterion.
- An AppImage only runs on systems at least as new as the one it was built on.
  The chosen baseline (Ubuntu 24.04+) matches `ubuntu-latest`. If that runner
  moves to a newer Ubuntu, the baseline moves with it unless the build is
  pinned to 24.04.

## Out of scope

- tar.gz, .deb, Flatpak or Snap packages.
- arm64 builds.
- Ubuntu 22.04 / Debian 12 or older.
- Signing the AppImage, AppImage auto-update, checksum files.
- An in-app "Add to app menu" feature.
- Making the Linux app itself feature-complete: #129.

## Dependencies

- Depends on #129 (Linux app on par: window, name, icon, share/import, data folder).
- Extends `.github/workflows/release.yml`.

## Notes from #129 (2026-11-15)

- Reuse `linux/packaging/io.github.juliusd.foxstreak.{desktop,png}` (also in
  the bundle's `share/`); the desktop file name must stay the app id so
  GNOME/Wayland map the window to it.
- `audioplayers_linux` links `libgstreamer-1.0`, `-app-1.0` and `-audio-1.0`
  dynamically: the AppImage either bundles them or relies on the host's
  (present on stock Ubuntu 24.04 desktops). A missing `playbin` plugin alone is
  handled in-app (#129, #135).

## Summary

- `tool/build_appimage.sh` packages the Linux bundle into an AppDir (whole bundle in `usr/bin`, #129 desktop file + icon at the root, `AppRun`) and builds it with appimagetool 1.9.0's static runtime (no libfuse2).
- `release.yml`: new `build-linux` job (pinned `ubuntu-24.04`), required by `release`; asset `fox-streak-<version>-linux-x86_64.AppImage`; release body = changelog + `.github/release-notes-linux.md`; summary line added.
- `ci.yml` smoke-packages the debug bundle and checks no libfuse link + AppDir content. README/CONTRIBUTING updated.
- Not verifiable on this macOS machine: first real proof is the CI run and the next release (no GStreamer bundling; relies on host libs).

## Code review

- appimagetool download was unverified.
  Fixed: pinned sha256 in `tool/build_appimage.sh`.
- Release notes named zenity, but the app uses the XDG desktop portal (AGENTS.md, #129).
  Fixed: notes now name `xdg-desktop-portal-gtk`.
- CI smoke never runs the app (AppRun / `/proc/self/exe` path untested) and the `ldd` libfuse check is weak.
  Not fixed: needs a Linux host with a display to get right; first release run is the proof.
- Smoke job uses `ubuntu-latest`, release pins `ubuntu-24.04`.
  Not fixed: harmless today, same as other CI jobs.
