#!/bin/bash
set -euo pipefail

APP_NAME="Spoke"
SCHEME="Spoke"
PROJECT="Spoke.xcodeproj"
DMG_NAME="Spoke.dmg"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

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

echo "==> Exporting app..."
# Create export options plist
cat > "$BUILD_DIR/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR" \
    -quiet 2>/dev/null || {
    # If export fails (e.g. no signing identity), fall back to copying from archive
    echo "==> Export failed, copying app from archive directly..."
    cp -R "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$APP_PATH"
}

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_PATH not found"
    exit 1
fi

echo "==> Creating DMG..."
rm -f "$DMG_NAME"

create-dmg \
    --volname "$APP_NAME" \
    --background "bg.png" \
    --window-size 600 400 \
    --window-pos 200 120 \
    --icon-size 128 \
    --icon "$APP_NAME.app" 150 200 \
    --app-drop-link 450 200 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_NAME" \
    "$APP_PATH"

echo ""
echo "==> Done! Created $DMG_NAME"
echo "    Size: $(du -h "$DMG_NAME" | cut -f1)"
