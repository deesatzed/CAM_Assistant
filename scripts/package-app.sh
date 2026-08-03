#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${SCRIPT_DIR:h}"
BUILD_DIR="$ROOT/.swift-build"
APP_DIR="$ROOT/artifacts/CAM Assistant.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
MODULE_MANIFEST_DIR="$APP_DIR/Contents/Resources/Modules/Core"
MEANING_PREVIEW_RESOURCES_DIR="$APP_DIR/Contents/Resources/MeaningPreview"
MEANING_PREVIEW_MANIFEST="$ROOT/Modules/Core/meaning-preview.json"
CORE_RESOURCE_BUNDLE="$BUILD_DIR/arm64-apple-macosx/release/CAMAssistant_CAMAssistantCore.bundle"
COMMITTED_REFLECTION_REPORT="$ROOT/docs/evidence/add2cam-09-named-model-report.json"
BUILD_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD)"
BUILD_SOURCE_DIRTY="false"
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  BUILD_SOURCE_DIRTY="true"
fi

cd "$ROOT"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"

swift build --disable-sandbox --scratch-path "$BUILD_DIR" -c release --product CAMAssistant
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$MODULE_MANIFEST_DIR"
cp "$BUILD_DIR/arm64-apple-macosx/release/CAMAssistant" "$MACOS_DIR/CAMAssistant"
cp "$MEANING_PREVIEW_MANIFEST" \
  "$MODULE_MANIFEST_DIR/meaning-preview.json"
if [[ ! -d "$CORE_RESOURCE_BUNDLE" ]]; then
  print -u2 "SwiftPM core resource bundle is unavailable"
  exit 66
fi
cp -R "$CORE_RESOURCE_BUNDLE" \
  "$APP_DIR/CAMAssistant_CAMAssistantCore.bundle"

if git -C "$ROOT" ls-files --error-unmatch \
    "docs/evidence/add2cam-09-named-model-report.json" >/dev/null 2>&1; then
  if [[ ! -f "$COMMITTED_REFLECTION_REPORT" ]]; then
    print -u2 "committed Meaning Preview named-model report is unavailable"
    exit 66
  fi
  mkdir -p "$MEANING_PREVIEW_RESOURCES_DIR"
  cp "$COMMITTED_REFLECTION_REPORT" \
    "$MEANING_PREVIEW_RESOURCES_DIR/named-model-report.json"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
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

/usr/bin/plutil -insert CFBundleVersion -string "$BUILD_NUMBER" \
  "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CAMBuildCommit -string "$BUILD_COMMIT" \
  "$APP_DIR/Contents/Info.plist"
/usr/bin/plutil -insert CAMBuildSourceDirty -bool "$BUILD_SOURCE_DIRTY" \
  "$APP_DIR/Contents/Info.plist"
plutil -lint "$APP_DIR/Contents/Info.plist"
print "$APP_DIR"
