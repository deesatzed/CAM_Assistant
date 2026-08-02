#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
PACKAGE_SCRIPT="$REPOSITORY_ROOT/scripts/package-app.sh"
BUILD_DIR="$REPOSITORY_ROOT/.swift-build"
SOURCE_MANIFEST_DIRECTORY="$REPOSITORY_ROOT/Modules/Core"
PACKAGED_APP="$REPOSITORY_ROOT/artifacts/CAM Assistant.app"
SOURCE_MANIFEST="$REPOSITORY_ROOT/Modules/Core/meaning-preview.json"
SOURCE_REPORT="$REPOSITORY_ROOT/docs/evidence/add2cam-09-named-model-report.json"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-meaning-preview-packaged.XXXXXX")"
PILOT_APP="$TEST_ROOT/CAM Assistant.app"
SUPPORT_ROOT="$TEST_ROOT/application-support"
VAULT_ROOT="$SUPPORT_ROOT/CAMAssistant"
VAULT_DB="$VAULT_ROOT/vault.sqlite"
MODULE_STATE="$VAULT_ROOT/module-state.json"
PREVIEW_DB="$VAULT_ROOT/meaning-preview/MeaningPreview.sqlite"
SYNTHETIC_MARKER="CAM_MEANING_PREVIEW_SYNTHETIC_PILOT_MARKER"
APP_PID=""
BUILD_MODE=""
SOURCE_MANIFEST_MODE=""
BUILD_WAS_RESTRICTED="false"
SOURCE_MANIFEST_WAS_RESTRICTED="false"

graceful_terminate_launched_app() {
  if [[ -z "$APP_PID" ]]; then
    return
  fi
  /usr/bin/osascript -l JavaScript - "$APP_PID" >/dev/null 2>&1 <<'JXA' || true
ObjC.import("AppKit")
function run(argv) {
    const wantedPID = Number(argv[0])
    const applications = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(
        "com.deesatzed.cam-assistant"
    ).js
    applications.forEach(application => {
        if (Number(application.processIdentifier) === wantedPID) {
            application.terminate
        }
    })
}
JXA
  for _ in {1..50}; do
    if ! /bin/ps -p "$APP_PID" >/dev/null 2>&1; then
      APP_PID=""
      return
    fi
    /bin/sleep 0.1
  done
}

cleanup() {
  graceful_terminate_launched_app
  if [[ "$BUILD_WAS_RESTRICTED" == "true" ]]; then
    chmod "$BUILD_MODE" "$BUILD_DIR"
  fi
  if [[ "$SOURCE_MANIFEST_WAS_RESTRICTED" == "true" ]]; then
    chmod "$SOURCE_MANIFEST_MODE" "$SOURCE_MANIFEST_DIRECTORY"
  fi
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  print -u2 "CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED status=fail reason=$1"
  exit 1
}

if /usr/bin/pgrep -x CAMAssistant >/dev/null 2>&1; then
  print -u2 \
    "CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED status=refused reason=existing-app-process"
  exit 69
fi

if [[ -n "$(git -C "$REPOSITORY_ROOT" status --porcelain)" ]]; then
  print -u2 \
    "CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED status=refused reason=source-not-clean"
  exit 65
fi

"$PACKAGE_SCRIPT" >/dev/null
cp -R "$PACKAGED_APP" "$PILOT_APP"

EXPECTED_COMMIT="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
ACTUAL_COMMIT="$(/usr/bin/plutil -extract CAMBuildCommit raw -o - \
  "$PILOT_APP/Contents/Info.plist")"
ACTUAL_DIRTY="$(/usr/bin/plutil -extract CAMBuildSourceDirty raw -o - \
  "$PILOT_APP/Contents/Info.plist")"
[[ "$ACTUAL_COMMIT" == "$EXPECTED_COMMIT" ]] || fail package-commit-identity
[[ "$ACTUAL_DIRTY" == "false" ]] || fail package-dirty-identity

PACKAGED_MANIFEST="$PILOT_APP/Contents/Resources/Modules/Core/meaning-preview.json"
PACKAGED_CORE_BUNDLE="$PILOT_APP/CAMAssistant_CAMAssistantCore.bundle"
PACKAGED_REPORT="$PILOT_APP/Contents/Resources/MeaningPreview/named-model-report.json"
[[ -f "$PACKAGED_MANIFEST" ]] || fail manifest-missing
[[ -d "$PACKAGED_CORE_BUNDLE" ]] || fail core-resource-bundle-missing
/usr/bin/cmp -s "$SOURCE_MANIFEST" "$PACKAGED_MANIFEST" \
  || fail manifest-byte-drift

