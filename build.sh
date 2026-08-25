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
ARCHS_STRING="${ARCHS:-$(uname -m)}"
read -r -a ARCHS_TO_BUILD <<< "$ARCHS_STRING"
mkdir -p "$BUILD_DIR"
TEMP_DIR="$(mktemp -d "$BUILD_DIR/architectures.XXXXXX")"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
rm -f "$EXECUTABLE"

if [[ ${#ARCHS_TO_BUILD[@]} -eq 0 ]]; then
  echo "ARCHS must contain at least one architecture" >&2
  exit 1
fi

EXECUTABLES=()
for arch in "${ARCHS_TO_BUILD[@]}"; do
  case "$arch" in
    arm64|x86_64) ;;
    *)
      echo "Unsupported architecture: $arch (expected arm64 or x86_64)" >&2
      exit 1
      ;;
  esac

  arch_executable="$TEMP_DIR/$APP_NAME-$arch"
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
    -target "$arch-apple-macosx13.0" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Security \
    -framework CryptoKit \
    -O \
    -o "$arch_executable"
  EXECUTABLES+=("$arch_executable")
done

if [[ ${#EXECUTABLES[@]} -eq 1 ]]; then
  mv "${EXECUTABLES[0]}" "$EXECUTABLE"
else
  lipo -create "${EXECUTABLES[@]}" -output "$EXECUTABLE"
fi

cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$SCRIPT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$EXECUTABLE"
plutil -lint "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

echo "Built $APP_DIR for ${ARCHS_TO_BUILD[*]}"
