#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIR:h:h}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cam-meaning-preview-packaged.XXXXXX")"
CLONE_ROOT="$TEST_ROOT/source"
PACKAGE_SCRIPT="$CLONE_ROOT/scripts/package-app.sh"
BUILD_DIR="$CLONE_ROOT/.swift-build"
SOURCE_MANIFEST_DIRECTORY="$CLONE_ROOT/Modules/Core"
PACKAGED_APP="$CLONE_ROOT/artifacts/CAM Assistant.app"
SOURCE_MANIFEST="$CLONE_ROOT/Modules/Core/meaning-preview.json"
SOURCE_REPORT="$CLONE_ROOT/docs/evidence/add2cam-09-named-model-report.json"
PILOT_APP="$TEST_ROOT/CAM Assistant.app"
PILOT_EXECUTABLE="$PILOT_APP/Contents/MacOS/CAMAssistant"
AX_DRIVER="$TEST_ROOT/meaning-preview-ax-driver"
SUPPORT_ROOT="$TEST_ROOT/application-support"
VAULT_ROOT="$SUPPORT_ROOT/CAMAssistant"
WATCH_DIRECTORY="$TEST_ROOT/watched-source"
WATCH_FILE="$WATCH_DIRECTORY/synthetic-pilot.txt"
VAULT_DB="$VAULT_ROOT/vault.sqlite"
MODULE_STATE="$VAULT_ROOT/module-state.json"
PREVIEW_DB="$VAULT_ROOT/meaning-preview/MeaningPreview.sqlite"
SYNTHETIC_DERIVED_TEXT="A synthetic local pilot note records one bounded community errand."
APP_PID=""
BUILD_MODE=""
SOURCE_MANIFEST_MODE=""
BUILD_WAS_RESTRICTED="false"
SOURCE_MANIFEST_WAS_RESTRICTED="false"

bound_app_pid() {
  /usr/bin/osascript -l JavaScript - "$PILOT_EXECUTABLE" <<'JXA'
ObjC.import("AppKit")
function run(argv) {
    const expected = argv[0]
    return $.NSRunningApplication.runningApplicationsWithBundleIdentifier(
        "com.deesatzed.cam-assistant"
    ).js.filter(application => {
        const url = application.executableURL
        return url && ObjC.unwrap(url.path) === expected
    }).map(application => String(application.processIdentifier)).join("\n")
}
JXA
}

graceful_terminate_launched_app() {
  if [[ -z "$APP_PID" ]]; then
    return
  fi
  /usr/bin/perl -e 'alarm shift; exec @ARGV' 5 \
    /usr/bin/osascript -l JavaScript - "$APP_PID" "$PILOT_EXECUTABLE" \
    >/dev/null 2>&1 <<'JXA' || true
ObjC.import("AppKit")
function run(argv) {
    const wantedPID = Number(argv[0])
    const expected = argv[1]
    const applications = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(
        "com.deesatzed.cam-assistant"
    ).js
    applications.forEach(application => {
        const url = application.executableURL
        if (Number(application.processIdentifier) === wantedPID
            && url && ObjC.unwrap(url.path) === expected) {
            application.terminate
        }
    })
}
JXA
  for _ in {1..50}; do
    if [[ "$(bound_app_pid)" != "$APP_PID" ]]; then
      APP_PID=""
      return
    fi
    /bin/sleep 0.1
  done
}

