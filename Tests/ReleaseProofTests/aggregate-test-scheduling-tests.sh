#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
VERIFY="$REPOSITORY_ROOT/scripts/verify.sh"

if /usr/bin/grep -q -- '--parallel\|--num-workers' "$VERIFY"; then
  print -u2 "aggregate verification must use SwiftPM's default non-parallel test mode"
  exit 1
fi

/usr/bin/grep -F -q \
  'swift test --disable-sandbox --scratch-path .swift-build' "$VERIFY"

print "CAM_ASSISTANT_AGGREGATE_TEST_SCHEDULING status=pass mode=nonparallel"
