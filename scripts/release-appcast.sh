#!/usr/bin/env bash
# Produces the Sparkle-signed update artifact for a release and prints the
# <item> block to add to appcast.xml.
#
# Usage: scripts/release-appcast.sh
# Requires: dist/Quill.app already built (scripts/build-app.sh)
#
# This is a separate, deliberate step from build-app.sh on purpose —
# build-app.sh is for local dev/test builds, run constantly. Signing an
# update and touching the public appcast is a *release* action, done only
# when a version is actually about to be published, matching how tags/gh
# releases already get created by hand in this project rather than on
# every build.
#
# What this does NOT do: upload anything, edit appcast.xml, or push to
# git. It only builds+signs the .zip and prints the XML fragment — same
# "review before it goes out" discipline already used for GitHub Releases
# (see .github/workflows/release.yml's `draft: true` comment). You paste
# the printed <item> into appcast.xml yourself, review it, then commit +
# push (which is what actually makes it live — SUFeedURL points at
# appcast.xml on the `master` branch).

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Quill"
DIST="dist"
APP="${DIST}/${APP_NAME}.app"
SPARKLE_VERSION="2.9.6"
TOOLS_DIR="${DIST}/.sparkle-tools"
SIGN_UPDATE="${TOOLS_DIR}/bin/sign_update"

if [ ! -d "$APP" ]; then
    echo "error: ${APP} not found — run scripts/build-app.sh first" >&2
    exit 1
fi

VERSION=$(defaults read "$(pwd)/${APP}/Contents/Info" CFBundleShortVersionString)
BUILD=$(defaults read "$(pwd)/${APP}/Contents/Info" CFBundleVersion)
echo "→ Quill ${VERSION} (build ${BUILD})"

if [ ! -x "$SIGN_UPDATE" ]; then
    echo "→ downloading Sparkle CLI tools (v${SPARKLE_VERSION})..."
    mkdir -p "$TOOLS_DIR"
    curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
        -o "${TOOLS_DIR}/sparkle.tar.xz"
    tar -xf "${TOOLS_DIR}/sparkle.tar.xz" -C "$TOOLS_DIR"
fi

ZIP_NAME="${APP_NAME}-${VERSION}.zip"
ZIP_PATH="${DIST}/${ZIP_NAME}"
echo "→ zipping ${APP} → ${ZIP_PATH}..."
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP_PATH"

echo "→ signing with the EdDSA key from this Mac's login keychain..."
# sign_update prints an XML fragment like:
#   sparkle:edSignature="..." length="12345678"
SIGNATURE_ATTRS=$("$SIGN_UPDATE" "$ZIP_PATH")

FILE_SIZE=$(stat -f%z "$ZIP_PATH")
PUB_DATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")
DOWNLOAD_URL="https://github.com/imtamiliniyan/quill/releases/download/v${VERSION}/${ZIP_NAME}"

echo ""
echo "✓ signed: ${ZIP_PATH} (${FILE_SIZE} bytes)"
echo ""
echo "Next steps:"
echo "  1. Upload ${ZIP_PATH} as an asset on the v${VERSION} GitHub Release"
echo "     (same release the .dmg goes on)."
echo "  2. Add this <item> to appcast.xml (newest release first):"
echo ""
cat <<XML
    <item>
        <title>Quill ${VERSION}</title>
        <pubDate>${PUB_DATE}</pubDate>
        <sparkle:version>${BUILD}</sparkle:version>
        <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        <link>https://github.com/imtamiliniyan/quill/releases/tag/v${VERSION}</link>
        <enclosure
            url="${DOWNLOAD_URL}"
            type="application/octet-stream"
            ${SIGNATURE_ATTRS}
        />
    </item>
XML
echo ""
echo "  3. Commit + push appcast.xml — that's what actually makes this"
echo "     version visible to Sparkle's automatic check and to anyone"
echo "     who clicks Check for Updates."
