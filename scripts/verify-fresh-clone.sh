#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h}"
SOURCE_COMMIT="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
SOURCE_DIRTY="false"
if [[ -n "$(git -C "$REPOSITORY_ROOT" status --porcelain)" ]]; then
  SOURCE_DIRTY="true"
fi

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-assistant-fresh-clone.XXXXXX")"
CLONE_ROOT="$TEMP_ROOT/CAM_Assistant"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

git clone --quiet --no-local "$REPOSITORY_ROOT" "$CLONE_ROOT"

cd "$CLONE_ROOT"
/bin/zsh scripts/verify.sh portability
CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all
/bin/zsh scripts/verify.sh package
/bin/zsh scripts/verify.sh smoke

if [[ -n "$(git status --porcelain)" ]]; then
  print -u2 "fresh-clone verification changed tracked repository files"
  git status --short
  exit 1
fi

print "CAM_ASSISTANT_FRESH_CLONE commit=$SOURCE_COMMIT source_dirty=$SOURCE_DIRTY tests=pass release_build=pass package=pass smoke=pass"
