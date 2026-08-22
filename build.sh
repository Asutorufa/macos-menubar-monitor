#!/usr/bin/env bash
set -euo pipefail

APP_NAME="StatusBar"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/$APP_NAME"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
rm -f "$EXECUTABLE"

swiftc \
  "$SCRIPT_DIR/Models.swift" \
  "$SCRIPT_DIR/Localization.swift" \
  "$SCRIPT_DIR/Configuration.swift" \
  "$SCRIPT_DIR/Formatting.swift" \
  "$SCRIPT_DIR/Providers.swift" \
  "$SCRIPT_DIR/AWSClient.swift" \
  "$SCRIPT_DIR/AppStore.swift" \
  "$SCRIPT_DIR/Views.swift" \
  "$SCRIPT_DIR/AppDelegate.swift" \
  "$SCRIPT_DIR/main.swift" \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Security \
  -framework CryptoKit \
  -O \
  -o "$EXECUTABLE"

cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SCRIPT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$EXECUTABLE"
plutil -lint "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

echo "Built $APP_DIR"
