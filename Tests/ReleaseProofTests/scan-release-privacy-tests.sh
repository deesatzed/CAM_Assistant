#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
SCANNER="$REPOSITORY_ROOT/scripts/scan-release-privacy.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-assistant-privacy-scan.XXXXXX")"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

clean_root="$TEST_ROOT/clean scope"
mkdir -p "$clean_root"
print -- "CAM Assistant keeps personal material local." \
  > "$clean_root/public.txt"

clean_report="$TEST_ROOT/clean-report.json"
"$SCANNER" "$clean_report" "$clean_root"

/usr/bin/plutil -p "$clean_report" >/dev/null
/usr/bin/grep -q '"status":"pass"' "$clean_report"
/usr/bin/grep -q '"scannedFileCount":1' "$clean_report"
/usr/bin/grep -q '"findingCount":0' "$clean_report"

failure_root="$TEST_ROOT/failure-scope"
mkdir -p "$failure_root"
secret_prefix="sk-"
synthetic_secret="${secret_prefix}synthetic012345678901234567890"
print -- "$synthetic_secret" > "$failure_root/restricted.txt"

failure_report="$TEST_ROOT/failure-report.json"
stdout_receipt="$TEST_ROOT/stdout.txt"
stderr_receipt="$TEST_ROOT/stderr.txt"
if "$SCANNER" "$failure_report" "$failure_root" \
    >"$stdout_receipt" 2>"$stderr_receipt"; then
  print -u2 "expected credential finding to fail the release privacy scan"
  exit 1
fi

/usr/bin/plutil -p "$failure_report" >/dev/null
/usr/bin/grep -q '"status":"fail"' "$failure_report"
/usr/bin/grep -q '"scannedFileCount":1' "$failure_report"
/usr/bin/grep -q '"findingCount":1' "$failure_report"

if /usr/bin/grep -q "$synthetic_secret" \
    "$failure_report" "$stdout_receipt" "$stderr_receipt"; then
  print -u2 "privacy scan exposed matching credential bytes"
  exit 1
fi

print "CAM_ASSISTANT_PRIVACY_SCAN_TESTS status=pass"
