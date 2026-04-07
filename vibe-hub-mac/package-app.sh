#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP="dist/VibeHub.app"
BIN=".build/debug/VibeHub"
APP_BIN="$APP/Contents/MacOS/VibeHub"
RES_DIR="$APP/Contents/Resources"
INFO_PLIST="$APP/Contents/Info.plist"
ICON_ICNS="VibeHubApp/Assets/VibeHub.icns"

swift build

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RES_DIR"
cp "$BIN" "$APP_BIN"
if [ -d "VibeHubApp/Assets" ]; then
  cp -R VibeHubApp/Assets/. "$RES_DIR/"
fi
if [ -f "$ICON_ICNS" ]; then
  cp "$ICON_ICNS" "$RES_DIR/VibeHub.icns"
fi

cat > "$INFO_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>VibeHub</string>
  <key>CFBundleIdentifier</key>
  <string>ai.openclaw.VibeHub</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>VibeHub</string>
  <key>CFBundleName</key>
  <string>Vibe Hub</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Vibe Hub uses the microphone for press-to-talk raw input.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>Vibe Hub converts held voice input into raw draft text.</string>
</dict>
</plist>
EOF

# Normalize bundle permissions so LaunchServices can spawn it cleanly.
chmod 755 "$APP" "$APP/Contents" "$APP/Contents/MacOS" "$RES_DIR"
chmod 755 "$APP_BIN"
if [ -f "$APP/Contents/Info.plist" ]; then
  chmod 644 "$APP/Contents/Info.plist"
fi
find "$RES_DIR" -type f -exec chmod 644 {} \;

# Re-sign the bundle after copying the latest executable.
codesign --force --deep --sign - "$APP"

echo "Packaged: $APP"
