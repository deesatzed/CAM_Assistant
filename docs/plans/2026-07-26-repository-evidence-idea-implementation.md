# Repository Evidence and Idea Review Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let a user inspect commit-cited repository observations and create a
proposal-only idea card from selected evidence.

**Architecture:** Keep committed Git reads in `RepositoryObservationExtractor`.
Add immutable presentation and draft/promotion helpers in the Core module, then
run them from `AppModel` off the SwiftUI actor and render them in the existing
Repository view. No proposal is persisted, executed, or sent externally.

**Tech Stack:** Swift 6.3, Foundation `Process` through existing Git reader,
SwiftUI, Swift Testing.

---

### Task 1: Commit-cited observation presentation

**Files:**

- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Step 1: Write the failing test**

Create clean-snapshot observations and assert an immutable presentation keeps
commit short form, file, positive line, symbol, and statement. Assert a dirty
snapshot is refused by existing extraction rather than represented as cited.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path .swift-build --filter RepositoryTests`

Expected: missing presentation type.

**Step 3: Write minimal implementation**

Add `RepositoryObservationPresentation` with no source bytes and a small
`RepositoryObservationOperation` that first extracts from a clean recorded
snapshot, then maps observations to presentation. Do not expand the extractor
beyond its existing marker/declaration rules.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path .swift-build --filter RepositoryTests`

Expected: focused suite passes.

**Step 5: Commit**

Defer due to the dirty recovery worktree.

### Task 2: Evidence-bound idea-card draft and proposal

**Files:**

- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Step 1: Write the failing test**

Write a test that drafts an idea from exactly one selected observation plus
user-supplied title, counterevidence, and validation experiment. Assert it
gets snapshot license/commit evidence and emits only a `researchPacket`
proposal. Add a stale/dirty rejection case.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path .swift-build --filter RepositoryTests`

Expected: missing draft/proposal helper.

**Step 3: Write minimal implementation**

Add a typed draft request that rejects blank fields. Build the existing
`RepositoryIdeaCard` with selected evidence and default confidence `0.5`, then
call existing `promote(snapshot:)`. Do not write a task, plan file, repository,
or CAM record.

**Step 4: Run test to verify it passes**

Run: `swift test --scratch-path .swift-build --filter RepositoryTests`

Expected: focused suite passes.

**Step 5: Commit**

Defer due to the dirty recovery worktree.

### Task 3: App-model and native repository review surface

**Files:**

- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/RepositoryView.swift`

**Step 1: Write the failing test**

Use the Task 1 and Task 2 Core presentation/draft tests. The app target is
verified through a release build rather than a test pretending to exercise a
real user repository.

**Step 2: Run test to verify it fails**

Run: `swift test --scratch-path .swift-build --filter RepositoryTests`

Expected: Core behavior failure before the new types are implemented.

**Step 3: Write minimal implementation**

Add an explicit `Scan Committed Observations` action that runs only for the
currently inspected clean snapshot and renders cited rows. Let the user select
one row and enter card fields. `Create Proposal-Only Idea` displays the
proposal commit/ID and never mutates or retains an action.

**Step 4: Run test to verify it passes**

Run: `/bin/zsh scripts/verify.sh repositories && /bin/zsh scripts/verify.sh all`

Expected: focused suite and aggregate build pass.

**Step 5: Commit**

Defer due to the dirty recovery worktree.

### Task 4: Evidence and review

**Files:**

- Modify: `PROGRESS.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `REVIEW.md`

**Step 1: Record current evidence**

State the exact deterministic observation scope and proposal-only boundary.
Do not claim semantic analysis, automatic idea generation, task creation,
Codex plan creation, CAM mining, or real repository proof.

**Step 2: Final verification**

Run: `/bin/zsh scripts/verify.sh all && /bin/zsh scripts/verify.sh package && /bin/zsh scripts/verify.sh smoke && git diff --check`

Expected: all local checks pass or the report retains the limitation.

**Step 3: Commit**

Defer due to the dirty recovery worktree.
