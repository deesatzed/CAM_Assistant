# Orchestration Snapshots Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Add versioned, restart-safe orchestration snapshots that accelerate
resume without becoming an alternate authority to the append-only event log.

**Architecture:** A snapshot carries a derived run state, event count, and
SHA-256 digest of canonically encoded events. The event log creates snapshots
only by replaying its current events; resume validates the run ID, count,
digest, and reducer replay before accepting the cached state. The persisted
snapshot file uses atomic writes and a versioned envelope. No event compaction
or source deletion occurs in this phase.

**Tech Stack:** Swift 6.3, Swift Testing, Foundation, CryptoKit, existing
`OrchestrationEventLog` and `OrchestrationReducer`.

---

### Task 1: Derive and validate a snapshot from events

**Files:**

- Modify: `Tests/CAMAssistantCoreTests/CoordinationTests.swift`
- Modify: `Sources/CAMAssistantCore/Coordination/OrchestrationState.swift`

1. Write a failing test that appends two events, creates a snapshot, and
   validates it to the same reducer-derived state after restart.
2. Run `/bin/zsh scripts/verify.sh coordination`; expect snapshot types to be
   absent.
3. Add a typed snapshot with event count and canonical event digest; derive it
   only through replay and reject mismatched state, run ID, count, or digest.
4. Re-run focused coordination tests.

### Task 2: Persist snapshots without replacing the log

**Files:**

- Modify: `Tests/CAMAssistantCoreTests/CoordinationTests.swift`
- Modify: `Sources/CAMAssistantCore/Coordination/OrchestrationState.swift`

1. Write a failing test for atomic snapshot save/load and rejection after a
   later event makes the snapshot stale.
2. Add a versioned local snapshot store; retain the complete event log.
3. Re-run focused coordination and aggregate verification.

### Task 3: Record limitations and migration path

**Files:**

- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `docs/VERIFICATION_REPORT.md`

1. Record snapshots as reducer-validated local caches and defer event
   compaction, remote synchronization, and schema migration beyond the first
   persisted version.
2. Run `git diff --check` after documentation updates.
