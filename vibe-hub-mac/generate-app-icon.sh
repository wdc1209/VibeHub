#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SRC_IMAGE="${1:-/Users/nethon/.openclaw/workspace-main/vibe-hub/vibe-hub-mac/VibeHubApp/Assets/vibe-hub-app-icon-source.png}"
ICONSET_DIR="VibeHubApp/Assets/VibeHub.iconset"
OUT_ICNS="VibeHubApp/Assets/VibeHub.icns"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16     "$SRC_IMAGE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     "$SRC_IMAGE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$SRC_IMAGE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     "$SRC_IMAGE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC_IMAGE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SRC_IMAGE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

iconutil --convert icns --output "$OUT_ICNS" "$ICONSET_DIR"

echo "Generated: $OUT_ICNS"
