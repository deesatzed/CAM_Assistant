# Closed CAM Executor Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Execute one enumerated CAM statistics tool through a confined,
bounded, idempotent disposable-state path with typed receipts and deterministic
postconditions.

**Architecture:** Add a typed request/receipt/store and one-tool executor in
`CAMAssistantCore`, expose an explicit CLI command, and leave mining plus
arbitrary commands unavailable. Reuse the existing verified runtime pin,
WAL-consistent snapshotter, and native statistics reader.

**Tech Stack:** Swift 6 strict concurrency, Foundation `Process`, macOS
`sandbox-exec`, CryptoKit SHA-256, SQLite, Swift Testing, atomic JSON files.

---

### Task 1: Freeze the closed request and receipt contract

**Files:**
- Create: `Sources/CAMAssistantCore/CAM/CAMClosedToolExecutor.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

**Steps:**

1. Add a failing test that constructs the single allowed statistics request
   and rejects invalid bounds, keys, and any mismatched runtime identity.
2. Run `swift test --disable-sandbox --scratch-path .swift-build --filter
   CAMClosedTool` and observe the missing-type failure.
3. Add the tool enum, request validation, status-only receipt, and typed error
   definitions with no process execution.
4. Re-run the focused tests and require green.
5. Commit the contract.

### Task 2: Execute one sandboxed disposable tool

**Files:**
- Modify: `Sources/CAMAssistantCore/CAM/CAMClosedToolExecutor.swift`
- Modify: `Sources/CAMAssistantCore/CAM/CAMRuntimeProbe.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

**Steps:**

1. Add failing success, external-write denial, runtime drift, typed-output,
   database-path, and independent-postcondition tests.
2. Run the focused tests and verify they fail because execution is absent.
3. Implement copied config/database preparation, compiled CAM arguments,
   sanitized environment, sandbox profile, bounded file-backed output, typed
   decoding, independent native verification, donor revalidation, and cleanup.
4. Re-run the focused tests and require green.
5. Commit the sandboxed executor.

### Task 3: Add cancellation, timeout, retry, and idempotency

**Files:**
- Modify: `Sources/CAMAssistantCore/CAM/CAMClosedToolExecutor.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

**Steps:**

1. Add failing timeout, cancellation, output-limit, retry-success,
   idempotent-replay, conflicting-key, and cleanup-failure tests.
2. Run the focused tests and verify the intended failures.
3. Implement bounded process termination, the closed retry policy, atomic
   terminal-receipt storage, and replay/conflict handling.
4. Re-run the focused tests and require green.
5. Commit lifecycle and idempotency.

### Task 4: Expose CLI execution and real disposable proof

**Files:**
- Modify: `Sources/CAMAssistantCLI/CAMCommands.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`
- Create: `docs/evidence/task-16-closed-cam-executor.md`

**Steps:**

1. Add a failing CLI test for
   `cam runtime-execute-stats PIN WORKSPACE RECEIPT IDEMPOTENCY_KEY`.
2. Add the explicit command with bounded options and status-only console
   output.
3. Run the focused CLI test and CAM suite.
4. Execute the command against the selected installed CAM runtime and
   disposable app-owned state; save donor hashes, typed counts, sandbox,
   cleanup, and receipt evidence.
5. Commit the CLI and live receipt.

### Task 5: Integrate native state and checkpoint evidence

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/CAMStatusView.swift`
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- Modify: `TASK_QUEUE.md`
- Modify: `PROGRESS.md`
- Modify: `DECISIONS.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json`

**Steps:**

1. Add failing app/accessibility tests for an explicitly labeled live
   disposable tool, cancellation, safe receipt display, and no mining
   authority.
2. Implement current-session-only execution and status controls without
   changing the historical re-pin boundary.
3. Run app, CAM, privacy, backup, and goal-map verification.
4. Run the aggregate and clean-clone verifiers.
5. Commit, push, verify the remote SHA, and record the honest remaining
   durable-recovery/mining limitations.

