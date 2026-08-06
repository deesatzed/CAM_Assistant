#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-barebones-packaged.XXXXXX")"
SUPPORT_ROOT="$TEST_ROOT/application-support"
OUTPUT_FILE="$TEST_ROOT/proof-output.txt"
PACKAGED_APP="$REPOSITORY_ROOT/artifacts/CAM Assistant.app"
PACKAGED_EXECUTABLE="$PACKAGED_APP/Contents/MacOS/CAMAssistant"
APP_PID=""

cleanup() {
  if [[ -n "$APP_PID" ]]; then
    kill "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  print -u2 "CAM_ASSISTANT_BAREBONES_PACKAGED status=fail reason=$1"
  exit 1
}

CAM_ASSISTANT_BUILD_DIR="$TEST_ROOT/swift-build" \
  "$REPOSITORY_ROOT/scripts/package-app.sh" >/dev/null
[[ -x "$PACKAGED_EXECUTABLE" ]] || fail packaged-executable-missing
/usr/bin/strings -a "$PACKAGED_EXECUTABLE" \
  | /usr/bin/grep "CAM_ASSISTANT_BAREBONES_PROOF" >/dev/null \
  || fail packaged-proof-entry-missing

mkdir -p "$SUPPORT_ROOT"
CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT="$SUPPORT_ROOT" \
CAM_ASSISTANT_BAREBONES_PROOF_HOLD_SECONDS=2 \
  "$PACKAGED_EXECUTABLE" --barebones-proof "$SUPPORT_ROOT" \
  >"$OUTPUT_FILE" 2>&1 &
APP_PID=$!

for _ in {1..100}; do
  if /usr/bin/grep -q "CAM_ASSISTANT_BAREBONES_PROOF status=pass" \
      "$OUTPUT_FILE" 2>/dev/null; then
    break
  fi
  kill -0 "$APP_PID" >/dev/null 2>&1 \
    || fail packaged-proof-exited-before-receipt
  /bin/sleep 0.1
done

/usr/bin/grep -q "shell=Home,Library,Settings" "$OUTPUT_FILE" \
  || fail primary-shell
/usr/bin/grep -q "capture=true duplicate=true restart=true" "$OUTPUT_FILE" \
  || fail capture-restart
/usr/bin/grep -q "ask=matchingPassages citations=1" "$OUTPUT_FILE" \
  || fail model-free-ask
/usr/bin/grep -q "keep_restart=true undo=true" "$OUTPUT_FILE" \
  || fail kept-memory
/usr/bin/grep -q "backup=true restore=true watched_paused=true" "$OUTPUT_FILE" \
  || fail recovery
/usr/bin/grep -q "network_requests=0" "$OUTPUT_FILE" \
  || fail model-free-network-count

set +e
/usr/sbin/lsof -nP -a -p "$APP_PID" -i >/dev/null 2>&1
socket_status=$?
set -e
[[ "$socket_status" -eq 1 ]] || fail app-network-socket-observed

wait "$APP_PID"
APP_PID=""
print "CAM_ASSISTANT_BAREBONES_PACKAGED status=pass"
