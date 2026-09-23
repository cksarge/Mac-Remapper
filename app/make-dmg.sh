#!/bin/bash
# Packages build/MacRemapper.app (produced by build-app.sh) into a
# distributable, drag-to-Applications .dmg at build/MacRemapper.dmg.
# Run this AFTER build-app.sh, and after codesigning/notarizing the .app
# for a real release (see README.md's "Path to 1.0.0").
#
# Usage: ./make-dmg.sh

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MacRemapper"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: $APP_BUNDLE not found — run ./build-app.sh first" >&2
    exit 1
fi

echo "Staging DMG contents…"
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating ${DMG_PATH}…"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "Done: $DMG_PATH"