if git -C "$REPOSITORY_ROOT" ls-files --error-unmatch \
    "docs/evidence/add2cam-09-named-model-report.json" >/dev/null 2>&1; then
  [[ -f "$PACKAGED_REPORT" ]] || fail named-model-report-missing
  /usr/bin/cmp -s "$SOURCE_REPORT" "$PACKAGED_REPORT" \
    || fail named-model-report-byte-drift
else
  [[ ! -e "$PACKAGED_REPORT" ]] || fail uncommitted-named-model-report-packaged
fi

BUILD_MODE="$(/usr/bin/stat -f %Lp "$BUILD_DIR")"
SOURCE_MANIFEST_MODE="$(/usr/bin/stat -f %Lp "$SOURCE_MANIFEST_DIRECTORY")"
chmod 000 "$BUILD_DIR" "$SOURCE_MANIFEST_DIRECTORY"
BUILD_WAS_RESTRICTED="true"
SOURCE_MANIFEST_WAS_RESTRICTED="true"

launch_pilot_app() {
  /usr/bin/open -n "$PILOT_APP" --env \
    "CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT=$SUPPORT_ROOT"
  for _ in {1..100}; do
    APP_PID="$(/usr/bin/pgrep -x CAMAssistant || true)"
    if [[ -n "$APP_PID" ]]; then
      return
    fi
    /bin/sleep 0.1
  done
  fail app-launch-timeout
}

assert_no_app_sockets() {
  if /usr/sbin/lsof -nP -a -p "$APP_PID" -i >/dev/null 2>&1; then
    fail app-network-socket-observed
  fi
}

