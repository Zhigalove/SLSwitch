#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SLSwitch"
MODULE_NAME="SLSwitch"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"
SPARKLE_DIR="$ROOT_DIR/Vendor/Sparkle"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Resources/Info.plist")}"
BUILD_NUMBER="${BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ROOT_DIR/Resources/Info.plist")}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

swiftc \
  -O \
  -module-name "$MODULE_NAME" \
  -target arm64-apple-macos13.0 \
  -F "$SPARKLE_DIR" \
  -framework AppKit \
  -framework Carbon \
  -framework ServiceManagement \
  -framework Sparkle \
  -framework UserNotifications \
  -Xlinker -rpath \
  -Xlinker "@executable_path/../Frameworks" \
  "$ROOT_DIR"/Sources/SLSwitch/*.swift \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Resources/StatusBar/StatusBarIconTemplate.png" "$RESOURCES_DIR/StatusBarIconTemplate.png"
find "$ROOT_DIR/Resources" -maxdepth 1 -name "*.lproj" -type d -exec cp -R {} "$RESOURCES_DIR/" \;
cp -R "$SPARKLE_DIR/Sparkle.framework" "$FRAMEWORKS_DIR/Sparkle.framework"

echo "Built: $APP_DIR"
