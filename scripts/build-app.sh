#!/usr/bin/env bash
# Builds Quill.app and packages it into a distributable .dmg.
#
# Usage: scripts/build-app.sh
# Output: dist/Quill.app, dist/Quill.dmg
#
# Notes:
# - Signed with a stable local identity (no Apple Developer account
#   involved yet — that's still the eventual Phase 2: real Developer ID +
#   notarization, once enrolled). That's enough for /Applications — unlike
#   /usr/local/bin, it doesn't get killed at launch by AppleSystemPolicy on
#   this macOS version (confirmed empirically).
# - Signing identity defaults to a self-signed local cert ("Quill Local
#   Dev" — create once via Keychain Access > Certificate Assistant >
#   Create a Certificate > Self Signed Root > Code Signing) rather than
#   ad-hoc (`-s -`). Ad-hoc's identity is derived from the binary's own
#   hash, so it changes on every rebuild and macOS treats each reinstall as
#   a brand-new, unrecognized app — re-prompting for both Accessibility
#   *and* Keychain access every time. A stable identity fixes both: after
#   one re-grant on the first build with the new identity, later rebuilds
#   keep the same identity and stop re-prompting. Override via
#   QUILL_SIGN_IDENTITY if your local cert has a different name.

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Quill"
BUNDLE_ID="com.tamiliniyan.quill"
SIGN_IDENTITY="${QUILL_SIGN_IDENTITY:-Quill Local Dev}"
DIST="dist"
APP="${DIST}/${APP_NAME}.app"

echo "→ building release binary..."
swift build -c release

echo "→ re-signing build output (works around swift build's occasionally-invalid auto signature)..."
codesign --force -s "$SIGN_IDENTITY" .build/release/quill

echo "→ assembling ${APP}..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/quill "$APP/Contents/MacOS/quill"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "→ signing ${APP}..."
codesign --force --deep -s "$SIGN_IDENTITY" "$APP"

echo "→ verifying..."
codesign -dv "$APP" 2>&1 | head -5
"$APP/Contents/MacOS/quill" doctor || true

echo "→ building .dmg..."
DMG_STAGING=$(mktemp -d)
trap 'rm -rf "$DMG_STAGING"' EXIT
cp -R "$APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
mkdir -p "$DMG_STAGING/.background"
cp Resources/dmg_background.png "$DMG_STAGING/.background/background.png"

rm -f "${DIST}/${APP_NAME}.dmg"
RW_DMG=$(mktemp -u).dmg
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDRW -fs HFS+ "$RW_DMG"

MOUNT_DIR="/Volumes/${APP_NAME}"
# No custom -mountpoint: Finder shows a volume by its actual label only
# when it's mounted at the default /Volumes/<name> location — pass a
# custom mountpoint and Finder's `disk` list shows the mountpoint folder's
# name instead, which breaks `tell disk "Quill"` below. Confirmed
# empirically (Finder listed a random tmp.XXXX name instead of "Quill").
if [ -d "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" -force -quiet || true
fi
hdiutil attach "$RW_DMG" -quiet
sleep 2

# Lay out the Finder window: background image, icon size, and the two icon
# positions that line up with the arrow drawn into the background — same
# "drag app to Applications" convention most macOS installers use.
osascript <<OSA
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        -- NOTE: this alias reliably sets the background picture on THIS
        -- (writable) mount, but the reference doesn't survive
        -- `hdiutil convert` to the final compressed .dmg — icon positions
        -- do survive (plain stored coordinates), but Finder shows a plain
        -- background once distributed. Known finicky Finder/hdiutil
        -- scripting quirk; not worth more engineering time against right
        -- now. Positioned, correctly-labeled icons still ship either way.
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" of container window to {170, 220}
        set position of item "Applications" of container window to {490, 220}
        update without registering applications
        delay 2
        close
    end tell
end tell
OSA

# Give Finder time to actually flush .DS_Store (the background-picture
# alias in particular needs a moment to resolve and write, and detaching
# too soon captures icon positions but silently drops the background).
sleep 2
sync
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$RW_DMG" -format UDZO -o "${DIST}/${APP_NAME}.dmg"
rm -f "$RW_DMG"

echo "✓ built:"
echo "  ${APP}"
echo "  ${DIST}/${APP_NAME}.dmg"
