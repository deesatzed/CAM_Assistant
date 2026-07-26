# Finish Wiki Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Complete every evidence gate in `GOAL_FINISH_WIKI.md` without weakening the verified local-first foundation.

**Architecture:** Preserve the three-layer ownership boundary: the native app owns personal truth, the coordination layer owns bounded verified work, and capability adapters operate only under explicit policy and authority. Close one end-to-end vertical slice at a time and promote it only after focused and aggregate evidence passes.

**Tech Stack:** Swift 6.2+, SwiftUI, Foundation, SQLite3, native macOS services, Swift Testing, shell verification/package scripts.

---

### Task 1: Portable canonical repository

**Files:**
- Modify: `GOAL.md`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `PROGRESS.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Test: `scripts/verify.sh`

**Steps:**

1. Remove controlling dependencies on files outside the repository.
2. Add a fresh-clone verification mode using repository-local caches and
   isolated application-support roots.
3. Run `/bin/zsh scripts/verify.sh all` and `git diff --check`.
4. Save the portable-baseline receipt and commit.

### Task 2: Daily-use native wiki journey

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/LibraryView.swift`
- Modify: `Sources/CAMAssistantApp/Views/CaptureSourcesView.swift`
- Modify: `Sources/CAMAssistantApp/Hotkeys/HotkeyManager.swift`
- Modify: `Sources/CAMAssistantCore/Capture/`
- Modify: `Sources/CAMAssistantCore/Knowledge/`
- Test: `Tests/CAMAssistantCoreTests/IngestTests.swift`
- Test: `Tests/CAMAssistantCoreTests/KnowledgeTests.swift`
- Test: `Tests/CAMAssistantCoreTests/AccessibilityTests.swift`

**Steps:**

1. Write failing journey contracts for source detail, citation navigation,
   lifecycle controls, real hotkey dispatch, restart, and recovery.
2. Implement the smallest native UI/core changes that satisfy each contract.
3. Exercise the packaged app with an isolated application-support root.
4. Run focused suites, aggregate verification, package/smoke, and commit.

### Task 3: Selected local-model grounded chat

**Files:**
- Modify: `Sources/CAMAssistantCore/Models/`
- Modify: `Sources/CAMAssistantCore/Conversation/ConversationCoordinator.swift`
- Modify: `Sources/CAMAssistantApp/Views/ConversationView.swift`
- Modify: `Sources/CAMAssistantApp/Views/ModelProfilesView.swift`
- Test: `Tests/CAMAssistantCoreTests/ConversationTests.swift`
- Test: `Tests/CAMAssistantCoreTests/ModelProfileTests.swift`
- Create: `Tests/Fixtures/Conversation/generated-v1/`

**Steps:**

1. Freeze generated-answer claim/citation, abstention, route identity, and
   latency fixtures before observing results.
2. Add a typed local inference adapter and explicit health check.
3. Add cited synthesis with confidence/coverage and ephemeral-default state.
4. Run the frozen evaluation, focused tests, aggregate verification, and commit.

### Task 4: Policy-gated research acquisition

**Files:**
- Modify: `Sources/CAMAssistantCore/Research/`
- Modify: `Sources/CAMAssistantCore/Privacy/OutboundPolicy.swift`
- Modify: `Sources/CAMAssistantApp/Views/ResearchView.swift`
- Test: `Tests/CAMAssistantCoreTests/ResearchTests.swift`
- Test: `Tests/CAMAssistantCoreTests/PrivacyTests.swift`

**Steps:**

1. Write failing tests for scrubbed payloads, transport spies, source quality,
   cancellation/resume, cost receipts, prompt injection, and explicit Keep.
2. Implement one bounded web/document acquisition adapter.
3. Add native packet review and fact/inference/contradiction presentation.
4. Prove zero egress for protected fixtures, run aggregate verification, and
   commit.

### Task 5: Persistent repository ingestion and evaluated ideas

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/`
- Modify: `Sources/CAMAssistantApp/Views/RepositoryView.swift`
- Modify: `Sources/CAMAssistantCore/Coordination/`
- Test: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`
- Create: `Tests/Fixtures/Repositories/semantic-v1/`

**Steps:**

1. Add failing restart/cancel/retry/removal/submodule/license/secret tests.
2. Implement persisted repository jobs and source removal lifecycle.
3. Freeze semantic evidence, counterevidence, abstention, and idea-quality
   fixtures before implementing semantic observations.
4. Add bounded analysis and promotion receipts; prove donor bytes/status remain
   unchanged.
5. Run focused and aggregate verification and commit.

### Task 6: Live bounded CAM/Codex integration

**Files:**
- Modify: `Sources/CAMAssistantCore/CAM/`
- Modify: `Sources/CAMAssistantCore/Coordination/`
- Modify: `Sources/CAMAssistantCLI/OrchestrationCommands.swift`
- Modify: `Sources/CAMAssistantApp/Views/CAMStatusView.swift`
- Test: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`
- Test: `Tests/CAMAssistantCoreTests/CoordinationTests.swift`

**Steps:**

1. Write failing tests for pinned runtime/config/database identity, exact
   approval, typed tools, timeout/retry/idempotency, cancellation, recovery,
   and postconditions.
2. Implement the smallest closed safe executor against disposable isolated
   CAM state.
3. Add native/CLI plan, approve, run, cancel, resume, and receipt controls.
4. Run isolated integration proof, aggregate verification, and commit.

### Task 7: Closed safe Mac Care actions and module lifecycle

**Files:**
- Modify: `Sources/CAMAssistantCore/MacCare/`
- Modify: `Sources/CAMAssistantCore/Modules/`
- Modify: `Sources/CAMAssistantApp/Views/MacCareView.swift`
- Test: `Tests/CAMAssistantCoreTests/MacCareTests.swift`
- Test: `Tests/CAMAssistantCoreTests/ModuleRegistryTests.swift`

**Steps:**

1. Define a closed non-privileged action set with preview, exact approval,
   precondition, postcondition, cancellation, and undo contracts.
2. Write failing success/stale/failure/undo/restart tests in temporary roots.
3. Implement the bounded executor and one packaged home-grown module lifecycle.
4. Run focused/aggregate verification and commit.

### Task 8: Accessibility, recovery, and release proof

**Files:**
- Modify: `Sources/CAMAssistantApp/Views/`
- Modify: `scripts/verify.sh`
- Modify: `scripts/package-app.sh`
- Modify: `scripts/smoke-app.sh`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`

**Steps:**

1. Add failing keyboard, VoiceOver, focus, reduced-motion, empty/offline/error,
   fresh-user, restart, backup/restore, and packaged-journey checks.
2. Fix only observed accessibility/usability/recovery failures.
3. Run the portable aggregate verifier, package/smoke, security/privacy scan,
   and `git diff --check`.
4. Run an adversarial reality audit against every `GOAL_FINISH_WIKI.md` gate.
5. Save the final report and mark complete only if no required gate remains.
