#!/bin/bash
# Shared by build/install verification. Never create or export a private key.
SIGNING_IDENTITY="1DDCB3B175991894FC207A24F0B13D5C41F502B6"
BUNDLE_ID="io.github.lrylnx.niuxin-reminder"
INSTALL_PATH="/Applications/牛信提醒.app"
SIGNING_REQUIREMENT="identifier \"$BUNDLE_ID\" and certificate leaf = H\"1ddcb3b175991894fc207a24f0b13d5c41f502b6\""

require_signing_identity() {
  if ! security find-identity -v -p codesigning | grep -F "$SIGNING_IDENTITY" >/dev/null; then
    echo '固定签名身份 TutorialQuickSend Local Signing 缺失，请恢复原身份后重新构建。' >&2
    return 1
  fi
}

verify_signature() {
  local app="$1"
  test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = "$BUNDLE_ID"
  codesign --verify --deep --strict --all-architectures -R "=$SIGNING_REQUIREMENT" "$app"
}

designated_requirement() {
  codesign -d -r- "$1" 2>&1 | sed -n 's/^designated => //p'
}

check_existing_signature() {
  local app="$1"
  [ -d "$app" ] || return 0
  test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = "$BUNDLE_ID"
  if codesign -dv "$app" 2>&1 | grep '^Signature=adhoc$' >/dev/null; then
    echo "一次性迁移旧临时签名：$app"
  else
    verify_signature "$app"
    test "$(designated_requirement "$app")" = "$SIGNING_REQUIREMENT"
  fi
}
