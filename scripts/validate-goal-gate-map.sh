#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h}"
GOAL="$REPOSITORY_ROOT/GOAL_FINISH_WIKI.md"
MANIFEST="${1:-$REPOSITORY_ROOT/docs/evidence/goal-finish-wiki-gate-map.json}"

if [[ ! -f "$MANIFEST" ]]; then
  print -u2 "goal gate map is unavailable"
  exit 66
fi

extract() {
  /usr/bin/plutil -extract "$1" raw -o - "$MANIFEST"
}

fail() {
  print -u2 "goal gate map invalid: $1"
  exit 1
}

schema_version="$(extract schemaVersion)"
source_goal="$(extract sourceGoal)"
recorded_goal_sha="$(extract sourceGoalSHA256)"
overall_status="$(extract overallStatus)"
current_goal_sha="$(shasum -a 256 "$GOAL" | awk '{print $1}')"

[[ "$schema_version" == "1" ]] || fail "unsupported schema version"
[[ "$source_goal" == "GOAL_FINISH_WIKI.md" ]] \
  || fail "source goal must be repository relative"
[[ "$recorded_goal_sha" == "$current_goal_sha" ]] \
  || fail "source goal digest drifted"

typeset -A expected_lines
while IFS= read -r line_number; do
  expected_lines[$line_number]=1
done < <(
  awk '
    /^### PROOF OF DONE/ { inside = 1; next }
    /^### SCOPE/ { inside = 0 }
    inside && /^- / { print NR }
  ' "$GOAL"
)

typeset -A seen_lines
typeset -A seen_ids
gate_count=0
passed_count=0
partial_count=0
missing_count=0
deferred_count=0
previous_source_line=0

while gate_id="$(
  /usr/bin/plutil -extract "gates.$gate_count.id" raw -o - \
    "$MANIFEST" 2>/dev/null
)"; do
  source_line="$(extract "gates.$gate_count.sourceLine")"
  gate_status="$(extract "gates.$gate_count.status")"

  [[ -n "$gate_id" ]] || fail "gate $gate_count has a blank id"
  [[ -z "${seen_ids[$gate_id]:-}" ]] || fail "duplicate gate id"
  seen_ids[$gate_id]=1

  [[ -n "${expected_lines[$source_line]:-}" ]] \
    || fail "gate source line is not a Proof-of-Done bullet"
  [[ -z "${seen_lines[$source_line]:-}" ]] || fail "duplicate source line"
  (( source_line > previous_source_line )) || fail "gates are out of source order"
  seen_lines[$source_line]=1
  previous_source_line="$source_line"

  case "$gate_status" in
    passed)
      (( passed_count += 1 ))
      ;;
    partial)
      (( partial_count += 1 ))
      ;;
    missing)
      (( missing_count += 1 ))
      ;;
    deferred)
      (( deferred_count += 1 ))
      ;;
    *)
      fail "gate has an unsupported status"
      ;;
  esac

  evidence_index=0
  while evidence_path="$(
    /usr/bin/plutil -extract \
      "gates.$gate_count.evidence.$evidence_index" raw -o - \
      "$MANIFEST" 2>/dev/null
  )"; do
    [[ -n "$evidence_path" ]] || fail "gate has a blank evidence path"
    [[ "$evidence_path" != /* ]] || fail "evidence path must be relative"
    [[ "/$evidence_path/" != *"/../"* ]] \
      || fail "evidence path escapes the repository"
    [[ -f "$REPOSITORY_ROOT/$evidence_path" ]] \
      || fail "evidence path does not exist"
    (( evidence_index += 1 ))
  done
  (( evidence_index > 0 )) || fail "gate has no evidence"

  if [[ "$gate_status" != "passed" ]]; then
    limitation="$(extract "gates.$gate_count.limitation")"
    [[ -n "$limitation" ]] || fail "non-passed gate has no limitation"
  fi

  (( gate_count += 1 ))
done

expected_count="${#expected_lines}"
(( gate_count == expected_count )) || fail "Proof-of-Done coverage is incomplete"
(( ${#seen_lines} == expected_count )) || fail "source-line coverage is incomplete"

[[ "$(extract summary.total)" == "$gate_count" ]] \
  || fail "summary total is stale"
[[ "$(extract summary.passed)" == "$passed_count" ]] \
  || fail "summary passed count is stale"
[[ "$(extract summary.partial)" == "$partial_count" ]] \
  || fail "summary partial count is stale"
[[ "$(extract summary.missing)" == "$missing_count" ]] \
  || fail "summary missing count is stale"
[[ "$(extract summary.deferred)" == "$deferred_count" ]] \
  || fail "summary deferred count is stale"

nonpassing_count=$(( partial_count + missing_count + deferred_count ))
expected_overall="complete"
if (( nonpassing_count > 0 )); then
  expected_overall="incomplete"
fi
[[ "$overall_status" == "$expected_overall" ]] \
  || fail "overall status contradicts gate verdicts"

print \
  "CAM_ASSISTANT_GOAL_GATE_MAP status=$overall_status gates=$gate_count passed=$passed_count partial=$partial_count missing=$missing_count deferred=$deferred_count"
