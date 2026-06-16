#!/bin/bash
#
# Build, ad-hoc sign, and package Glimble.app into a distributable .dmg.
#
# Usage:
#   GLIMBLE_IDENTITY="-" ./scripts/release.sh            # ad-hoc (no Apple account)
#   GLIMBLE_IDENTITY="Developer ID Application: …" ./scripts/release.sh   # if you later notarize
#
# The version is read from Sources/GlimbleApp/Info.plist (CFBundleShortVersionString).
# Prints the DMG's sha256 at the end — paste it into homebrew/glimble.rb for the release.
set -euo pipefail

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Sources/GlimbleApp/Info.plist)"
APP="Glimble.app"
DMG="Glimble-${VERSION}.dmg"
STAGING="$(mktemp -d)"

# Build + ad-hoc (or Developer ID) sign the app bundle.
GLIMBLE_IDENTITY="${GLIMBLE_IDENTITY:--}" ./scripts/build-app.sh

# Stage the app next to an /Applications symlink so the DMG offers drag-to-install.
rm -f "${DMG}"
cp -R "${APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

hdiutil create -volname "Glimble ${VERSION}" -srcfolder "${STAGING}" \
    -ov -format UDZO "${DMG}"
rm -rf "${STAGING}"

echo ""
echo "Created ${DMG}"
echo "sha256 (for homebrew/glimble.rb):"
shasum -a 256 "${DMG}" | awk '{print $1}'
