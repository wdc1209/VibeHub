#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_PATH="${1:-dist/VibeHub.app}"
ZIP_PATH="dist/VibeHub-notarize.zip"

: "${APPLE_SIGNING_IDENTITY:?Missing APPLE_SIGNING_IDENTITY}"
: "${APPLE_TEAM_ID:?Missing APPLE_TEAM_ID}"
: "${APPLE_ID:?Missing APPLE_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Missing APPLE_APP_SPECIFIC_PASSWORD}"

if [ ! -d "$APP_PATH" ]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

codesign --force --deep --options runtime --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$APP_PATH"

rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait

xcrun stapler staple "$APP_PATH"

echo "Notarized and stapled: $APP_PATH"
