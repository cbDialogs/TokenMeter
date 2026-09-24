#!/bin/sh
# Builds a release binary and wraps it in build/TokenMeter.app.
set -e
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TokenMeter"

APP=build/TokenMeter.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/TokenMeter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP"
