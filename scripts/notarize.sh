#!/bin/bash
#
# Notarize and staple the signed Glimble Spike.app. Requires a real Developer ID
# signature (run build-app.sh with a real GLIMBLE_IDENTITY first) and a stored
# notarytool credential profile:
#
#   xcrun notarytool store-credentials glimble-notary \
#       --apple-id <id> --team-id <TEAMID> --password <app-specific-password>
#   # or --key/--key-id/--issuer for an App Store Connect API key (preferred)
#
# Usage:  ./scripts/notarize.sh
set -euo pipefail

APP="Glimble Spike.app"
ZIP="GlimbleSpike.zip"
PROFILE="${GLIMBLE_NOTARY_PROFILE:-glimble-notary}"

ditto -c -k --keepParent "${APP}" "${ZIP}"

xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait

xcrun stapler staple "${APP}"
xcrun stapler validate "${APP}"
spctl -a -t exec -vv "${APP}"
