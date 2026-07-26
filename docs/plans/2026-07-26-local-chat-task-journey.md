# Local Chat and Task Journey Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Add the local-first daily assistant journey: submit a local question, return a citation-bound deterministic response, keep/discard it explicitly, and promote it to a durable task proposal without cloud or CAM execution.

**Architecture:** A pure `ConversationCoordinator` accepts an existing local `ContextBundle`, produces an ephemeral response with citation identity and calibrated deterministic confidence, and never performs model/network/CAM transport. A local task proposal references the response/citations and becomes durable only through an explicit keep/promotion operation. SwiftUI adds an accessible compact chat surface and preserves existing offline/degraded behavior.

**Tech Stack:** Swift 6.3, Foundation, Swift Testing, existing retrieval citation/context contracts, SwiftUI.

---

### Task 1: Ephemeral cited local response contract

**Files:**
- Create: `Sources/CAMAssistantCore/Conversation/ConversationCoordinator.swift`
- Create: `Tests/CAMAssistantCoreTests/ConversationTests.swift`
- Modify: `scripts/verify.sh`

1. Write failing tests for blank-question refusal, no-context low-confidence response, context-backed citation identity, deterministic response ID, and no automatic retention.
2. Implement pure local response construction from a supplied `ContextBundle`; explicitly label the route `local-retrieval` and keep source citations separate from generated text.
3. Run the focused suite and prove no request creates a provider, CAM, or network call.

### Task 2: Keep/discard and task-promotion contract

**Files:**
- Modify: `Sources/CAMAssistantCore/Conversation/ConversationCoordinator.swift`
- Create: `Sources/CAMAssistantCore/Tasks/TaskProposal.swift`
- Modify: `Tests/CAMAssistantCoreTests/ConversationTests.swift`

1. Write failing tests that discard is terminal, keep is explicit, and promotion carries acceptance criteria/citations/authority while refusing uncited or discarded responses.
2. Implement in-memory, value-only keep/discard/promotion transitions; a future storage adapter owns durable persistence.
3. Run focused regression tests.

### Task 3: Native accessible assistant journey

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Create: `Sources/CAMAssistantApp/Views/ConversationView.swift`
- Modify: `Tests/CAMAssistantCoreTests/AccessibilityTests.swift`

1. Add a keyboard-focusable question field, local-only send action, cited response view, low-confidence follow-up, and explicit Keep/Discard/Promote controls.
2. Keep controls disabled when no response exists or policy state prevents the transition; expose VoiceOver labels and no-motion-dependent state.
3. Run focused conversation/accessibility tests, full suite, release build, smoke, package, and diff check.
