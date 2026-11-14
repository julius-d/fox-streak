# Issue 129: Linux desktop app on par with macOS and Windows

Status: open | Type: enhancement | Refined-at: 2026-11-14

## Goal

A first Linux target was added in `26186a1` (`build: add linux`), but only the
generated Flutter scaffold. Someone starting FoxStreak on a Linux desktop should
get the same app as a macOS or Windows user: a phone-shaped window called
"Fox Streak" with the fox icon, where every feature works or has a sensible
Linux alternative. This is the base for shipping a Linux download in #130.

## Gaps found (review 2026-11-14)

- **Window shape**: on macOS and Windows the app opens as a centered,
  phone-sized window. On Linux it opens as a large landscape window instead.
- **Name**: the window title (and the program name) shows `fox_streak_app`
  instead of "Fox Streak".
- **Icon**: Linux gets no fox icon, neither in the window/taskbar nor in the
  app menu. #023 explicitly left Linux out.
- **Sharing a set**: Library's "Share" exports a `.foxstreak.json` file through
  the system share sheet. Linux has no share sheet for files, so the action
  fails or does nothing.
- **Importing a set**: on Linux the file picker relies on a system dialog helper
  (zenity / kdialog). If neither is installed, the import button silently does
  nothing.
- **Sounds**: level-up and answer sounds rely on the system's media
  framework (GStreamer). A system without it must still run the app, just
  without sound.
- **Data location**: the app database would land as a visible file in the
  user's `~/Documents` folder (the current default), not in the usual hidden
  app-data folder.
- **No build signal**: nothing checks that the Linux app still builds, so it can
  break unnoticed.

## Decisions (2026-11-14, with repo owner)

- Share on Linux = "Save file" dialog (no share sheet). Confirmation snackbar
  "Set saved" with a "Show folder" action.
- Missing file dialog → friendly message that names the fix (installing
  zenity). It applies to both import and the new save dialog.
- No audio available → skip sounds quietly. The Settings Sound toggle stays
  unchanged, with no extra hint.
- Data lives in the standard hidden Linux app-data folder, not `~/Documents`.
  There are no Linux users yet, so no migration is needed.
- x64 desktop Linux only. Window centering is best-effort: on Wayland the
  desktop decides where new windows appear.

## Desired behavior

1. **Window**: on launch the app opens a phone-sized window, the same size as
   on macOS/Windows, centered where the desktop allows it. The user can resize
   it.
2. **Name**: the window title, taskbar/dock tooltip and app-menu entry read
   "Fox Streak", the same name as on the other desktops.
3. **Icon**: the fox icon (same artwork as the other platforms) shows in the
   window/taskbar and in the desktop's app menu/launcher.
4. **Sharing a set on Linux**: the Share action opens a "Save file" dialog
   with the suggested `<title>.foxstreak.json` filename.
   - Saving writes the file and shows a "Set saved" snackbar with a
     **Show folder** action that opens the containing folder in the file
     manager, so the user can send the file on from there.
   - Cancelling does nothing, with no error.
   - Android/iOS/macOS/Windows keep the share sheet unchanged.
5. **Importing a set on Linux**: works with the desktop's normal file dialog.
6. **No file dialog available** (import or save): instead of a silent no-op,
   the user sees a friendly, encouraging message that names the fix, e.g.
   "Your system can't show a file dialog yet. Installing zenity fixes this."
7. **Sounds**: if the system can't play audio, the app still starts and works.
   Sounds are skipped quietly and nothing crashes. The Sound setting looks and
   behaves as before.
8. **Data**: progress, streaks, XP and sets are kept in the standard hidden
   per-user app-data folder. Nothing appears in `~/Documents`. Data survives
   app restarts and replacing the app file with a newer version (#130).
9. **System integration**: light/dark mode follows the desktop setting where
   the desktop reports one. The app language (DE/EN) follows the system
   language.
10. **Everything else behaves exactly as on macOS/Windows**: lessons, streaks,
    XP, pets, marketplace, settings and links to the web. There's no Android
    home-screen widget on Linux, same as the other desktops.
11. **Stays working**: every change is checked to still build for Linux, the
    same way the Android build is checked today.

## Acceptance criteria

- [ ] Launching on Linux opens a phone-sized (same as macOS/Windows), resizable "Fox Streak" window with the fox icon; centered on X11 (best-effort on Wayland).
- [ ] The fox icon and the "Fox Streak" name appear in the desktop app menu / launcher entry.
- [ ] Share on Linux opens a save dialog with the suggested `<title>.foxstreak.json` filename. Save writes a file that re-imports correctly, and Cancel is a no-op.
- [ ] After saving, a "Set saved" snackbar appears; its "Show folder" action opens the containing folder in the file manager.
- [ ] Share on Android/iOS/macOS/Windows is unchanged.
- [ ] Import on Linux works via the system file dialog.
- [ ] With no file-dialog helper installed, both import and save show the friendly "install zenity" message instead of doing nothing.
- [ ] The app runs without sound (no crash, no error shown) when audio playback isn't available. The Sound toggle is unchanged.
- [ ] On Linux the database is stored in the per-user app-data folder (not `~/Documents`). Data survives restart and replacing the app binary.
- [ ] Dark mode and DE/EN language follow the system on a stock GNOME desktop.
- [ ] All new user-visible copy ("Set saved", "Show folder", no-dialog message) exists in DE + EN (arb), with encouraging tone.
- [ ] Tests cover the Linux-specific share/save and no-dialog decisions (platform overridable in tests).
- [ ] CI fails when the Linux build breaks.
- [ ] AGENTS.md lists Linux as a kept platform: "Keep all five" and the plugin-support rule includes Linux.
- [ ] Follows #015: snackbar/message reuse the kit, with no ad-hoc styling.

## Out of scope

- Publishing a Linux download (AppImage) in the release tool: #130.
- A Linux home-screen widget/applet.
- ARM (arm64) Linux builds.
- Store listings (Flathub, Snap Store).
- Changing where data is stored on Windows/macOS.

## Dependencies

- Builds on `26186a1` (Linux scaffold) and #023 (fox icon artwork).
- Blocks #130.