cleanup() {
  graceful_terminate_launched_app
  if [[ -n "$APP_PID" ]]; then
    print -u2 \
      "CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED cleanup=preserved reason=app-still-running"
    return
  fi
  if [[ "$BUILD_WAS_RESTRICTED" == "true" ]]; then
    chmod "$BUILD_MODE" "$BUILD_DIR" || true
    BUILD_WAS_RESTRICTED="false"
  fi
  if [[ "$SOURCE_MANIFEST_WAS_RESTRICTED" == "true" ]]; then
    chmod "$SOURCE_MANIFEST_MODE" "$SOURCE_MANIFEST_DIRECTORY" || true
    SOURCE_MANIFEST_WAS_RESTRICTED="false"
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

EXPECTED_COMMIT="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
git clone --quiet --local --no-hardlinks "$REPOSITORY_ROOT" "$CLONE_ROOT"
[[ -d "$CLONE_ROOT/.git" ]] || fail disposable-clone-missing
[[ "$(git -C "$CLONE_ROOT" rev-parse HEAD)" == "$EXPECTED_COMMIT" ]] \
  || fail disposable-clone-identity
[[ -z "$(git -C "$CLONE_ROOT" status --porcelain)" ]] \
  || fail disposable-clone-not-clean

"$PACKAGE_SCRIPT" >/dev/null
cp -R "$PACKAGED_APP" "$PILOT_APP"
PILOT_APP="${PILOT_APP:A}"
PILOT_EXECUTABLE="$PILOT_APP/Contents/MacOS/CAMAssistant"

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

if git -C "$CLONE_ROOT" ls-files --error-unmatch \
    "docs/evidence/add2cam-09-named-model-report.json" >/dev/null 2>&1; then
  [[ -f "$PACKAGED_REPORT" ]] || fail named-model-report-missing
  /usr/bin/cmp -s "$SOURCE_REPORT" "$PACKAGED_REPORT" \
    || fail named-model-report-byte-drift
else
  [[ ! -e "$PACKAGED_REPORT" ]] || fail uncommitted-named-model-report-packaged
fi

BUILD_MODE="$(/usr/bin/stat -f %Lp "$BUILD_DIR")"
SOURCE_MANIFEST_MODE="$(/usr/bin/stat -f %Lp "$SOURCE_MANIFEST_DIRECTORY")"
chmod 000 "$BUILD_DIR"
BUILD_WAS_RESTRICTED="true"
chmod 000 "$SOURCE_MANIFEST_DIRECTORY"
SOURCE_MANIFEST_WAS_RESTRICTED="true"

launch_pilot_app() {
  /usr/bin/open -n "$PILOT_APP" --env \
    "CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT=$SUPPORT_ROOT"
  for _ in {1..100}; do
    APP_PID="$(bound_app_pid)"
    if [[ "$APP_PID" == <-> ]]; then
      return
    fi
    [[ "$APP_PID" != *$'\n'* ]] || fail app-launch-ambiguous
    /bin/sleep 0.1
  done
  fail app-launch-timeout
}

assert_no_app_sockets() {
  local socket_status
  /usr/sbin/lsof -nP -p "$APP_PID" >/dev/null 2>&1 \
    || fail lsof-process-inspection
  set +e
  /usr/sbin/lsof -nP -a -p "$APP_PID" -i >/dev/null 2>&1
  socket_status=$?
  set -e
  if [[ "$socket_status" -eq 0 ]]; then
    fail app-network-socket-observed
  fi
  [[ "$socket_status" -eq 1 ]] || fail lsof-socket-inspection
}

build_ax_driver() {
  mkdir -p "$TEST_ROOT/ax-module-cache"
  /usr/bin/swiftc \
    -module-cache-path "$TEST_ROOT/ax-module-cache" \
    -framework AppKit \
    -framework ApplicationServices \
    -o "$AX_DRIVER" - <<'SWIFT'
import AppKit
import ApplicationServices
import Darwin
import Foundation

private enum DriverError: Error {
    case missing(String)
    case disabled(String)
    case unexpected(String)
    case action(String)

    var token: String {
        switch self {
        case .missing(let value): "missing-\(value)"
        case .disabled(let value): "disabled-\(value)"
        case .unexpected(let value): "unexpected-\(value)"
        case .action(let value): "action-\(value)"
        }
    }
}

private enum AXAccessError: Error { case denied }

private func finish(_ code: Int32, _ token: String) -> Never {
    FileHandle.standardError.write(Data((token + "\n").utf8))
    Darwin.exit(code)
}

private func copyAttribute(
    _ element: AXUIElement,
    _ attribute: CFString
) throws -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute, &value)
    switch result {
    case .success:
        return value
    case .apiDisabled:
        throw AXAccessError.denied
    case .cannotComplete, .invalidUIElement:
        throw DriverError.action("ax-index-incomplete")
    case .attributeUnsupported, .noValue:
        return nil
    default:
        throw DriverError.action("ax-index-incomplete")
    }
}

