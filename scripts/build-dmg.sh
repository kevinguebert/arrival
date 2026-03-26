#!/bin/bash
set -euo pipefail

# Build a DMG for Arrival
# Usage: ./scripts/build-dmg.sh [path-to-app-bundle]

APP_PATH="${1:-build/Build/Products/Release/Arrival.app}"
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
DMG_NAME="Arrival-${VERSION}.dmg"
OUTPUT_DIR="dist"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: App bundle not found at $APP_PATH"
  echo "Build the app first: xcodebuild -project Arrival.xcodeproj -scheme Arrival -configuration Release build"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Remove existing DMG if present
rm -f "$OUTPUT_DIR/$DMG_NAME"

create-dmg \
  --volname "Arrival" \
  --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Arrival.app" 175 190 \
  --app-drop-link 425 190 \
  --hide-extension "Arrival.app" \
  --no-internet-enable \
  "$OUTPUT_DIR/$DMG_NAME" \
  "$APP_PATH"

echo ""
echo "DMG created: $OUTPUT_DIR/$DMG_NAME"
echo "Size: $(du -h "$OUTPUT_DIR/$DMG_NAME" | cut -f1)"
