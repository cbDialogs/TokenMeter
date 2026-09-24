#!/bin/sh
# Builds a Developer ID-signed DMG, notarizes it with Apple, and staples the ticket.
#
# Requires a notarytool keychain profile, created once with:
#   xcrun notarytool store-credentials <profile> --apple-id <id> --team-id <team>
#
# Environment:
#   SIGN_IDENTITY   Developer ID Application identity (default: Dialogs Apps, Inc.)
#   NOTARY_PROFILE  notarytool keychain profile name (default: homesick-notary)
set -e
cd "$(dirname "$0")/.."

export SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Dialogs Apps, Inc. (54MH33556M)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-homesick-notary}"
DMG=build/TokenMeter.dmg

./scripts/make-dmg.sh

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

spctl --assess --type open --context context:primary-signature --verbose "$DMG"
echo "Notarized $DMG"
