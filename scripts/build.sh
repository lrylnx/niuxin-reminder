#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source scripts/signing.sh
require_signing_identity
check_existing_signature "$INSTALL_PATH"
check_existing_signature "dist/牛信提醒.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
mkdir -p build dist assets
xcrun swiftc scripts/IconGenerator.swift -o build/icon-generator
build/icon-generator build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
cp build/AppIcon.iconset/icon_512x512@2x.png assets/AppIcon.png
for arch in arm64 x86_64; do
  xcrun swiftc -O -target "$arch-apple-macosx12.0" main.swift EventParser.swift PendingReminders.swift -framework AppKit -o "build/Reminder-$arch"
done
APP="dist/牛信提醒.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create build/Reminder-arm64 build/Reminder-x86_64 -output "$APP/Contents/MacOS/Reminder"
cp Info.plist "$APP/Contents/Info.plist"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign "$SIGNING_IDENTITY" --requirements "=designated => $SIGNING_REQUIREMENT" "$APP"
verify_signature "$APP"
test "$(designated_requirement "$APP")" = "$SIGNING_REQUIREMENT"
# Prove that changing a sealed resource and re-signing preserves the requirement.
PROBE="$(mktemp -d "$ROOT/build/signing-probe.XXXXXX")"
trap 'rm -rf "$PROBE"' EXIT
ditto "$APP" "$PROBE/Reminder.app"
printf 'resource-change continuity check\n' > "$PROBE/Reminder.app/Contents/Resources/SigningContinuity.txt"
codesign --force --sign "$SIGNING_IDENTITY" --requirements "=designated => $SIGNING_REQUIREMENT" "$PROBE/Reminder.app"
verify_signature "$PROBE/Reminder.app"
test "$(designated_requirement "$PROBE/Reminder.app")" = "$(designated_requirement "$APP")"
echo 'PASS: resource change preserves designated requirement'
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/NiuxinReminder-$VERSION-universal.zip"
(cd dist && shasum -a 256 "NiuxinReminder-$VERSION-universal.zip" > SHA256SUMS.txt)
printf 'Built: %s/%s\n' "$ROOT" "$APP"
