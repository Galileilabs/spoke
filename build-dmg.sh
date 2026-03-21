#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Usage: ./build-dmg.sh
#
# Required environment variables (or pass as args):
#   APPLE_ID        – your Apple ID email
#   TEAM_ID         – your 10-character Developer Team ID
#   APP_PASSWORD    – app-specific password from appleid.apple.com
#
# One-time setup:
#   1. In Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application
#   2. Create an app-specific password at appleid.apple.com → Sign-In and Security
# ---------------------------------------------------------------------------

APP_NAME="Spoke"
SCHEME="Spoke"
PROJECT="Spoke.xcodeproj"
DMG_NAME="Spoke.dmg"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

APPLE_ID="${APPLE_ID:?Set APPLE_ID env var to your Apple ID email}"
TEAM_ID="${TEAM_ID:?Set TEAM_ID env var to your 10-char Team ID}"
APP_PASSWORD="${APP_PASSWORD:?Set APP_PASSWORD env var to your app-specific password}"

echo "==> Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building release archive..."
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    -quiet

echo "==> Exporting app (Developer ID)..."
cat > "$BUILD_DIR/ExportOptions.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR" \
    -quiet

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_PATH not found after export"
    exit 1
fi

echo "==> Notarizing app..."
ditto -c -k --keepParent "$APP_PATH" "$BUILD_DIR/$APP_NAME.zip"

xcrun notarytool submit "$BUILD_DIR/$APP_NAME.zip" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

echo "==> Stapling notarization ticket to app..."
xcrun stapler staple "$APP_PATH"

echo "==> Creating DMG..."
rm -f "$DMG_NAME"

create-dmg \
    --volname "$APP_NAME" \
    --background "Spoke/Assets.xcassets/Background.imageset/bg.png" \
    --window-size 600 400 \
    --window-pos 200 120 \
    --icon-size 128 \
    --icon "$APP_NAME.app" 150 200 \
    --app-drop-link 450 200 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_NAME" \
    "$APP_PATH"

echo "==> Notarizing DMG..."
xcrun notarytool submit "$DMG_NAME" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

echo "==> Stapling notarization ticket to DMG..."
xcrun stapler staple "$DMG_NAME"

echo ""
echo "==> Done! Created $DMG_NAME (signed, notarized, stapled)"
echo "    Size: $(du -h "$DMG_NAME" | cut -f1)"
