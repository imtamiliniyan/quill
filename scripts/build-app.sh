#!/usr/bin/env bash
# Builds Quill.app and packages it into a distributable .dmg.
#
# Usage: scripts/build-app.sh
# Output: dist/Quill.app, dist/Quill OSS <version>.dmg
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

# mlx-swift's Metal GPU shaders (mlx.metallib) — `swift build` alone can't
# produce this. mlx-swift's own README says as much ("SwiftPM (command
# line) cannot build the Metal shaders"): the 39 .metal kernels need
# `xcrun metal`/`metallib`, which only ships as part of Xcode's separately
# -downloaded Metal Toolchain component, not the base SwiftPM toolchain.
# Without it, Local AI's on-device rewrite throws "Failed to load the
# default metallib" the moment a model tries to run — confirmed via a real
# crash-free-but-still-broken run on this M5 Mac before this step existed.
#
# Built once via mlx-swift's own CMake+Ninja path (the officially
# documented non-Xcode-project route — reuses its real `mlx_build_metallib`
# macro rather than hand-rolling per-file `xcrun metal` calls, which would
# have to reimplement the JIT kernel-source preprocessing step it also
# does), then cached outside .build/ (a fresh checkout wipes that) keyed by
# the exact mlx-swift commit so a dependency bump rebuilds it automatically
# instead of silently shipping stale shaders.
MLX_SWIFT_DIR=".build/checkouts/mlx-swift"
MLX_CMAKE_DIR="${MLX_SWIFT_DIR}/Source/Cmlx/mlx"
MLX_COMMIT=$(git -C "$MLX_CMAKE_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
METALLIB_CACHE=".metallib-cache/${MLX_COMMIT}/mlx.metallib"
# CMake's own build dir must NOT live inside Source/Cmlx/mlx: that whole
# tree is `Cmlx`'s SwiftPM source path, and CMake vendors doctest (with
# its own example main.cpp files) into whatever build dir it's given —
# SwiftPM's target-type auto-detection sees those and misidentifies Cmlx
# as an executable target, breaking every other target's `import Cmlx`.
# Confirmed the hard way: built once with the build dir nested inside, and
# `swift build -c release` broke on the very next run. /tmp is well
# outside anything SwiftPM scans.
MLX_CMAKE_BUILD_DIR="/tmp/quill-mlx-metallib-build"

if [ ! -f "$METALLIB_CACHE" ]; then
    echo "→ building mlx.metallib (mlx-swift @ ${MLX_COMMIT:0:12}, not cached)..."
    if ! xcrun -sdk macosx -f metal >/dev/null 2>&1; then
        echo "Metal compiler not found — run: xcodebuild -downloadComponent MetalToolchain" >&2
        exit 1
    fi
    if ! command -v cmake >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
        echo "cmake/ninja not found — run: brew install cmake ninja" >&2
        exit 1
    fi
    cmake -S "$MLX_CMAKE_DIR" -B "$MLX_CMAKE_BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
    ninja -C "$MLX_CMAKE_BUILD_DIR" mlx-metallib
    mkdir -p "$(dirname "$METALLIB_CACHE")"
    cp "${MLX_CMAKE_BUILD_DIR}/mlx/backend/metal/kernels/mlx.metallib" "$METALLIB_CACHE"
else
    echo "→ reusing cached mlx.metallib (mlx-swift @ ${MLX_COMMIT:0:12})..."
fi

# Sparkle ships as a framework (SPM binary target), not a plain dylib —
# the executable needs a real rpath to find it inside the app bundle.
# SPM's own default rpaths (`@loader_path`, the Swift toolchain dirs — see
# `otool -l`) don't include the standard app-bundle convention, so without
# this the app would build and sign fine but crash on launch with
# "Library not loaded: @rpath/Sparkle.framework/...". Added before the
# first codesign below since install_name_tool invalidates any existing
# signature.
echo "→ adding Frameworks rpath for Sparkle..."
install_name_tool -add_rpath "@executable_path/../Frameworks" .build/release/quill

echo "→ re-signing build output (works around swift build's occasionally-invalid auto signature)..."
codesign --force -s "$SIGN_IDENTITY" .build/release/quill

echo "→ assembling ${APP}..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/quill "$APP/Contents/MacOS/quill"
# MLX looks for "mlx.metallib" colocated with the running binary first
# (confirmed via mlx-swift's own device.cpp) — Contents/MacOS is exactly
# that directory for the packaged app.
cp "$METALLIB_CACHE" "$APP/Contents/MacOS/mlx.metallib"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sparkle.framework itself — the rpath above only tells the executable
# where to look, it still needs the actual framework physically present
# in the bundle. `.build/release` is a symlink to the current arch's
# build dir (e.g. arm64-apple-macosx/release), where SPM already copies
# the framework as part of its own build (`swift build`'s "Copying
# Sparkle.framework" step).
cp -R .build/release/Sparkle.framework "$APP/Contents/Frameworks/Sparkle.framework"

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

# Distributed filename is "Quill OSS <version>.dmg" — the mounted volume
# label stays plain "Quill" (that's what shows in the Finder sidebar/DMG
# window, unrelated to the downloaded filename).
VERSION=$(defaults read "$(pwd)/Resources/Info.plist" CFBundleShortVersionString)
DMG_NAME="${APP_NAME} OSS ${VERSION}.dmg"

rm -f "${DIST}/${DMG_NAME}"
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
    "${APP_NAME}" "${DIST}/${DMG_NAME}"

echo "✓ built:"
echo "  ${APP}"
echo "  ${DIST}/${DMG_NAME}"
