#!/usr/bin/env bash
# quill installer.
#   curl -fsSL https://imtamiliniyan.github.io/quill/install.sh | sh
#
# Fetches the latest arm64 macOS binary from GitHub Releases, drops it in
# ~/bin, and strips the quarantine xattr so Gatekeeper doesn't block the
# unsigned binary.
#
# Deliberately NOT /usr/local/bin: on current macOS, ad-hoc-signed binaries
# placed there get killed at launch by AppleSystemPolicy ("load code
# signature error 2") even with a valid signature — /usr/local/bin gets
# extra scrutiny as a shared system PATH location. The identical binary
# runs fine from any user-owned directory. Confirmed empirically.
#
# Apple Silicon only — WhisperKit uses the Apple Neural Engine via CoreML,
# which only ships on M-series chips.

set -euo pipefail

REPO="imtamiliniyan/quill"
BIN_NAME="quill"
INSTALL_DIR="$HOME/bin"
ASSET="quill-macos-arm64.tar.gz"

red()    { printf "\033[31m%s\033[0m\n" "$*" >&2; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
dim()    { printf "\033[2m%s\033[0m\n" "$*"; }

# 1. sanity
if [ "$(uname -s)" != "Darwin" ]; then
    red "quill is macOS-only (detected $(uname -s))"
    exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    red "quill requires Apple Silicon (detected $ARCH)"
    red "the on-device inference engine uses the Apple Neural Engine, which Intel Macs don't have."
    exit 1
fi

for cmd in curl tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        red "missing dependency: $cmd"
        exit 1
    fi
done

# 2. resolve latest release
dim "→ resolving latest release..."
TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep -E '"tag_name"' \
    | head -1 \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')

if [ -z "${TAG:-}" ]; then
    red "couldn't determine latest release tag"
    exit 1
fi
dim "  ${TAG}"

URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

# 3. download + extract
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

dim "→ downloading ${ASSET}..."
curl -fsSL "$URL" -o "$TMP/${ASSET}"

dim "→ extracting..."
tar -xzf "$TMP/${ASSET}" -C "$TMP"

if [ ! -f "$TMP/${BIN_NAME}" ]; then
    red "archive did not contain ${BIN_NAME}"
    exit 1
fi

chmod +x "$TMP/${BIN_NAME}"

# 4. strip quarantine so Gatekeeper lets the unsigned binary run
xattr -d com.apple.quarantine "$TMP/${BIN_NAME}" 2>/dev/null || true

# 5. install — user-owned directory, no sudo needed
mkdir -p "$INSTALL_DIR"
mv "$TMP/${BIN_NAME}" "${INSTALL_DIR}/${BIN_NAME}"
chmod +x "${INSTALL_DIR}/${BIN_NAME}"

green "✓ quill ${TAG} installed at ${INSTALL_DIR}/${BIN_NAME}"

# 6. PATH check
case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
        echo
        red "${INSTALL_DIR} isn't on your PATH yet. Add this to ~/.zshrc:"
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
        ;;
esac

echo
echo "next:"
echo "  quill setup                       # grant mic + accessibility"
echo "  quill install --launch-at-login   # (optional) start at login"
echo "  quill                             # run the daemon"
