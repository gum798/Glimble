#!/bin/bash
#
# Assemble the GlimbleApp SwiftPM executable into a signed .app bundle.
#
# Usage:
#   GLIMBLE_IDENTITY="Developer ID Application: NAME (TEAMID)" ./scripts/build-app.sh
#   GLIMBLE_IDENTITY="-" ./scripts/build-app.sh        # ad-hoc local dry-run (no notarization)
#
# The OpenMultitouchSupport dependency ships as a prebuilt dynamic XCFramework that the
# executable links via @rpath, so we must embed it under Contents/Frameworks, add the
# loader path, and RE-SIGN it with our identity (it arrives signed by the upstream author).
set -euo pipefail

IDENTITY="${GLIMBLE_IDENTITY:?Set GLIMBLE_IDENTITY to your 'Developer ID Application: NAME (TEAMID)' string (or '-' for an ad-hoc local test)}"
CONFIG=release
APP="Glimble.app"
BUILD_DIR=".build/${CONFIG}"
BIN="${BUILD_DIR}/GlimbleApp"
FRAMEWORK="OpenMultitouchSupportXCF.framework"

# Production signing wants a secure timestamp; ad-hoc ('-') cannot get one.
TIMESTAMP="--timestamp"
if [ "${IDENTITY}" = "-" ]; then
    TIMESTAMP=""
    echo "NOTE: ad-hoc signing — structural dry-run only, NOT notarizable."
fi

swift build -c "${CONFIG}" --product GlimbleApp

# --- assemble bundle ---
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Frameworks" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/GlimbleApp"
cp Sources/GlimbleApp/Info.plist "${APP}/Contents/Info.plist"
cp Resources/Glimble.icns "${APP}/Contents/Resources/Glimble.icns"

# Embed the dynamic framework and drop dev-only headers/modules from the shipped copy.
cp -R "${BUILD_DIR}/${FRAMEWORK}" "${APP}/Contents/Frameworks/${FRAMEWORK}"
rm -rf "${APP}/Contents/Frameworks/${FRAMEWORK}/Versions/A/Headers" \
       "${APP}/Contents/Frameworks/${FRAMEWORK}/Versions/A/Modules" \
       "${APP}/Contents/Frameworks/${FRAMEWORK}/Headers" \
       "${APP}/Contents/Frameworks/${FRAMEWORK}/Modules"

# Point the executable at the bundled Frameworks dir (SwiftPM doesn't add this rpath).
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP}/Contents/MacOS/GlimbleApp"

# --- sign inside-out: framework FIRST, app LAST, never --deep ---
codesign --force --options runtime ${TIMESTAMP} \
    --sign "${IDENTITY}" \
    "${APP}/Contents/Frameworks/${FRAMEWORK}"

codesign --force --options runtime ${TIMESTAMP} \
    --entitlements Glimble.entitlements \
    --sign "${IDENTITY}" \
    "${APP}"

codesign --verify --strict --verbose=2 "${APP}"
echo "Signed ${APP}"
