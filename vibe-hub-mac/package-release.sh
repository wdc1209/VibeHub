#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${1:-1.0.0}"
APP_NAME="VibeHub.app"
APP_PATH="dist/${APP_NAME}"
ZIP_NAME="VibeHub-macOS-${VERSION}.zip"
ZIP_PATH="dist/${ZIP_NAME}"

./package-app.sh

rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Release bundle: $ZIP_PATH"
