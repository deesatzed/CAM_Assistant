# Mac Care Reversible Organization Action Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Add one exact-approved, reversible `moveOneSelectedFile` Mac Care action that is fully proven in disposable roots before it is exposed in the native app.

**Architecture:** A new `MacCareOrganizationAction` core component accepts only a prepared plan bound to one canonical root and a consumed `ActionCard` approval. It stores status-only receipts under the app-owned vault root, checks source/destination state both before and after a single move, and performs verified undo with no automatic target selection.

**Tech Stack:** Swift 6.3, Foundation/FileManager, CryptoKit, existing `ActionCard`/`ApprovalStore`, Swift Testing, SwiftUI.

---

### Task 1: Freeze status-only planning and receipt values

**Files:**
- Create: `Sources/CAMAssistantCore/MacCare/MacCareOrganizationAction.swift`
- Modify: `Sources/CAMAssistantCore/Storage/LocalVaultPaths.swift`
- Modify: `Tests/CAMAssistantCoreTests/MacCareTests.swift`

1. Write failing tests for a plan that accepts one regular non-symlink fixture file, one existing fixture destination directory, a safe optional replacement name, and rejects traversal, symlinks, directories, cross-root paths, and an existing destination.
2. Run `/bin/zsh scripts/verify.sh mac-care`; observe missing action-plan types.
3. Add `MacCareOrganizationPlan`, relative target identifiers, SHA-256/byte-count precondition, explicit state revision, `ActionCard` builder, and Codable status-only receipt values. Add `mac-care-actions.json` to `LocalVaultStateFile`.
4. Run the focused suite and commit the contract.

### Task 2: Require exact approval and execute one bounded move

**Files:**
- Modify: `Sources/CAMAssistantCore/MacCare/MacCareOrganizationAction.swift`
- Modify: `Tests/CAMAssistantCoreTests/MacCareTests.swift`

1. Write failing tests that an unapproved, expired, reused, stale-source, changed-source, or destination-conflict plan cannot move a file or report success.
2. Add `MacCareOrganizationExecutor.execute`, consuming the existing `ApprovalStore` exact binding before a move. Create an action-local status-only receipt only after state checks.
3. Verify source absence, destination regular-file identity, and planned digest/byte count after the move; save only action ID, digests, counts, state/version, status, approval ID, and timestamps.
4. Run `mac-care` and commit the execution boundary.

### Task 3: Add cancellation, restart-safe receipt, and verified undo

**Files:**
- Modify: `Sources/CAMAssistantCore/MacCare/MacCareOrganizationAction.swift`
- Modify: `Tests/CAMAssistantCoreTests/MacCareTests.swift`

1. Write failing tests for pre-move cancellation, receipt reload after restart, successful undo, changed-destination refusal, and reoccupied-origin refusal.
2. Implement a cooperative cancellation check before the move, atomic receipt persistence, receipt loading, and undo that revalidates the moved file and original vacancy before moving it back.
3. Confirm every failure leaves the expected file state and no status becomes verified incorrectly.
4. Run focused tests and commit.

### Task 4: Add an explicit native review journey

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/MacCareView.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift` only if required by the view API
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- Create/modify: `Tests/CAMAssistantAppTests/MacCareActionAppModelTests.swift`

1. Write failing source-contract/AppModel tests for user-selected source/destination/name, explicit preview, exact approval state, apply/cancel/error/result/undo controls, and accessible labels that state no automatic organization occurs.
2. Add a fixture-injectable AppModel action store/executor. Normal UI begins with no target and cannot construct a plan from assessment counts or model output.
3. Present relative labels and status-only receipts; do not display a raw path in audit history. Keep read-only assessment independent.
4. Run app and Mac Care suites, then commit.

### Task 5: Prove and publish the fixture-only vertical slice

**Files:**
- Create: `docs/evidence/task-17-reversible-organization-action.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json` only if current proof warrants it

1. Run `git diff --check`, `./scripts/verify.sh mac-care`, `./scripts/verify.sh app`, and `./scripts/verify.sh goal-map`.
2. Run the complete aggregate and fresh-clone verifier once after the slice is coherent.
3. Record fixture-only scope, action boundaries, no-live-user-file proof, exact undo behavior, remaining duplicate/organization assessment gaps, and the absent packaged GUI proof if it is not completed.
4. Commit, push, verify the remote commit, and tag a checkpoint only if all verification passes.