ax_phase() {
  local phase="$1"
  local output
  export CAM_PILOT_APP_PID="$APP_PID"
  export CAM_PILOT_SYNTHETIC_MARKER="$SYNTHETIC_MARKER"
  if ! output="$(/usr/bin/osascript - "$phase" 2>&1 <<'APPLESCRIPT'
on appProcess()
    set wantedPID to (system attribute "CAM_PILOT_APP_PID") as integer
    tell application "System Events"
        return first application process whose unix id is wantedPID
    end tell
end appProcess

on identifierOf(anElement)
    tell application "System Events"
        try
            return value of attribute "AXIdentifier" of anElement
        on error
            return ""
        end try
    end tell
end identifierOf

on findIdentifier(identifierValue)
    tell application "System Events"
        set processRef to my appProcess()
        repeat with windowRef in windows of processRef
            try
                if my identifierOf(windowRef) is identifierValue then return windowRef
                repeat with candidate in entire contents of windowRef
                    if my identifierOf(candidate) is identifierValue then return candidate
                end repeat
            end try
        end repeat
    end tell
    return missing value
end findIdentifier

on waitIdentifier(identifierValue)
    repeat 120 times
        set foundElement to my findIdentifier(identifierValue)
        if foundElement is not missing value then return foundElement
        delay 0.1
    end repeat
    error "CAM_AX_FAILURE:missing-" & identifierValue number 1002
end waitIdentifier

on waitIdentifierAbsent(identifierValue)
    repeat 120 times
        if my findIdentifier(identifierValue) is missing value then return
        delay 0.1
    end repeat
    error "CAM_AX_FAILURE:unexpected-" & identifierValue number 1002
end waitIdentifierAbsent

on findNamedButton(buttonName)
    tell application "System Events"
        set processRef to my appProcess()
        repeat with windowRef in windows of processRef
            try
                repeat with candidate in entire contents of windowRef
                    try
                        if role of candidate is "AXButton" and name of candidate is buttonName then
                            return candidate
                        end if
                    end try
                end repeat
            end try
        end repeat
    end tell
    return missing value
end findNamedButton

on waitNamedButton(buttonName)
    repeat 120 times
        set foundElement to my findNamedButton(buttonName)
        if foundElement is not missing value then return foundElement
        delay 0.1
    end repeat
    error "CAM_AX_FAILURE:missing-button" number 1002
end waitNamedButton

on waitNamedText(textValue)
    tell application "System Events"
        set processRef to my appProcess()
    end tell
    repeat 120 times
        tell application "System Events"
            repeat with windowRef in windows of processRef
                try
                    repeat with candidate in entire contents of windowRef
                        try
                            if name of candidate is textValue then return
                        end try
                    end repeat
                end try
            end repeat
        end tell
        delay 0.1
    end repeat
    error "CAM_AX_FAILURE:missing-status" number 1002
end waitNamedText

on clickIdentifier(identifierValue)
    set foundElement to my waitIdentifier(identifierValue)
    tell application "System Events" to click foundElement
end clickIdentifier

on waitEnabled(identifierValue)
    repeat 120 times
        set foundElement to my findIdentifier(identifierValue)
        if foundElement is not missing value then
            tell application "System Events"
                try
                    if enabled of foundElement then return foundElement
                end try
            end tell
        end if
        delay 0.1
    end repeat
    error "CAM_AX_FAILURE:disabled-" & identifierValue number 1002
end waitEnabled

on captureSyntheticClipboard()
    set savedClipboard to the clipboard as record
    try
        set the clipboard to system attribute "CAM_PILOT_SYNTHETIC_MARKER"
        set captureButton to my waitNamedButton("Capture Clipboard Locally")
        tell application "System Events" to click captureButton
        my waitNamedText("Clipboard captured and indexed locally.")
    on error errorText number errorNumber
        set the clipboard to savedClipboard
        error errorText number errorNumber
    end try
    set the clipboard to savedClipboard
end captureSyntheticClipboard

on run(arguments)
    set phase to item 1 of arguments
    try
        tell application "System Events" to set frontmost of my appProcess() to true
        if phase is "capture" then
            my waitIdentifier("assistant-section-settings")
            if my findIdentifier("meaning-preview-sidebar") is not missing value then
                error "CAM_AX_FAILURE:preview-visible-while-disabled" number 1002
            end if
            my captureSyntheticClipboard()
            return "capture=pass"
        else if phase is "exercise" then
            my clickIdentifier("assistant-section-settings")
            my clickIdentifier("meaning-preview-settings-open")
            my clickIdentifier("meaning-preview-enable")
            my waitIdentifier("meaning-preview-grant")
            my waitIdentifier("meaning-preview-sidebar")
            if my findIdentifier("meaning-preview-request") is not missing value then
                error "CAM_AX_FAILURE:enablement-granted-access" number 1002
            end if
            tell application "System Events" to key code 53
            my clickIdentifier("meaning-preview-sidebar")
            my waitIdentifier("meaning-preview-permission-state")
            my clickIdentifier("meaning-preview-grant")
            set pickerElement to my waitIdentifier("meaning-preview-source-picker")
            tell application "System Events"
                click pickerElement
                key code 125
                key code 36
            end tell
            set requestElement to my waitEnabled("meaning-preview-request")
            tell application "System Events" to click requestElement
            my waitIdentifier("meaning-preview-reflect-unavailable")
            repeat 120 times
                if my findIdentifier("meaning-preview-card") is not missing value then
                    my waitIdentifier("meaning-preview-inspect")
                    my waitIdentifier("meaning-preview-now")
                    my waitIdentifier("meaning-preview-later")
                    my waitIdentifier("meaning-preview-release")
                    my waitIdentifier("meaning-preview-helpful")
                    my waitIdentifier("meaning-preview-not-helpful")
                    my clickIdentifier("meaning-preview-inspect")
                    my waitIdentifier("meaning-preview-inspect-sheet")
                    tell application "System Events" to key code 53
                    my clickIdentifier("meaning-preview-helpful")
                    return "result=card feedback=helpful"
                end if
                if my findIdentifier("meaning-preview-silence") is not missing value then
                    my clickIdentifier("meaning-preview-inspect")
                    my waitIdentifier("meaning-preview-inspect-sheet")
                    tell application "System Events" to key code 53
                    return "result=silence feedback=not-applicable"
                end if
                delay 0.1
            end repeat
            error "CAM_AX_FAILURE:no-bounded-result" number 1002
        else if phase is "disable" then
            my clickIdentifier("meaning-preview-disable")
            my waitIdentifierAbsent("meaning-preview-sidebar")
            my waitIdentifier("assistant-section-assistant")
            return "disable=pass"
        else if phase is "restart" then
            my waitIdentifier("assistant-section-assistant")
            if my findIdentifier("meaning-preview-sidebar") is not missing value then
                error "CAM_AX_FAILURE:preview-visible-after-restart" number 1002
            end if
            return "restart=disabled"
        end if
        error "CAM_AX_FAILURE:unknown-phase" number 1002
    on error errorText number errorNumber
        if errorNumber is -1719 or errorNumber is -1743 or errorText contains "assistive access" or errorText contains "not authorized to send Apple events" then
            error "CAM_AX_TCC_DENIED" number 1001
        end if
        error errorText number errorNumber
    end try
end run
APPLESCRIPT
)"; then
    if [[ "$output" == *"CAM_AX_TCC_DENIED"* ]]; then
      print -u2 \
        "CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED status=unmet reason=ax-or-apple-events-denied"
      exit 77
    fi
    fail "ax-$phase"
  fi
  print "$output"
}

wait_for_source_capture() {
  for _ in {1..100}; do
    if [[ -f "$VAULT_DB" ]]; then
      local source_count
      source_count="$(/usr/bin/sqlite3 "$VAULT_DB" \
        "SELECT COUNT(*) FROM sources;")"
      if [[ "$source_count" == "1" ]]; then
        return
      fi
    fi
    /bin/sleep 0.1
  done
  fail synthetic-capture-not-persisted
}

