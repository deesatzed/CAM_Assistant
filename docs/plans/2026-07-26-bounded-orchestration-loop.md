# Bounded Orchestration Loop Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Make the existing versioned coordination reducer executable as one
local, bounded, restart-safe loop that persists content-addressed evidence.

**Architecture:** A `BoundedOrchestrationLoop` accepts only typed local step
inputs: phase advance, verification, block, or cancellation. It stores each
step's evidence locally, appends the corresponding event through the existing
event log, and rebuilds its run state from that log on restart. It does not
execute commands, invoke models, access CAM, or fan out to specialists; those
remain separate capability gates.

**Tech Stack:** Swift 6.3, Swift Testing, Foundation, existing
`OrchestrationReducer`, `OrchestrationEventLog`, and
`OrchestrationArtifactStore`.

---

### Task 1: Specify a persisted bounded local loop

**Files:**

- Modify: `Tests/CAMAssistantCoreTests/CoordinationTests.swift`
- Modify: `Sources/CAMAssistantCore/Coordination/OrchestrationState.swift`

1. Write a failing test constructing a loop with a run ID and step budget,
   driving observe-to-plan-to-execute-to-verify plus verification, and asserting
   verified success, four evidence references, and ordered persisted events.
2. Run `/bin/zsh scripts/verify.sh coordination`; expect the loop type to be
   absent.
3. Add immutable typed step input and a loop that writes evidence to the local
   artifact store before appending its reducer event.
4. Re-run the focused coordination suite.

### Task 2: Prove restart recovery and terminal safety

**Files:**

- Modify: `Tests/CAMAssistantCoreTests/CoordinationTests.swift`
- Modify: `Sources/CAMAssistantCore/Coordination/OrchestrationState.swift`

1. Write a failing test reopening a loop from its event log and asserting the
   replayed state and artifact references equal the original; assert no step is
   accepted after terminal verification.
2. Run `/bin/zsh scripts/verify.sh coordination`; expect the new recovery
   assertion to fail.
3. Implement replay-based initialization and terminal-state refusal without
   adding a second persistence authority.
4. Re-run focused coordination then aggregate verification.

### Task 3: Preserve truth surfaces

**Files:**

- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `docs/VERIFICATION_REPORT.md`

1. Record the local bounded-loop boundary and its verification result.
2. Explicitly defer OS/process/model/CAM execution, cross-process leases,
   graph dispatch, and specialist fan-out.
3. Run `git diff --check` after documentation updates.
