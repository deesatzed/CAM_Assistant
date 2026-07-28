#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
VALIDATOR="$REPOSITORY_ROOT/scripts/validate-goal-gate-map.sh"
MANIFEST="$REPOSITORY_ROOT/docs/evidence/goal-finish-wiki-gate-map.json"
VERIFY="$REPOSITORY_ROOT/scripts/verify.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-assistant-goal-map.XXXXXX")"
OUTPUT="$TEST_ROOT/output.txt"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

"$VALIDATOR" "$MANIFEST" >"$OUTPUT"

/usr/bin/grep -q \
  'CAM_ASSISTANT_GOAL_GATE_MAP status=incomplete gates=48' "$OUTPUT"
/usr/bin/plutil -p "$MANIFEST" >/dev/null
/usr/bin/grep -q 'goal-map)' "$VERIFY"
/usr/bin/grep -F -q '"$SCRIPT_DIR/verify.sh" goal-map' "$VERIFY"

summary_line="$(tail -n 1 "$OUTPUT")"
print "$summary_line"
print "CAM_ASSISTANT_GOAL_GATE_MAP_TESTS status=pass"
