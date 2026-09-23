#!/bin/bash
# Quits the running app, rebuilds it, clears the now-stale Accessibility grant
# (ad-hoc signed builds lose it on every rebuild), and relaunches it.
#
# Usage: ./rebuild-and-run.sh

set -euo pipefail
cd "$(dirname "$0")"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" Resources/Info.plist)

pkill -x MacRemapper || true
./build-app.sh
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null
open build/MacRemapper.app

echo "Relaunched. Grant Accessibility access again when the app asks."
