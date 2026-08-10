#!/usr/bin/env bash
# Builds Quill.app and packages it into a distributable .dmg.
#
# Usage: scripts/build-app.sh
# Output: dist/Quill.app, dist/Quill.dmg
#
# Notes:
# - Ad-hoc signed (no Apple Developer account involved). That's enough for
#   /Applications — unlike /usr/local/bin, it doesn't get killed at launch
#   by AppleSystemPolicy on this macOS version (confirmed empirically).
# - Each rebuild changes the ad-hoc signature, so macOS will ask for a
#   fresh Accessibility grant after every reinstall. That's expected.

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Quill"
BUNDLE_ID="com.tamiliniyan.quill"
DIST="dist"
APP="${DIST}/${APP_NAME}.app"

echo "→ building release binary..."
swift build -c release

echo "→ re-signing build output (works around swift build's occasionally-invalid auto signature)..."
codesign --force -s - .build/release/quill

echo "→ assembling ${APP}..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/quill "$APP/Contents/MacOS/quill"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "→ signing ${APP}..."
codesign --force --deep -s - "$APP"

echo "→ verifying..."
codesign -dv "$APP" 2>&1 | head -5
"$APP/Contents/MacOS/quill" doctor || true

echo "→ building .dmg..."
DMG_STAGING=$(mktemp -d)
trap 'rm -rf "$DMG_STAGING"' EXIT
cp -R "$APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

rm -f "${DIST}/${APP_NAME}.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "${DIST}/${APP_NAME}.dmg"

echo "✓ built:"
echo "  ${APP}"
echo "  ${DIST}/${APP_NAME}.dmg"
