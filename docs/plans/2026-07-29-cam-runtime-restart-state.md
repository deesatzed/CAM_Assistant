# CAM Runtime Restart State Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Persist the latest CAM runtime pin and disposable-probe receipt across
ordinary app restart while requiring a fresh current-session pin before another
probe.

**Architecture:** Add a small schema-versioned atomic JSON store in
`CAMAssistantCore`. The native CAM view loads it as historical evidence,
persists fresh pins and terminal receipts, and keeps probe authority disabled
until the runtime is freshly derived in the current process.

**Tech Stack:** Swift 6, Foundation `Codable`, atomic file replacement, Swift
Testing, SwiftUI source-contract tests.

---

### Task 1: Core restart-state contract

**Files:**
- Create: `Tests/CAMAssistantCoreTests/CAMRuntimeRestartStateTests.swift`
- Create: `Sources/CAMAssistantCore/CAM/CAMRuntimeRestartState.swift`

**Step 1: Write the failing tests**

Add tests that construct a valid synthetic schema-v2 pin and terminal receipt,
then require:

- store recreation to load the same pin and receipt;
- a replacement pin to clear the stale receipt;
- a mismatched receipt identity to throw without changing saved state;
- malformed and unsupported-schema files to fail closed.

**Step 2: Run the tests and verify red**

Run:

```bash
swift test --filter CAMRuntimeRestartState
```

Expected: compile failure because `CAMRuntimeRestartStateStore` is absent.

**Step 3: Implement the minimal store**

Create public `CAMRuntimeRestartState`, `CAMRuntimeRestartStateStore`, and typed
errors. Use `CAMVerifiedRuntimePin.decode` to revalidate decoded pin material.
Validate receipt schema, fixed tool identity, runtime identity binding, terminal
status, and timestamps. Write sorted JSON atomically after creating only the
parent directory. Expose `load()`, `save(pin:updatedAt:)`, and
`save(receipt:for:updatedAt:)`.

**Step 4: Run the tests and verify green**

Run:

```bash
swift test --filter CAMRuntimeRestartState
```

Expected: all restart-state tests pass.

### Task 2: Native historical restoration

**Files:**
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- Modify: `Sources/CAMAssistantApp/Views/CAMStatusView.swift`

**Step 1: Write the failing source-contract test**

Require the CAM view to load `cam-runtime-history.json`, label restored state as
historical, retain a `runtimePinIsCurrentSession` gate, disable the disposable
probe until re-pin, and persist successful pin and terminal receipt state.

**Step 2: Run the test and verify red**

Run:

```bash
swift test --filter AccessibilityViewContractTests
```

Expected: failure because restart-state integration markers are absent.

**Step 3: Implement the minimal native integration**

Load once on `.task`, prefill selected URLs, restore the pin/receipt, and mark
the pin historical. Persist after a successful fresh pin and after any terminal
probe receipt. Disable the probe for historical state and explain the required
revalidation. Preserve generation/cancellation guards so stale async
completions cannot overwrite restored or newly selected state.

**Step 4: Run the app tests and verify green**

Run:

```bash
/bin/zsh scripts/verify.sh app
```

Expected: all app tests pass.

### Task 3: Backup-boundary regression

**Files:**
- Modify: `Tests/CAMAssistantCoreTests/FullVaultBackupTests.swift`

**Step 1: Write the failing boundary assertion**

Create `cam-runtime-history.json` beside recognized vault state and require the
package manifest not to include it.

**Step 2: Run the focused backup test**

Run:

```bash
/bin/zsh scripts/verify.sh backup
```

Expected: the new assertion passes against the intentional existing exclusion;
if it already passes immediately, retain it as a regression proof because no
production backup change is required.

### Task 4: Evidence and checkpoint

**Files:**
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Create: `docs/evidence/task-16-cam-runtime-restart-state.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json` only if the proof
  changes an honest gate verdict.

**Step 1: Run focused verification**

Run CAM, app, and backup verification. Require all tests green.

**Step 2: Run aggregate verification**

Run:

```bash
CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all
```

Require the goal-map validator, tests, release builds, reproducibility, privacy,
and offline smoke to pass.

**Step 3: Record exact evidence**

Document test counts, scope, backup exclusion, and the explicit boundary that
no live CAM process or mining executor exists.

**Step 4: Commit and push**

Run `git diff --check`, commit one coherent checkpoint, push
`agent/portable-canonical-repo`, and verify the remote branch SHA.
