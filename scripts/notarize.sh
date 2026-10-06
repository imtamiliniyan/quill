#!/bin/bash
# Notarize and staple a Developer ID signed Quill.app or .dmg.
#
#   scripts/build-app.sh                  # signs dist/Quill.app with Developer ID
#   scripts/notarize.sh dist/Quill.app    # Apple scans it, ticket is stapled on
#   (then build the DMG from the stapled app, and run this on the DMG too)
#
# Needs the keychain profile made once with:
#   xcrun notarytool store-credentials kiiwi-notary --apple-id <id> --team-id <team>
# (the profile is per Apple account, so Kiiwi and Quill share it).
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:?usage: scripts/notarize.sh dist/Quill.app|dist/<name>.dmg}"
PROFILE="${QUILL_NOTARY_PROFILE:-kiiwi-notary}"
[ -e "$TARGET" ] || { echo "not found: $TARGET" >&2; exit 1; }

UPLOAD="$TARGET"
if [ -d "$TARGET" ]; then
  UPLOAD=$(mktemp -d)/Quill-notarize.zip
  ditto -c -k --keepParent "$TARGET" "$UPLOAD"
fi

echo "→ submitting $TARGET to Apple" >&2
LOG=$(mktemp)
xcrun notarytool submit "$UPLOAD" --keychain-profile "$PROFILE" --wait | tee "$LOG"
if ! grep -q "status: Accepted" "$LOG"; then
  ID=$(awk '/^  id:/ {print $2; exit}' "$LOG")
  echo "not accepted. Reasons:" >&2
  xcrun notarytool log "$ID" --keychain-profile "$PROFILE" >&2 || true
  exit 1
fi
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"
echo "✓ $TARGET notarized and stapled"
