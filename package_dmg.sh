#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SLSwitch"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
FINAL_DMG="$BUILD_DIR/SLSwitch-Installer.dmg"
RW_DMG="$BUILD_DIR/SLSwitch-Installer-rw.dmg"
VOLUME_NAME="SLSwitch"
MOUNT_POINT="/Volumes/$VOLUME_NAME"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

"$ROOT_DIR/build_app.sh"
codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

rm -f "$FINAL_DMG" "$RW_DMG"
if [ -d "$MOUNT_POINT" ]; then
    hdiutil detach "$MOUNT_POINT" || true
fi

hdiutil create -size 35m -volname "$VOLUME_NAME" -fs HFS+ -type UDIF -ov "$RW_DMG"
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_POINT" -nobrowse

mkdir -p "$MOUNT_POINT/.background"
cp "$ROOT_DIR/Resources/Installer/background.png" "$MOUNT_POINT/.background/background.png"
cp -R "$APP_DIR" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"
chflags hidden "$MOUNT_POINT/.background"

osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "SLSwitch"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {120, 120, 680, 440}
        set arrangement of icon view options of container window to not arranged
        set icon size of icon view options of container window to 96
        set background picture of icon view options of container window to file ".background:background.png"
        set position of item "SLSwitch.app" to {150, 165}
        set position of item "Applications" to {410, 165}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

hdiutil detach "$MOUNT_POINT"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"
hdiutil verify "$FINAL_DMG"
rm -f "$RW_DMG"
rm -rf "$APP_DIR" "$BUILD_DIR/module-cache" "$BUILD_DIR/.DS_Store"

echo "Built: $FINAL_DMG"
