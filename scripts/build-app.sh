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

# Enhancement Engine's provider logos, as loose files under
# Contents/Resources/ — loaded via Bundle.main at runtime
# (ProviderLogos.swift), not SPM's generated Bundle.module/resource-bundle
# mechanism. Tried that first: SPM's generated accessor expects
# `quill_quill.bundle` sitting as a sibling of Contents/ (confirmed by
# reading the generated accessor directly), which `codesign --deep`
# rejects outright ("unsealed contents present in the bundle root",
# non-zero exit, whole script aborts under `set -e`). Contents/Resources/
# is where signed content is already expected to live — AppIcon.icns
# above proves that path works — so that's what ProviderLogos.swift
# actually reads from in the shipped app; the Package.swift `resources:`
# declaration stays only for a bare `swift run`, a path this script
# doesn't use.
cp -R Sources/quill/Resources/ProviderLogos "$APP/Contents/Resources/ProviderLogos"

echo "→ signing ${APP}..."
codesign --force --deep -s "$SIGN_IDENTITY" "$APP"

echo "→ verifying..."
# `|| true` on the whole pipeline: codesign can still be writing when `head`
# closes its end after 5 lines, which sends codesign SIGPIPE (exit 141).
# Under `set -euo pipefail` that silently aborted the entire script right
# here — before the .dmg packaging below ever ran — timing-dependent, so it
# passed some runs and not others. Confirmed via exit code 141 after dist/Quill.dmg
# was found still dated from a much older build despite dist/Quill.app rebuilding fine.
(codesign -dv "$APP" 2>&1 | head -5) || true
"$APP/Contents/MacOS/quill" doctor || true

echo "→ building .dmg..."
# Built with dmgbuild (pip3 install dmgbuild), not a live Finder/AppleScript
# session + `hdiutil convert`. That was the original approach here, and it
# had a real, confirmed bug: Finder's "background picture" is backed by a
# classic Alias Manager record tied to the writable image's own volume
# identity, which `hdiutil convert` doesn't preserve — so the background
# silently failed to render on the distributed .dmg while every file
# (including .DS_Store and the background image itself) was still sitting
# right there on disk, correctly copied. Icon *positions* survived because
# they're plain stored coordinates, not aliases — which is exactly why
# that bug looked like "half-working" instead of "broken." dmgbuild writes
# the .DS_Store's background/position records directly into the image it
# builds, sidestepping that resolution step entirely. Settings for window
# size, icon size/positions, and background live in scripts/dmg_settings.py.
if ! python3 -c "import dmgbuild" 2>/dev/null; then
    echo "dmgbuild not installed — run: pip3 install dmgbuild" >&2
    exit 1
fi

rm -f "${DIST}/${APP_NAME}.dmg"
# No custom -mountpoint: Finder shows a volume by its actual label only
# when it's mounted at the default /Volumes/<name> location. A leftover
# manual mount (e.g. from testing this background by hand) would collide
# with dmgbuild's own internal mount, so clear it first.
if [ -d "/Volumes/${APP_NAME}" ]; then
    hdiutil detach "/Volumes/${APP_NAME}" -force -quiet || true
fi

python3 -m dmgbuild \
    -s scripts/dmg_settings.py \
    -D app="$(pwd)/${APP}" \
    -D background="$(pwd)/Resources/dmg_background.png" \
    "${APP_NAME}" "${DIST}/${APP_NAME}.dmg"

echo "✓ built:"
echo "  ${APP}"
echo "  ${DIST}/${APP_NAME}.dmg"
