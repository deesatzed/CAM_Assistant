#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
VERIFY="$REPOSITORY_ROOT/scripts/verify.sh"
REPORT="$REPOSITORY_ROOT/docs/evidence/task-18-release-privacy-scan.json"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-assistant-release-suite.XXXXXX")"
OUTPUT="$TEST_ROOT/output.txt"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

"$VERIFY" release-privacy >"$OUTPUT"

/usr/bin/grep -q \
  'CAM_ASSISTANT_PRIVACY_SCAN_TESTS status=pass' "$OUTPUT"
/usr/bin/grep -q \
  'CAM_ASSISTANT_PRIVACY_SCAN status=pass' "$OUTPUT"
/usr/bin/plutil -p "$REPORT" >/dev/null
/usr/bin/grep -q '"status":"pass"' "$REPORT"
/usr/bin/grep -q '"findingCount":0' "$REPORT"

print "CAM_ASSISTANT_RELEASE_PRIVACY_SUITE_TESTS status=pass"