private func stringAttribute(
    _ element: AXUIElement,
    _ attribute: CFString
) throws -> String? {
    try copyAttribute(element, attribute) as? String
}

private func boolAttribute(
    _ element: AXUIElement,
    _ attribute: CFString
) throws -> Bool? {
    try copyAttribute(element, attribute) as? Bool
}

private func elementsAttribute(
    _ element: AXUIElement,
    _ attribute: CFString
) throws -> [AXUIElement] {
    (try copyAttribute(element, attribute) as? [AXUIElement]) ?? []
}

private struct AXIndex {
    let elements: [AXUIElement]

    init(application: AXUIElement) throws {
        let relationAttributes: [CFString] = [
            kAXChildrenAttribute as CFString,
            kAXVisibleChildrenAttribute as CFString,
            kAXRowsAttribute as CFString,
            kAXContentsAttribute as CFString,
            "AXChildrenInNavigationOrder" as CFString,
        ]
        var queue = try elementsAttribute(application, kAXWindowsAttribute as CFString)
            .map { ($0, 0) }
        var cursor = 0
        var seen: [CFHashCode: [AXUIElement]] = [:]
        var result: [AXUIElement] = []
        while cursor < queue.count && result.count < 4_000 {
            let (element, depth) = queue[cursor]
            cursor += 1
            let identity = CFHash(element)
            if seen[identity, default: []].contains(where: {
                CFEqual($0, element)
            }) { continue }
            seen[identity, default: []].append(element)
            result.append(element)
            var descendants: [AXUIElement] = []
            for relation in relationAttributes {
                descendants.append(contentsOf: try elementsAttribute(element, relation))
            }
            if depth >= 24 && !descendants.isEmpty {
                throw DriverError.action("ax-depth-cap")
            }
            for child in descendants {
                queue.append((child, depth + 1))
            }
        }
        if cursor < queue.count {
            throw DriverError.action("ax-node-cap")
        }
        elements = result
    }

    func identifier(_ value: String) throws -> AXUIElement? {
        for element in elements where
            try stringAttribute(element, kAXIdentifierAttribute as CFString) == value {
            return element
        }
        return nil
    }

    func named(_ value: String, role: String? = nil) throws -> AXUIElement? {
        for element in elements {
            if let role,
               try stringAttribute(element, kAXRoleAttribute as CFString) != role {
                continue
            }
            let names = try [
                stringAttribute(element, kAXTitleAttribute as CFString),
                stringAttribute(element, kAXDescriptionAttribute as CFString),
                stringAttribute(element, kAXValueAttribute as CFString),
            ]
            if names.compactMap({ $0 }).contains(value) { return element }
        }
        return nil
    }
}

private final class Driver {
    let application: AXUIElement

