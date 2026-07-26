# Repository Idea to Local Task Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Persist a user-approved repository idea as a local-read task with
commit-cited evidence and explicit validation criteria.

**Architecture:** A Core mapper validates the existing idea card against the
clean snapshot, then emits an existing `TaskProposal`. `AppModel` saves that
proposal through the existing local `TaskStore` and refreshes Tasks.

**Tech Stack:** Swift 6.3, existing repository evidence contracts, SQLite
`TaskStore`, SwiftUI, Swift Testing.

---

### Task 1: Evidence-bound task mapper

**Files:**

- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Step 1: Write the failing test**

Build a clean snapshot and card, map it to a task, and assert stable ID,
`localRead` authority, two explicit criteria, and one repository citation.
Assert dirty/stale evidence fails.

**Step 2: Run red**

Run: `swift test --scratch-path .swift-build --filter RepositoryTests`

**Step 3: Implement minimal mapper**

Validate via existing `card.promote(snapshot:)`, then make a `TaskProposal`
with deterministic ID and a citation whose passage identifies commit/file/line.
Do not add execution, a new store, source bytes, or automatic promotion.

**Step 4: Run green**

Run: `swift test --scratch-path .swift-build --filter RepositoryTests`

**Step 5: Commit**

Defer due to the dirty recovery worktree.

### Task 2: Explicit native save action

**Files:**

- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/RepositoryView.swift`

**Step 1: Preserve Core proof**

The Core mapper test is the behavior proof. Do not use a real repository in an
app test.

**Step 2: Implement minimal bridge**

Show `Save as Local Task` only after a proposal exists. Reconstruct/use the
current validated card, save its task through `TaskStore`, refresh Tasks, and
display a status-only local receipt. Failure never writes a partial task.

**Step 3: Verify**

Run: `/bin/zsh scripts/verify.sh repositories && /bin/zsh scripts/verify.sh tasks && /bin/zsh scripts/verify.sh all`

**Step 4: Commit**

Defer due to the dirty recovery worktree.

### Task 3: Evidence update and review

**Files:**

- Modify: `PROGRESS.md`, `docs/VERIFICATION_REPORT.md`, `DECISIONS.md`, `REVIEW.md`

**Step 1:** Record that task saving is an explicit local derived write only.

**Step 2:** Run package, smoke, and `git diff --check`; retain all remaining
research-packet, Codex-plan, semantic-analysis, and CAM-mining limitations.
