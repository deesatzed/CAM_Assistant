# Orchestration Ownership Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Ensure only one local process can advance a bounded orchestration run
at a time, with explicit ownership and release semantics.

**Architecture:** A process-local `OrchestrationLeaseStore` uses an advisory
exclusive operating-system file lock keyed by run ID. A `BoundedOrchestrationLoop`
must acquire that ownership before it can replay or append events, and releases
it explicitly or at deinitialization. The lock is process-owned and is released
by the operating system if the owner exits; no network lease, executor, or
remote coordination is introduced.

**Tech Stack:** Swift 6.3, Swift Testing, Foundation, Darwin `open`/`flock`,
existing orchestration event log and reducer.

---

### Task 1: Define local ownership and prove contention

**Files:**

- Modify: `Tests/CAMAssistantCoreTests/CoordinationTests.swift`
- Modify: `Sources/CAMAssistantCore/Coordination/OrchestrationState.swift`

1. Write a failing test that acquires a run lease in one store and proves a
   second store cannot acquire it; release then permits the second owner.
2. Run `/bin/zsh scripts/verify.sh coordination`; expect the lease type to be
   absent.
3. Add a typed lease and an exclusive OS file-lock store with safe run-ID
   naming, exact owner checks, release, and cleanup.
4. Re-run the focused coordination suite.

### Task 2: Bind the bounded loop to ownership

**Files:**

- Modify: `Tests/CAMAssistantCoreTests/CoordinationTests.swift`
- Modify: `Sources/CAMAssistantCore/Coordination/OrchestrationState.swift`

1. Write a failing test that one loop owner blocks another loop for the same
   run, and that explicit release permits recovery by the successor owner.
2. Run `/bin/zsh scripts/verify.sh coordination`; expect ownership integration
   to be absent.
3. Require an active lease at loop initialization and before `run`; release
   ownership on request and in deinitialization.
4. Re-run focused coordination and aggregate verification.

### Task 3: Record the proof boundary

**Files:**

- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `REVIEW.md`

1. Record that local OS ownership is proven but remote/multi-machine leases,
   snapshots, and execution remain deferred.
2. Run `git diff --check` after documentation updates.
