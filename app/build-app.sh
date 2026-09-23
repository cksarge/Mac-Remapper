#!/bin/bash
# Builds MacRemapper.app from the Swift Package, using only the Xcode Command
# Line Tools (no full Xcode / .xcodeproj required). Produces a signed app
# bundle under app/build/.
#
# Usage: ./build-app.sh [debug|release]
#
# By default, signs ad-hoc (fine for local testing on your own Mac only).
# For a real release build, set SIGN_IDENTITY to your Developer ID Application
# certificate's name (as it appears in Keychain Access / `security find-identity
# -v -p codesigning`), and pass "release":
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build-app.sh release

set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-debug}"
APP_NAME="MacRemapper"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Release builds are universal (Apple Silicon + Intel); debug builds stay native for speed.
ARCH_FLAGS=()
if [ "$CONFIG" = "release" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "Building Swift package ($CONFIG)…"
swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --product "$APP_NAME"

BIN_PATH=$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)

echo "Assembling ${APP_BUNDLE}…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Ad-hoc signing (set SIGN_IDENTITY for a real release build)…"
    codesign --force --deep --sign - "$APP_BUNDLE"
else
    echo "Signing with identity: ${SIGN_IDENTITY}…"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
fi

echo "Done: $APP_BUNDLE"
echo "Run it with: open \"$APP_BUNDLE\""
