#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DesktopCat"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
REQUIRED_ANIMATIONS=(
  idle running-left running-right waving jumping failed waiting running review
  belly todo-loaf timer-yawn
)

cd "$ROOT_DIR"

for animation in "${REQUIRED_ANIMATIONS[@]}"; do
  if [[ ! -f "$ROOT_DIR/Assets/animations/$animation.gif" ]]; then
    echo "Missing animation: Assets/animations/$animation.gif" >&2
    exit 1
  fi
done

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR/animations"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/App/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Assets/animations/"*.gif "$RESOURCES_DIR/animations/"

chmod +x "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
