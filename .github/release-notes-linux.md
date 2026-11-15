
## Linux (AppImage)

Download `fox-streak-*-linux-x86_64.AppImage`, make it executable and run it:

```shell
chmod +x fox-streak-*-linux-x86_64.AppImage
./fox-streak-*-linux-x86_64.AppImage
```

- **Minimum system:** Ubuntu 24.04 or a similar-aged distro (Fedora 40+, Debian 13+), x86_64. Nothing needs to be installed first (no `libfuse2`).
- **App menu (optional):** integrate the file with [Gear Lever](https://flathub.org/apps/it.mijorus.gearlever) or AppImageLauncher.
- **Updating:** replace the file with the newer one — your progress is kept, it lives outside the AppImage.
- **Relies on your system for:** a file dialog helper for import/save (the XDG desktop portal, e.g. `xdg-desktop-portal-gtk`; most desktops have it, `zenity` is not needed), and system sound support (GStreamer). Without sound support the app is simply silent.
