#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build dist assets
xcrun swiftc scripts/IconGenerator.swift -o build/icon-generator
build/icon-generator build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
cp build/AppIcon.iconset/icon_512x512@2x.png assets/AppIcon.png
for arch in arm64 x86_64; do
  xcrun swiftc -O -target "$arch-apple-macosx12.0" main.swift EventParser.swift -framework AppKit -o "build/Reminder-$arch"
done
APP="dist/牛信提醒.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create build/Reminder-arm64 build/Reminder-x86_64 -output "$APP/Contents/MacOS/Reminder"
cp Info.plist "$APP/Contents/Info.plist"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/NiuxinReminder-1.0.0-universal.zip
(cd dist && shasum -a 256 NiuxinReminder-1.0.0-universal.zip > SHA256SUMS.txt)
printf 'Built: %s/%s\n' "$ROOT" "$APP"