    init(pid: pid_t) throws {
        guard AXIsProcessTrusted() else { throw AXAccessError.denied }
        guard CGPreflightPostEventAccess() else { throw AXAccessError.denied }
        application = AXUIElementCreateApplication(pid)
        NSRunningApplication(processIdentifier: pid)?.activate(
            options: []
        )
        let deadline = Date().addingTimeInterval(12)
        repeat {
            if !(try elementsAttribute(
                application,
                kAXWindowsAttribute as CFString
            )).isEmpty { return }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        throw DriverError.missing("app-window")
    }

    func waitIdentifier(_ value: String, timeout: TimeInterval = 12) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let result = try AXIndex(application: application).identifier(value) {
                return result
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        throw DriverError.missing(value)
    }

    func waitNamed(
        _ value: String,
        role: String? = nil,
        timeout: TimeInterval = 12
    ) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let result = try AXIndex(application: application).named(value, role: role) {
                return result
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        let token = value.lowercased().map { character in
            character.isLetter || character.isNumber ? String(character) : "-"
        }.joined()
        throw DriverError.missing("named-\(token)")
    }

    func waitEnabled(_ value: String) throws -> AXUIElement {
        let deadline = Date().addingTimeInterval(12)
        repeat {
            if let anchor = try AXIndex(application: application).identifier(value),
               let button = try ancestor(anchor, role: kAXButtonRole as String),
               try boolAttribute(button, kAXEnabledAttribute as CFString) == true {
                return button
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        throw DriverError.disabled(value)
    }

    func assertAbsent(_ value: String) throws {
        if try AXIndex(application: application).identifier(value) != nil {
            throw DriverError.unexpected(value)
        }
    }

    func waitAbsent(_ value: String) throws {
        let deadline = Date().addingTimeInterval(12)
        repeat {
            if try AXIndex(application: application).identifier(value) == nil { return }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        throw DriverError.unexpected(value)
    }

    func press(_ element: AXUIElement, token: String) throws {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if result == .apiDisabled {
            throw AXAccessError.denied
        }
        guard result == .success else { throw DriverError.action(token) }
    }

    func pressIdentifier(_ value: String) throws {
        let anchor = try waitIdentifier(value)
        guard let button = try ancestor(anchor, role: kAXButtonRole as String) else {
            throw DriverError.missing("button-\(value)")
        }
        try press(button, token: value)
    }

    func ancestor(_ start: AXUIElement, role: String) throws -> AXUIElement? {
        var element = start
        for _ in 0..<12 {
            if try stringAttribute(element, kAXRoleAttribute as CFString) == role {
                return element
            }
            guard let parentValue = try copyAttribute(
                element,
                kAXParentAttribute as CFString
            ), CFGetTypeID(parentValue) == AXUIElementGetTypeID() else {
                return nil
            }
            element = unsafeBitCast(parentValue, to: AXUIElement.self)
        }
        return nil
    }

    func selectSidebar(_ identifier: String) throws {
        let anchor = try waitIdentifier(identifier)
        guard let element = try ancestor(anchor, role: kAXRowRole as String) else {
            throw DriverError.missing("sidebar-row")
        }
                var settable = DarwinBoolean(false)
                let check = AXUIElementIsAttributeSettable(
                    element,
                    kAXSelectedAttribute as CFString,
                    &settable
                )
                if check == .apiDisabled { throw AXAccessError.denied }
                guard check == .success, settable.boolValue else {
                    throw DriverError.action("sidebar-row-selection")
                }
                let selected = AXUIElementSetAttributeValue(
                    element,
                    kAXSelectedAttribute as CFString,
                    kCFBooleanTrue
                )
                if selected == .apiDisabled { throw AXAccessError.denied }
                guard selected == .success else {
                    throw DriverError.action("sidebar-row-selection")
                }
    }

    func key(_ code: CGKeyCode) throws {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        else { throw DriverError.action("keyboard") }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.15)
    }
}

private func capture(_ driver: Driver) throws {
    _ = try driver.waitIdentifier("assistant-section-assistant")
    _ = try driver.waitIdentifier("assistant-section-settings")
    try driver.assertAbsent("meaning-preview-sidebar")
    guard let text = ProcessInfo.processInfo.environment[
              "CAM_PILOT_SYNTHETIC_DERIVED_TEXT"
          ],
          let path = ProcessInfo.processInfo.environment[
              "CAM_PILOT_WATCH_FILE"
          ] else { throw DriverError.missing("synthetic-input") }
    Thread.sleep(forTimeInterval: 1)
    try Data(text.utf8).write(to: URL(filePath: path), options: .atomic)
    _ = try driver.waitNamed(
        "Watched folder captured and indexed content locally."
    )
}

private func exercise(_ driver: Driver) throws -> String {
    try driver.selectSidebar("assistant-section-settings")
    try driver.pressIdentifier("meaning-preview-settings-open")
    try driver.pressIdentifier("meaning-preview-enable")
    _ = try driver.waitIdentifier("meaning-preview-grant")
    _ = try driver.waitIdentifier("meaning-preview-sidebar")
    try driver.assertAbsent("meaning-preview-request")
    try driver.key(53)
    try driver.selectSidebar("meaning-preview-sidebar")
    _ = try driver.waitIdentifier("meaning-preview-permission-state")
    try driver.pressIdentifier("meaning-preview-grant")
    let picker = try driver.waitIdentifier("meaning-preview-source-picker")
    try driver.press(picker, token: "source-picker")
    try driver.key(125)
    try driver.key(36)
    try driver.press(try driver.waitEnabled("meaning-preview-request"), token: "request")
    _ = try driver.waitIdentifier("meaning-preview-reflect-unavailable")

    let deadline = Date().addingTimeInterval(12)
    repeat {
        let index = try AXIndex(application: driver.application)
        if try index.identifier("meaning-preview-card") != nil {
            for identifier in [
                "meaning-preview-inspect", "meaning-preview-now",
                "meaning-preview-later", "meaning-preview-release",
                "meaning-preview-helpful", "meaning-preview-not-helpful",
            ] { _ = try driver.waitIdentifier(identifier) }
            try driver.pressIdentifier("meaning-preview-inspect")
            _ = try driver.waitIdentifier("meaning-preview-inspect-sheet")
            try driver.key(53)
            try driver.pressIdentifier("meaning-preview-now")
            _ = try driver.waitNamed("Now recorded in isolated Preview state.")
            try driver.press(try driver.waitEnabled("meaning-preview-request"), token: "second-request")
            _ = try driver.waitIdentifier("meaning-preview-card")
            try driver.pressIdentifier("meaning-preview-helpful")
            _ = try driver.waitNamed("Helpful recorded explicitly in isolated Preview state.")
            return "result=card action=now feedback=helpful"
        }
        if try index.identifier("meaning-preview-silence") != nil {
            try driver.pressIdentifier("meaning-preview-inspect")
            _ = try driver.waitIdentifier("meaning-preview-inspect-sheet")
            try driver.key(53)
            return "result=silence action=not-applicable feedback=not-applicable"
        }
        Thread.sleep(forTimeInterval: 0.1)
    } while Date() < deadline
    throw DriverError.missing("bounded-result")
}

do {
    guard CommandLine.arguments.count == 2,
          let pidText = ProcessInfo.processInfo.environment["CAM_PILOT_APP_PID"],
          let pid = pid_t(pidText)
    else { throw DriverError.missing("arguments") }
    let driver = try Driver(pid: pid)
    switch CommandLine.arguments[1] {
    case "capture":
        try capture(driver)
        print("capture=pass")
    case "exercise":
        print(try exercise(driver))
    case "disable":
        try driver.pressIdentifier("meaning-preview-disable")
        try driver.waitAbsent("meaning-preview-sidebar")
        _ = try driver.waitIdentifier("assistant-section-assistant")
        print("disable=pass")
    case "restart":
        _ = try driver.waitIdentifier("assistant-section-assistant")
        try driver.assertAbsent("meaning-preview-sidebar")
        print("restart=disabled")
    default:
        throw DriverError.missing("phase")
    }
} catch is AXAccessError {
    finish(77, "CAM_AX_TCC_DENIED")
} catch let error as DriverError {
    finish(1, "CAM_AX_FAILURE:\(error.token)")
} catch {
    finish(1, "CAM_AX_FAILURE:unclassified")
}
SWIFT
}

native_ax_phase() {
  local phase="$1"
  local output
  local ax_status
  [[ "$(bound_app_pid)" == "$APP_PID" ]] || fail app-identity-drift
  export CAM_PILOT_APP_PID="$APP_PID"
  export CAM_PILOT_SYNTHETIC_DERIVED_TEXT="$SYNTHETIC_DERIVED_TEXT"
  export CAM_PILOT_WATCH_FILE="$WATCH_FILE"
  set +e
  output="$(/usr/bin/perl -e 'alarm shift; exec @ARGV' 45 \
    "$AX_DRIVER" "$phase" 2>&1)"
  ax_status=$?
  set -e
  if [[ "$ax_status" -eq 77 || "$output" == *"CAM_AX_TCC_DENIED"* ]]; then
    print -u2 \
      "CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED status=unmet reason=ax-or-apple-events-denied"
    exit 77
  fi
  if [[ "$ax_status" -ne 0 ]]; then
    if [[ "$ax_status" -ge 128 && -z "$output" ]]; then
      fail "ax-$phase-timeout"
    fi
    if [[ "$output" == *"CAM_AX_FAILURE:"* ]]; then
      local detail="${output#*CAM_AX_FAILURE:}"
      detail="${detail%% *}"
      fail "ax-$phase-$detail"
    fi
    fail "ax-$phase-unclassified"
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

prepare_watched_source() {
  mkdir -p "$VAULT_ROOT" "$WATCH_DIRECTORY"
  /usr/bin/printf \
    '[{"id":"00000000-0000-4000-8000-000000000050","canonicalPath":"%s","isEnabled":true}]' \
    "$WATCH_DIRECTORY" > "$VAULT_ROOT/watched-sources.json"
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

decoded_preview_digest() {
  /usr/bin/sqlite3 "$PREVIEW_DB" \
    "SELECT snapshot_json FROM meaning_preview_state WHERE singleton = 1;" \
    | /usr/bin/base64 -D \
    | /usr/bin/shasum -a 256 \
    | /usr/bin/awk '{print $1}'
}

assert_ordinary_unchanged() {
  local after_tables="$(ordinary_tables)"
  [[ "$after_tables" == "${(j:\n:)${(ok)ORDINARY_BEFORE}}" ]] \
    || fail ordinary-table-set-changed
  for table in ${(f)after_tables}; do
    [[ "$(ordinary_table_fingerprint "$table")" \
        == "$ORDINARY_BEFORE[$table]" ]] \
      || fail ordinary-table-content-changed
  done
}

postflight_git_state() {
  [[ "$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)" == "$EXPECTED_COMMIT" ]] \
    || fail root-head-drift
  [[ -z "$(git -C "$REPOSITORY_ROOT" status --porcelain)" ]] \
    || fail root-worktree-drift
  [[ "$(git -C "$CLONE_ROOT" rev-parse HEAD)" == "$EXPECTED_COMMIT" ]] \
    || fail clone-head-drift
  [[ -z "$(git -C "$CLONE_ROOT" status --porcelain)" ]] \
    || fail clone-worktree-drift
}

typeset -A ORDINARY_BEFORE

prepare_watched_source
build_ax_driver
launch_pilot_app
native_ax_phase capture
wait_for_source_capture

for table in ${(f)"$(ordinary_tables)"}; do
  [[ "$table" =~ '^[A-Za-z0-9_]+$' ]] || fail unexpected-table-name
  ORDINARY_BEFORE[$table]="$(ordinary_table_fingerprint "$table")"
done

EXERCISE_RESULT="$(native_ax_phase exercise)"
print "$EXERCISE_RESULT"
[[ "$EXERCISE_RESULT" == *"result=card action=now feedback=helpful"* ]] \
  || fail synthetic-result-not-actionable
assert_no_app_sockets

[[ -f "$MODULE_STATE" ]] || fail module-state-missing
/opt/homebrew/bin/jq -e '
  (.enabledModuleIDs | index("cam.meaning-preview")) != null
  and (.permissionGrants["cam.meaning-preview"] | sort)
    == (["readLocal", "writeLocal"] | sort)
' "$MODULE_STATE" >/dev/null || fail exact-permission-state

[[ -f "$PREVIEW_DB" ]] || fail isolated-state-missing
PREVIEW_STATE_DIGEST="$(decoded_preview_digest)"

MEANING_AUDIT_COUNT="$(/usr/bin/sqlite3 "$VAULT_DB" \
  "SELECT COUNT(*) FROM audit_events WHERE resource_id LIKE 'meaning-preview:%';")"
[[ "$MEANING_AUDIT_COUNT" -ge 1 ]] || fail audit-receipt-missing
INVALID_AUDIT_COUNT="$(/usr/bin/sqlite3 "$VAULT_DB" \
  "SELECT COUNT(*) FROM audit_events WHERE resource_id LIKE 'meaning-preview:%' AND (operation != 'system' OR status NOT IN ('succeeded','cancelled','denied','failed') OR privacy_decision != 'localOnly' OR payload_sha256 IS NOT NULL OR COALESCE(outbound_byte_count, 0) != 0);")"
[[ "$INVALID_AUDIT_COUNT" == "0" ]] || fail audit-not-status-only
RAW_AUDIT_MARKER_COUNT="$(/usr/bin/sqlite3 "$VAULT_DB" \
  "SELECT COUNT(*) FROM audit_events WHERE COALESCE(resource_id,'') LIKE '%' || '$SYNTHETIC_DERIVED_TEXT' || '%' OR COALESCE(route,'') LIKE '%' || '$SYNTHETIC_DERIVED_TEXT' || '%' OR COALESCE(payload_sha256,'') LIKE '%' || '$SYNTHETIC_DERIVED_TEXT' || '%';")"
[[ "$RAW_AUDIT_MARKER_COUNT" == "0" ]] || fail raw-marker-in-audit
ACTION_AUDIT_COUNT="$(/usr/bin/sqlite3 "$VAULT_DB" \
  "SELECT COUNT(*) FROM audit_events WHERE resource_id LIKE 'meaning-preview:%' AND route = 'now';")"
FEEDBACK_AUDIT_COUNT="$(/usr/bin/sqlite3 "$VAULT_DB" \
  "SELECT COUNT(*) FROM audit_events WHERE resource_id LIKE 'meaning-preview:%' AND route = 'helpful';")"
[[ "$ACTION_AUDIT_COUNT" -ge 1 ]] || fail action-audit-missing
[[ "$FEEDBACK_AUDIT_COUNT" -ge 1 ]] || fail feedback-audit-missing

assert_ordinary_unchanged

native_ax_phase disable
/opt/homebrew/bin/jq -e '
  (.enabledModuleIDs | index("cam.meaning-preview")) == null
  and (.permissionGrants["cam.meaning-preview"] == null)
' "$MODULE_STATE" >/dev/null || fail disable-state-authority
[[ -f "$PREVIEW_DB" ]] || fail isolated-state-deleted-on-disable
[[ "$(decoded_preview_digest)" \
    == "$PREVIEW_STATE_DIGEST" ]] || fail isolated-state-mutated-on-disable
assert_ordinary_unchanged

graceful_terminate_launched_app
[[ -z "$APP_PID" ]] || fail app-did-not-terminate
launch_pilot_app
native_ax_phase restart
assert_no_app_sockets
[[ -f "$PREVIEW_DB" ]] || fail isolated-state-deleted-on-restart
[[ "$(decoded_preview_digest)" \
    == "$PREVIEW_STATE_DIGEST" ]] || fail isolated-state-mutated-on-restart
assert_ordinary_unchanged
postflight_git_state

print \
  "CAM_ASSISTANT_MEANING_PREVIEW_PACKAGED status=pass commit=$EXPECTED_COMMIT resources=exact result=card action=now feedback=helpful permissions=exact audit=status-only audit_outbound_bytes=0 sockets_point_in_time=0 restart=disabled"
