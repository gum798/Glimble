#!/bin/bash
#
# Generate Resources/Glimble.icns from the simple icon rendered by make-icon.swift.
# Re-run whenever the icon design changes.
set -euo pipefail

TMP="$(mktemp -d)"
ICONSET="${TMP}/Glimble.iconset"
mkdir -p "${ICONSET}"

swift scripts/make-icon.swift "${TMP}/icon-1024.png"

for s in 16 32 128 256 512; do
    sips -z "$s" "$s"           "${TMP}/icon-1024.png" --out "${ICONSET}/icon_${s}x${s}.png"     >/dev/null
    sips -z "$((s*2))" "$((s*2))" "${TMP}/icon-1024.png" --out "${ICONSET}/icon_${s}x${s}@2x.png" >/dev/null
done

mkdir -p Resources
iconutil -c icns "${ICONSET}" -o Resources/Glimble.icns
rm -rf "${TMP}"
echo "Wrote Resources/Glimble.icns"
