#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SLSwitch"
MODULE_NAME="SLSwitch"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Resources/Info.plist")}"
BUILD_NUMBER="${BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ROOT_DIR/Resources/Info.plist")}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc \
  -O \
  -module-name "$MODULE_NAME" \
  -target arm64-apple-macos13.0 \
  -framework AppKit \
  -framework ApplicationServices \
  -framework Carbon \
  -framework ServiceManagement \
  -framework UserNotifications \
  "$ROOT_DIR"/Sources/SLSwitch/*.swift \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Resources/StatusBar/StatusBarIconTemplate.png" "$RESOURCES_DIR/StatusBarIconTemplate.png"
find "$ROOT_DIR/Resources" -maxdepth 1 -name "*.lproj" -type d -exec cp -R {} "$RESOURCES_DIR/" \;

echo "Built: $APP_DIR"
