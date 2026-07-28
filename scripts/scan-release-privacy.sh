#!/bin/zsh
set -euo pipefail

if (( $# < 2 )); then
  print -u2 "usage: $0 REPORT_JSON SCOPE [SCOPE ...]"
  exit 64
fi

report_path="$1"
shift
report_absolute="${report_path:A}"
report_directory="${report_path:h}"
temporary_report="${report_path}.tmp.$$"
credential_pattern='(^|[^A-Za-z0-9])(-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|sk-(proj-|or-v1-)?[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{20,})'

typeset -A seen_files
typeset -a candidate_files
scanned_file_count=0
finding_count=0

cleanup() {
  rm -f "$temporary_report"
}
trap cleanup EXIT

record_candidate() {
  local candidate="$1"
  local candidate_absolute="${candidate:A}"

  if [[ "$candidate_absolute" == "$report_absolute" ]] \
      || [[ -n "${seen_files[$candidate_absolute]:-}" ]]; then
    return
  fi

  seen_files[$candidate_absolute]=1
  candidate_files+=("$candidate_absolute")
}

for scope in "$@"; do
  if [[ -f "$scope" ]]; then
    record_candidate "$scope"
  elif [[ -d "$scope" ]]; then
    while IFS= read -r -d '' candidate; do
      record_candidate "$candidate"
    done < <(/usr/bin/find "$scope" -type f -print0)
  else
    print -u2 "release privacy scan scope is unavailable"
    exit 66
  fi
done

for candidate in "${candidate_files[@]}"; do
  (( scanned_file_count += 1 ))
  if LC_ALL=C /usr/bin/grep -a -E -q "$credential_pattern" "$candidate"; then
    (( finding_count += 1 ))
  fi
done

scan_status="pass"
exit_status=0
if (( finding_count > 0 )); then
  scan_status="fail"
  exit_status=1
fi

mkdir -p "$report_directory"
print -n -- \
  "{\"schemaVersion\":1,\"status\":\"$scan_status\",\"scannedFileCount\":$scanned_file_count,\"findingCount\":$finding_count}" \
  > "$temporary_report"
print >> "$temporary_report"
mv "$temporary_report" "$report_path"

print "CAM_ASSISTANT_PRIVACY_SCAN status=$scan_status scanned_files=$scanned_file_count findings=$finding_count"
exit "$exit_status"
