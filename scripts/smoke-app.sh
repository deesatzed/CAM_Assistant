#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${SCRIPT_DIR:h}"
BUILD_DIR="$ROOT/.swift-build"

cd "$ROOT"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_DIR/module-cache"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"

swift build --scratch-path "$BUILD_DIR" --product CAMAssistant
"$BUILD_DIR/arm64-apple-macosx/debug/CAMAssistant" --smoke-offline
