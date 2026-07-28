#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
VERIFIER="$REPOSITORY_ROOT/scripts/verify-package-reproducibility.sh"
AGGREGATE_VERIFY="$REPOSITORY_ROOT/scripts/verify.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-assistant-package-repro.XXXXXX")"
OUTPUT="$TEST_ROOT/output.txt"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

"$VERIFIER" >"$OUTPUT"

/usr/bin/grep -q \
  'CAM_ASSISTANT_PACKAGE_REPRODUCIBILITY status=pass builds=2' "$OUTPUT"
/usr/bin/grep -q 'package-reproducibility)' "$AGGREGATE_VERIFY"
/usr/bin/grep -F -q \
  '"$SCRIPT_DIR/verify.sh" package-reproducibility' "$AGGREGATE_VERIFY"

summary_line="$(tail -n 1 "$OUTPUT")"
print "$summary_line"
print "CAM_ASSISTANT_PACKAGE_REPRODUCIBILITY_TESTS status=pass"
