#!/usr/bin/env bash
# Packages a built Linux bundle as a single AppImage (issue #130).
#   tool/build_appimage.sh <bundle-dir> <output.AppImage>
# e.g. tool/build_appimage.sh build/linux/x64/release/bundle \
#        fox-streak-1.2.3-linux-x86_64.AppImage
# Linux x86_64 only. Uses appimagetool's static type-2 runtime, so the result
# runs without libfuse2 (which Ubuntu 24.04 no longer ships).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <bundle-dir> <output.AppImage>" >&2
  exit 64
fi

app_id=io.github.juliusd.foxstreak
appimagetool_version=1.9.0
appimagetool_sha256=46fdd785094c7f6e545b61afcfb0f3d98d8eab243f644b4b17698c01d06083d1
bundle=$(cd "$1" && pwd)
output=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
packaging="$(cd "$(dirname "$0")/.." && pwd)/linux/packaging"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
appdir="$work/AppDir"

# The Flutter bundle finds lib/ and data/ next to its executable, so the whole
# bundle lives in usr/bin. share/ and the menu installer are for plain bundles.
mkdir -p "$appdir/usr/bin"
cp -a "$bundle/." "$appdir/usr/bin/"
rm -rf "$appdir/usr/bin/share" "$appdir/usr/bin/install-desktop-entry.sh"

# AppImage tools (Gear Lever, AppImageLauncher) read the name and icon from the
# desktop file and icon at the AppDir root. The desktop file name must stay the
# app id so GNOME/Wayland map the window to it.
cp "$packaging/$app_id.desktop" "$packaging/$app_id.png" "$appdir/"
ln -s "$app_id.png" "$appdir/.DirIcon"

cat > "$appdir/AppRun" <<'APPRUN'
#!/bin/sh
here=$(dirname "$(readlink -f "$0")")
exec "$here/usr/bin/fox_streak_app" "$@"
APPRUN
chmod +x "$appdir/AppRun"

tool="$work/appimagetool"
curl -fsSL -o "$tool" "https://github.com/AppImage/appimagetool/releases/download/$appimagetool_version/appimagetool-x86_64.AppImage"
echo "$appimagetool_sha256  $tool" | sha256sum -c -
chmod +x "$tool"

# The tool is itself an AppImage; extract-and-run avoids needing FUSE here.
APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$tool" --no-appstream "$appdir" "$output"
chmod +x "$output"
echo "Built $output"
