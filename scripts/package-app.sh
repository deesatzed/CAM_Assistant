#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${SCRIPT_DIR:h}"
BUILD_DIR="$ROOT/.swift-build"
APP_DIR="$ROOT/artifacts/CAM Assistant.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"

cd "$ROOT"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"

swift build --scratch-path "$BUILD_DIR" -c release --product CAMAssistant
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$BUILD_DIR/arm64-apple-macosx/release/CAMAssistant" "$MACOS_DIR/CAMAssistant"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>CAMAssistant</string>
  <key>CFBundleIdentifier</key><string>com.deesatzed.cam-assistant</string>
  <key>CFBundleName</key><string>CAM Assistant</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
</dict></plist>
PLIST

plutil -lint "$APP_DIR/Contents/Info.plist"
print "$APP_DIR"
