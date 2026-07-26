# Research and Knowledge Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Add local-first, resumable research packets and citation-bound knowledge records without web, cloud, CAM-runtime, or automatic-retention behavior.

**Architecture:** `ResearchRun` is an immutable-value checkpoint model and `ResearchCoordinator` is a pure local state transition service that validates cited facts against an existing `ContextBundle`. Knowledge records preserve claims, assumptions, and contradictions as separate, directly cited candidates. Native presentation is read-only; retaining a packet requires an explicit local request.

**Tech Stack:** Swift 6.3, Foundation, Swift Testing, existing `CitationVerifier`, `ContextBundle`, SwiftUI, local synthetic fixtures.

---

### Task 1: Define a checkpointed local research run

**Files:**
- Create: `Sources/CAMAssistantCore/Research/ResearchRun.swift`
- Create: `Sources/CAMAssistantCore/Research/ResearchCoordinator.swift`
- Create: `Tests/CAMAssistantCoreTests/ResearchTests.swift`
- Modify: `scripts/verify.sh`

1. Write failing tests that a run begins with unique nonblank queries, starts at a checkpoint, resumes deterministically, rejects stale checkpoint versions, and retains no result by default.
2. Run `/bin/zsh scripts/verify.sh research`; expect missing types.
3. Implement `ResearchRun`, `ResearchCheckpoint`, explicit `ResearchRetention`, and pure `ResearchCoordinator` transitions. A transition records only a digest/status; it makes no transport, process, database, or model call.
4. Rerun the focused suite; expect lifecycle and retention tests to pass.

### Task 2: Require citations and separate facts from inferences

**Files:**
- Modify: `Sources/CAMAssistantCore/Research/ResearchRun.swift`
- Modify: `Sources/CAMAssistantCore/Research/ResearchCoordinator.swift`
- Modify: `Tests/CAMAssistantCoreTests/ResearchTests.swift`

1. Write failing tests for a supported fact, rejected forged citation, uncited inference, and a packet whose fact/inference lists remain distinct.
2. Run `/bin/zsh scripts/verify.sh research`; expect compilation/test failures.
3. Reuse `CitationVerifier` to accept facts only when every quote exists in supplied local context. Permit an inference only when it references one or more verified facts and label it as inference.
4. Rerun the focused suite; expect cited/uncited paths to be explicit.

### Task 3: Add claim, assumption, and contradiction candidates

**Files:**
- Create: `Sources/CAMAssistantCore/Knowledge/Claim.swift`
- Create: `Sources/CAMAssistantCore/Knowledge/Contradiction.swift`
- Create: `Tests/CAMAssistantCoreTests/KnowledgeTests.swift`

1. Write failing tests for citation-bound claim candidates, explicit assumption labels, and a manual contradiction/steelman record that preserves two cited positions without merging them.
2. Run `/bin/zsh scripts/verify.sh knowledge`; expect missing types.
3. Implement value-only candidates and validation. A contradiction records `left`, `right`, and optional bridge as separate suggestions; it cannot edit a source or declare a winner.
4. Rerun the focused suite; expect invalid citations/duplicate position IDs to fail closed.

### Task 4: Show local research status without auto-retention

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Create: `Sources/CAMAssistantApp/Views/ResearchView.swift`
- Modify: `Tests/CAMAssistantCoreTests/ResearchTests.swift`

1. Add a failing core test for the read-only research presentation state, including `ephemeral` retention.
2. Add a Research sidebar section and render its read-only status. Do not add a web-search/start/retain button.
3. Compile through the focused research suite.

### Task 5: Record evidence and verify the milestone

**Files:**
- Create: `docs/evidence/task-10-research-knowledge.md`
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`

1. Run `/bin/zsh scripts/verify.sh research` and `/bin/zsh scripts/verify.sh knowledge`.
2. Run `/bin/zsh scripts/verify.sh all` and `git diff --check`.
3. Record exact outputs, retention behavior, and the limitation that no web, cloud, CAM, database persistence, background schedule, or automatic retention was enabled.
4. Mark CAM-010 complete only after the focused and aggregate receipts are current.
