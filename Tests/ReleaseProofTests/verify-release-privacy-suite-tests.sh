#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
VERIFY="$REPOSITORY_ROOT/scripts/verify.sh"
# Live scan receipt is gitignored under artifacts/ so fresh-clone stays clean.
# docs/evidence/task-18-release-privacy-scan.json remains historical evidence only.
REPORT="$REPOSITORY_ROOT/artifacts/release-privacy-scan.json"
HISTORICAL_EVIDENCE="$REPOSITORY_ROOT/docs/evidence/task-18-release-privacy-scan.json"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-assistant-release-suite.XXXXXX")"
OUTPUT="$TEST_ROOT/output.txt"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

HISTORICAL_BEFORE="$(/usr/bin/shasum -a 256 "$HISTORICAL_EVIDENCE" | /usr/bin/awk '{print $1}')"

"$VERIFY" release-privacy >"$OUTPUT"

/usr/bin/grep -q \
  'CAM_ASSISTANT_PRIVACY_SCAN_TESTS status=pass' "$OUTPUT"
/usr/bin/grep -q \
  'CAM_ASSISTANT_PACKAGE_IDENTITY status=pass' "$OUTPUT"
/usr/bin/grep -q \
  'CAM_ASSISTANT_PRIVACY_SCAN status=pass' "$OUTPUT"
/usr/bin/plutil -p "$REPORT" >/dev/null
/usr/bin/grep -q '"status":"pass"' "$REPORT"
/usr/bin/grep -q '"findingCount":0' "$REPORT"

HISTORICAL_AFTER="$(/usr/bin/shasum -a 256 "$HISTORICAL_EVIDENCE" | /usr/bin/awk '{print $1}')"
if [[ "$HISTORICAL_BEFORE" != "$HISTORICAL_AFTER" ]]; then
  print -u2 "release privacy scan must not mutate committed historical evidence"
  exit 1
fi

print "CAM_ASSISTANT_RELEASE_PRIVACY_SUITE_TESTS status=pass"
