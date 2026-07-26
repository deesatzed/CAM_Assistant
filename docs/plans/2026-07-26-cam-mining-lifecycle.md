# CAM Mining Lifecycle Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Represent an exact-approved CAM repository-mining operation as a
native Swift lifecycle with pinned identity, idempotency, cancellation,
receipts, and fail-closed unavailable execution.

**Architecture:** The core stores only typed plan and lifecycle metadata. A
plan binds a repository snapshot and source roots to digests for the intended
CAM runtime, configuration, and database; it exposes expected writes,
verification, and recovery without including raw configuration or source
content. A pure lifecycle can request approval, start only with a matching
approval receipt, cancel, and terminate honestly. The runtime executor remains
explicitly unavailable.

**Tech Stack:** Swift 6.3, Swift Testing, existing `ActionCard`,
`ApprovalStore`, `CAMAdapter`, and synthetic fixtures only.

---

### Task 1: Define a pinned, non-secret mining plan

**Files:**

- Create: `Sources/CAMAssistantCore/CAM/CAMMiningLifecycle.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

1. Write a failing test that rejects missing source roots, non-SHA-256 pinned
   identities, empty idempotency keys, and unbounded repository/time limits.
2. Run `/bin/zsh scripts/verify.sh cam`; expect the lifecycle types to be
   missing.
3. Add immutable `CAMMiningPlan` and `CAMMiningRuntimePin` values that carry
   only repository commit, source-root identifiers, digests, limits, expected
   writes, verification command, and recovery description.
4. Re-run the focused CAM suite.

### Task 2: Add exact-approval and honest lifecycle transitions

**Files:**

- Modify: `Sources/CAMAssistantCore/CAM/CAMMiningLifecycle.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

1. Write a failing test that a plan creates an exact-approval action card and
   cannot start without a consumed matching approval; assert stale plan and
   cancellation paths cannot report success.
2. Implement `CAMMiningLifecycle` states and a pure transition reducer. Bind
   approval to the plan's target, payload digest, and state version through the
   existing `ApprovalStore` contract.
3. Run the focused CAM suite.

### Task 3: Make runtime execution deliberately unavailable and receipted

**Files:**

- Modify: `Sources/CAMAssistantCore/CAM/CAMMiningLifecycle.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`
- Modify: `scripts/verify.sh`

1. Write a failing test proving the executor returns a typed unavailable error
   before reading or invoking any runtime and never manufactures a successful
   receipt.
2. Implement the unavailable executor and a status-only receipt describing
   the terminal reason, idempotency key, and verification command.
3. Run focused CAM tests, then `/bin/zsh scripts/verify.sh all` and
   `git diff --check`.

### Task 4: Save evidence without inflating readiness

**Files:**

- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `docs/evidence/task-09-cam-adapter.md`

1. Record that lifecycle proof is synthetic and non-executing.
2. Explicitly defer live runtime/config/database binding, corpus mutation, and
   external spending until a separate exact-approved integration gate.
3. Record exact current verification output and limitations.
