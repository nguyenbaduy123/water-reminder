#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! AppIcon.icns -nt icon.swift ]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    swift icon.swift "$ICONSET"
    iconutil -c icns "$ICONSET" -o AppIcon.icns
fi

APP="$HOME/Applications/WaterReminder.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O main.swift -o "$APP/Contents/MacOS/WaterReminder"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
# Finder and Notification Center cache app icons by bundle, so tell Launch Services the bundle changed.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

pkill -x WaterReminder || true
while pgrep -x WaterReminder >/dev/null; do sleep 0.2; done
# LaunchServices occasionally rejects the first open right after the bundle is replaced (error -600); a retry succeeds.
for attempt in 1 2 3; do
    open "$APP" && break
    sleep 1
done
echo "Installed: $APP"
