#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
GOAL="$REPOSITORY_ROOT/GOAL_BAREBONES.md"
ROOT_GOAL="$REPOSITORY_ROOT/GOAL.md"
VERIFY="$REPOSITORY_ROOT/scripts/verify.sh"

[[ -f "$GOAL" ]]

required_phrases=(
  "general iPhone user"
  "Home"
  "Library"
  "Settings"
  "Capture gate"
  "Find gate"
  "Ask gate"
  "Keep gate"
  "Recover gate"
  "Human gate"
  "progressive disclosure"
  "no model"
  "Stop Rules"
)

for phrase in "${required_phrases[@]}"; do
  /usr/bin/grep -F -q "$phrase" "$GOAL"
done

/usr/bin/grep -F -q 'GOAL_BAREBONES.md' "$ROOT_GOAL"
/usr/bin/grep -F -q 'barebones-goal)' "$VERIFY"
/usr/bin/grep -F -q 'Tests/ReleaseProofTests/barebones-goal-contract-tests.sh' "$VERIFY"

gate_count="$(/usr/bin/grep -E -c '^## Gate [1-7]:' "$GOAL")"
[[ "$gate_count" == "7" ]]

print "CAM_ASSISTANT_BAREBONES_GOAL status=pass gates=$gate_count"
