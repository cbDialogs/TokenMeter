#!/bin/sh
# Builds TokenMeter.app and packages it as build/TokenMeter.dmg
# with an Applications shortcut for drag-to-install.
# Honors SIGN_IDENTITY (see build-app.sh); the DMG is signed with it too.
set -e
cd "$(dirname "$0")/.."

./scripts/build-app.sh

STAGING=build/dmg
DMG=build/TokenMeter.dmg
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R build/TokenMeter.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname TokenMeter -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

echo "Built $DMG"
