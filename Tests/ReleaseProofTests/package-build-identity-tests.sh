#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
PLIST="$REPOSITORY_ROOT/artifacts/CAM Assistant.app/Contents/Info.plist"

if [[ ! -f "$PLIST" ]]; then
  print -u2 "packaged app Info.plist is unavailable"
  exit 66
fi

expected_commit="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
expected_build_number="$(git -C "$REPOSITORY_ROOT" rev-list --count HEAD)"
expected_dirty="false"
if [[ -n "$(git -C "$REPOSITORY_ROOT" status --porcelain)" ]]; then
  expected_dirty="true"
fi

actual_commit="$(/usr/bin/plutil -extract CAMBuildCommit raw -o - "$PLIST")"
actual_build_number="$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$PLIST")"
actual_dirty="$(/usr/bin/plutil -extract CAMBuildSourceDirty raw -o - "$PLIST")"

if [[ "$actual_commit" != "$expected_commit" ]]; then
  print -u2 "packaged commit identity does not match repository HEAD"
  exit 1
fi

if [[ "$actual_build_number" != "$expected_build_number" ]]; then
  print -u2 "packaged build number does not match repository commit count"
  exit 1
fi

if [[ "$actual_dirty" != "$expected_dirty" ]]; then
  print -u2 "packaged dirty-state identity does not match repository state"
  exit 1
fi

print \
  "CAM_ASSISTANT_PACKAGE_IDENTITY status=pass commit=$actual_commit build=$actual_build_number dirty=$actual_dirty"
