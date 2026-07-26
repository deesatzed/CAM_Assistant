# Repository Intelligence and Mac Care Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Add read-only selected-repository intake and Mac Care assessment/plan contracts, with cited idea candidates and no live CAM mining or host mutation.

**Architecture:** Repository intake receives a user-selected local root and returns a versioned snapshot plus file/symbol evidence; it only reads filesystem/Git metadata and refuses non-repositories. Idea cards bind exact repository evidence and promote only to a proposal. Mac Care receives read-only assessment facts and can create a stale-state-checked plan, but has no apply/undo executor.

**Tech Stack:** Swift 6.3, Foundation FileManager/Process for local read-only inspection, Swift Testing, SwiftUI, synthetic temporary repositories and assessment fixtures.

---

### Task 1: Snapshot a selected local repository without mutation

**Files:**
- Create: `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- Create: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`
- Modify: `scripts/verify.sh`

1. Write failing tests that an intake captures canonical path, Git identity, dirty state, license signal, and sorted file manifest without changing fixture bytes or Git status.
2. Run `/bin/zsh scripts/verify.sh repositories`; expect missing types.
3. Implement a bounded local inspector using read-only `git` commands and recursive file metadata. Reject paths that are not Git repositories; do not use checkout, reset, add, clean, fetch, or any CAM command.
4. Rerun the focused suite and compare fixture bytes/status before and after intake.

### Task 2: Add evidence-backed observations and idea-card promotion

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

1. Write failing tests for exact file/line/symbol evidence, license-aware idea cards, required counterevidence, and promotion to a user-actionable proposal only.
2. Implement value-only observation, idea-card, and promotion types. Reject missing snapshot identity, missing evidence, blank validation experiment, or direct code-copy payloads.
3. Rerun focused tests; prove promotion cannot mutate/intake a repository or invoke CAM mining.

### Task 3: Add Mac Care assessment and non-executing plan boundary

**Files:**
- Create: `Sources/CAMAssistantCore/MacCare/MacWiseAdapter.swift`
- Create: `Tests/CAMAssistantCoreTests/MacCareTests.swift`

1. Write failing tests for read-only storage/application/startup assessment, immutable assessment digest, stale plan refusal, exact approval requirement, and unavailable apply/undo executor.
2. Implement assessment/plan values and a pure planner. Keep the system probe behind an explicit read-only adapter and make no delete, install, uninstall, login-item, service, preference, or Homebrew change.
3. Rerun the focused suite; prove plan generation is not execution and any action returns a typed unavailable error.

### Task 4: Native visibility and evidence

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Create: `Sources/CAMAssistantApp/Views/RepositoryView.swift`
- Create: `Sources/CAMAssistantApp/Views/MacCareView.swift`
- Create: `docs/evidence/task-11-repositories-mac-care.md`
- Modify: `DECISIONS.md`, `PROGRESS.md`, `TASK_QUEUE.md`

1. Add read-only Repository and Mac Care status sections with no scan/apply/mine button.
2. Run repository and Mac Care suites, then `/bin/zsh scripts/verify.sh all` and `git diff --check`.
3. Record that no real repository, CAM corpus, or Mac state was modified; defer mining, apply, and undo execution to exact-approved future gates.
