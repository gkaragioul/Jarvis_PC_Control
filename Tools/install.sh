#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="JarvisPCControl.app"
SYSTEM_APP="/Applications/${APP_NAME}"
USER_APP="${HOME}/Applications/${APP_NAME}"
DESKTOP_ALIAS="${HOME}/Desktop/Jarvis PC Control"
LAUNCH_AGENT="${HOME}/Library/LaunchAgents/local.jarvis.pccontrol.plist"

cd "$PROJECT_DIR"

swift build
if [[ -f Resources/JarvisLogo.png ]]; then
  swift Tools/make_icon_from_image.swift Resources/JarvisLogo.png Resources/AppIcon.iconset 0 0 2114 2016 0.68
else
  swift Tools/make_icon.swift Resources/AppIcon.iconset
fi
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
mkdir -p "${APP_NAME}/Contents/Resources"
cp Resources/AppIcon.icns "${APP_NAME}/Contents/Resources/AppIcon.icns"
cp ".build/debug/JarvisPCControl" "${APP_NAME}/Contents/MacOS/JarvisPCControl"

mkdir -p "${HOME}/.local/bin"
install -m 755 Tools/jarvis-pc-wake "${HOME}/.local/bin/jarvis-pc-wake"

rm -rf "$SYSTEM_APP"
ditto "$APP_NAME" "$SYSTEM_APP"
touch "$SYSTEM_APP" "$SYSTEM_APP/Contents" "$SYSTEM_APP/Contents/Info.plist" "$SYSTEM_APP/Contents/Resources/AppIcon.icns"

# Remove the old user-local copy so Finder, Dock, and login items do not drift.
rm -rf "$USER_APP"

cat > "$LAUNCH_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>local.jarvis.pccontrol</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>${SYSTEM_APP}</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
PLIST

osascript <<OSA
tell application "Finder"
  set appPath to POSIX file "$SYSTEM_APP" as alias
  set desktopFolder to path to desktop folder
  if exists item "Jarvis PC Control" of desktopFolder then
    delete item "Jarvis PC Control" of desktopFolder
  end if
  make new alias file at desktopFolder to appPath with properties {name:"Jarvis PC Control"}
end tell
OSA

killall Dock 2>/dev/null || true
sleep 1
python3 <<'PY'
import os
import plistlib
import subprocess

dock_plist = os.path.expanduser("~/Library/Preferences/com.apple.dock.plist")
app_url = "file:///Applications/JarvisPCControl.app/"
old_urls = {
    "file:///Users/georgekarangioules/Applications/JarvisPCControl.app/",
    app_url,
}

with open(dock_plist, "rb") as handle:
    dock = plistlib.load(handle)

apps = dock.get("persistent-apps", [])
filtered = []
for item in apps:
    url = item.get("tile-data", {}).get("file-data", {}).get("_CFURLString")
    label = item.get("tile-data", {}).get("file-label")
    if url in old_urls or label in {"JarvisPCControl", "Jarvis PC Control"}:
        continue
    filtered.append(item)

filtered.append({
    "tile-data": {
        "file-data": {
            "_CFURLString": app_url,
            "_CFURLStringType": 15,
        },
        "file-label": "Jarvis PC Control",
        "file-type": 41,
    },
    "tile-type": "file-tile",
})

dock["persistent-apps"] = filtered
with open(dock_plist, "wb") as handle:
    plistlib.dump(dock, handle)

subprocess.run(["killall", "Dock"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
PY

qlmanage -r cache >/dev/null 2>&1 || true

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"

pkill -f '/JarvisPCControl.app/Contents/MacOS/JarvisPCControl' 2>/dev/null || true
open "$SYSTEM_APP"

echo "Installed $SYSTEM_APP"
