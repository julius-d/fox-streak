#!/bin/sh
# Adds this Fox Streak bundle to the desktop's app menu (issue #129): installs
# the .desktop entry, pointed at this bundle's binary, and the fox icon into
# the per-user XDG data folder. Run it from the built bundle:
#   build/linux/x64/release/bundle/install-desktop-entry.sh
set -eu

app_id=io.github.juliusd.foxstreak
bundle_dir=$(cd "$(dirname "$0")" && pwd)
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
icon_dir="$data_home/icons/hicolor/256x256/apps"

mkdir -p "$data_home/applications" "$icon_dir"
cp "$bundle_dir/share/icons/hicolor/256x256/apps/$app_id.png" "$icon_dir/"
awk -v exec_line="Exec=\"$bundle_dir/fox_streak_app\"" \
  '/^Exec=/ { print exec_line; next } { print }' \
  "$bundle_dir/share/applications/$app_id.desktop" \
  > "$data_home/applications/$app_id.desktop"
# Refresh the menu/icon caches where the tools exist; desktops also pick the
# entry up on their own.
update-desktop-database "$data_home/applications" 2>/dev/null || true
gtk-update-icon-cache -q -t "$data_home/icons/hicolor" 2>/dev/null || true

echo "Fox Streak is now in your app menu."