ordinary_table_fingerprint() {
  local table="$1"
  /usr/bin/sqlite3 "$VAULT_DB" ".dump \"$table\"" \
    | /usr/bin/shasum -a 256 \
    | /usr/bin/awk '{print $1}'
}

ordinary_tables() {
  /usr/bin/sqlite3 "$VAULT_DB" \
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT IN ('audit_events', 'sqlite_sequence') ORDER BY name;"
}

typeset -A ORDINARY_BEFORE

launch_pilot_app
ax_phase capture
wait_for_source_capture

for table in ${(f)"$(ordinary_tables)"}; do
  [[ "$table" == [A-Za-z0-9_]## ]] || fail unexpected-table-name
  ORDINARY_BEFORE[$table]="$(ordinary_table_fingerprint "$table")"
done

ax_phase exercise
assert_no_app_sockets

[[ -f "$MODULE_STATE" ]] || fail module-state-missing
/opt/homebrew/bin/jq -e '
  (.enabledModuleIDs | index("cam.meaning-preview")) != null
  and (.permissionGrants["cam.meaning-preview"] | sort)
    == (["readLocal", "writeLocal"] | sort)
' "$MODULE_STATE" >/dev/null || fail exact-permission-state

[[ -f "$PREVIEW_DB" ]] || fail isolated-state-missing
PREVIEW_STATE_DIGEST="$(/usr/bin/shasum -a 256 "$PREVIEW_DB" \
  | /usr/bin/awk '{print $1}')"

MEANING_AUDIT_COUNT="$(/usr/bin/sqlite3 "$VAULT_DB" \
  "SELECT COUNT(*) FROM audit_events WHERE resource_id LIKE 'meaning-preview:%';")"
[[ "$MEANING_AUDIT_COUNT" -ge 1 ]] || fail audit-receipt-missing
INVALID_AUDIT_COUNT="$(/usr/bin/sqlite3 "$VAULT_DB" \
  "SELECT COUNT(*) FROM audit_events WHERE resource_id LIKE 'meaning-preview:%' AND (operation != 'system' OR status NOT IN ('succeeded','cancelled','denied','failed') OR privacy_decision != 'localOnly' OR payload_sha256 IS NOT NULL OR COALESCE(outbound_byte_count, 0) != 0);")"
[[ "$INVALID_AUDIT_COUNT" == "0" ]] || fail audit-not-status-only
RAW_AUDIT_MARKER_COUNT="$(/usr/bin/sqlite3 "$VAULT_DB" \
  "SELECT COUNT(*) FROM audit_events WHERE COALESCE(resource_id,'') LIKE '%' || '$SYNTHETIC_MARKER' || '%' OR COALESCE(route,'') LIKE '%' || '$SYNTHETIC_MARKER' || '%' OR COALESCE(payload_sha256,'') LIKE '%' || '$SYNTHETIC_MARKER' || '%';")"
[[ "$RAW_AUDIT_MARKER_COUNT" == "0" ]] || fail raw-marker-in-audit

AFTER_TABLES="$(ordinary_tables)"
[[ "$AFTER_TABLES" == "${(j:\n:)${(ok)ORDINARY_BEFORE}}" ]] \
  || fail ordinary-table-set-changed
for table in ${(f)AFTER_TABLES}; do
  [[ "$(ordinary_table_fingerprint "$table")" == "$ORDINARY_BEFORE[$table]" ]] \
    || fail ordinary-table-content-changed
done

ax_phase disable
/opt/homebrew/bin/jq -e '
  (.enabledModuleIDs | index("cam.meaning-preview")) == null
  and (.permissionGrants["cam.meaning-preview"] == null)
' "$MODULE_STATE" >/dev/null || fail disable-state-authority
[[ -f "$PREVIEW_DB" ]] || fail isolated-state-deleted-on-disable
[[ "$(/usr/bin/shasum -a 256 "$PREVIEW_DB" | /usr/bin/awk '{print $1}')" \
    == "$PREVIEW_STATE_DIGEST" ]] || fail isolated-state-mutated-on-disable

graceful_terminate_launched_app
[[ -z "$APP_PID" ]] || fail app-did-not-terminate
launch_pilot_app
ax_phase restart
assert_no_app_sockets
[[ -f "$PREVIEW_DB" ]] || fail isolated-state-deleted-on-restart
[[ "$(/usr/bin/shasum -a 256 "$PREVIEW_DB" | /usr/bin/awk '{print $1}')" \
    == "$PREVIEW_STATE_DIGEST" ]] || fail isolated-state-mutated-on-restart

print \
  "CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED status=pass commit=$EXPECTED_COMMIT resources=exact result=zero-or-one permissions=exact audit=status-only outbound_sockets=0 restart=disabled"
