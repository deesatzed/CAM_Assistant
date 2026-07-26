# Explicit Local-First Model Routing Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Add native, atomic model profiles and deterministic request routing that defaults locally, preserves the documented marker grammar, and fails closed before any unapproved provider or CAM action.

**Architecture:** Keep marker parsing pure and independent from profile availability. A local JSON-backed profile registry owns versioned role assignments, active-profile selection, and rollback. The request router consumes a parsed marker set and registry snapshot to produce an explainable route decision; it never performs a network or CAM call. `AR`, `WR`, and `CAM` remain typed requests whose execution is deferred until CAM-008/CAM-009 enforce privacy and adapter contracts.

**Tech Stack:** Swift 6.3, Swift Testing, Foundation JSON/Codable, atomic local file writes, existing audit concepts, and native SwiftUI/CLI surfaces.

---

## Invariants

- No marker selects the configured local role.
- `CL`, `GR`, and `OA` select exactly their named configured roles; a missing or unavailable role is a visible error, never a fallback.
- `WR`, `WRGR`, `AR`, and `CAM` are parsed accurately but cannot trigger cloud, web, or CAM execution in this milestone.
- Profile state is local, atomic, revisioned, rollback-capable, and contains no secret value.
- Catalog data is fact-only fixture data. A later opt-in live client may supply it, but no live request occurs in tests.

### Task 1: Freeze marker grammar and route-decision contracts

**Files:**

- Create: `Sources/CAMAssistantCore/Routing/MarkerParser.swift`
- Create: `Sources/CAMAssistantCore/Routing/RequestRouter.swift`
- Create: `Tests/CAMAssistantCoreTests/RoutingTests.swift`

1. Write failing tests for local default; `CL`, `GR`, `OA`, `AR`, `WR`, `WRGR`, and `CAM`; duplicate/incompatible markers; text preservation; unavailable named roles; and no-silent-substitution.
2. Run `/bin/zsh scripts/verify.sh routing`; expected result: compilation failure because routing contracts do not exist.
3. Add marker tokens, `ParsedRequest`, route intents, and typed parser errors. Parse only explicit terminal backtick markers; leave ordinary prose unchanged.
4. Add a pure `RequestRouter` that accepts a parsed request and available-role snapshot. It returns a local decision for no marker, a named-role decision for configured explicit markers, a deferred-policy decision for `AR`/`WR`, and a deferred-CAM decision for `CAM`.
5. Re-run the focused suite; expected result: every marker maps deterministically and missing roles fail before a transport is selected.

### Task 2: Add versioned local model profile persistence

**Files:**

- Create: `Sources/CAMAssistantCore/Models/ModelProfile.swift`
- Create: `Sources/CAMAssistantCore/Models/ModelRegistry.swift`
- Create: `Tests/CAMAssistantCoreTests/ModelProfileTests.swift`

1. Write failing tests for profile validation, atomic create/use, exact role lookup, revision increments, restart, rollback, invalid expected revision, and no secret-bearing endpoint/query data in exported state.
2. Run `/bin/zsh scripts/verify.sh models`; expected result: compilation failure because model profile and registry types do not exist.
3. Implement a local registry document with schema version, active profile, current profile revisions, and retained prior revisions. Use atomic writes and expected-revision checks. Profile assignments contain provider/model/role facts and a local endpoint descriptor, never API keys.
4. Add `ModelRoleAvailability` derived from the active profile. The router reads this value rather than inspecting files itself.
5. Re-run the focused suite; expected result: a fresh process observes the same active profile, a failed write leaves the prior profile active, and rollback restores a prior revision without source/index changes.

### Task 3: Make catalog and discovery data explicit, local, and fact-only

**Files:**

- Create: `Sources/CAMAssistantCore/Models/ModelCatalog.swift`
- Create: `Tests/Fixtures/Models/catalog-v1.json`
- Modify: `Tests/CAMAssistantCoreTests/ModelProfileTests.swift`

1. Write failing tests that decode a versioned catalog fixture, reject malformed/duplicate model records, preserve provider/model/context/pricing facts, and prove the catalog makes no recommendation or profile change.
2. Implement a `ModelCatalog` decoder and narrow local OpenAI-compatible endpoint descriptor. Do not add a network client; live lookup remains an opt-in later transport with outbound-policy enforcement.
3. Re-run model tests; expected result: catalog facts are read-only and profile choice remains a separate user mutation.

### Task 4: Expose equivalent CLI and native settings state

**Files:**

- Modify: `Sources/CAMAssistantCLI/main.swift`
- Create: `Sources/CAMAssistantCLI/ModelsCommands.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Create: `Sources/CAMAssistantApp/Views/ModelProfilesView.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Tests/CAMAssistantCoreTests/ModelProfileTests.swift`

1. Write failing command-parser tests for `models current`, `profile list`, `profile show`, `profile create`, `profile use`, `models set`, and `models catalog`. Write view-model tests for local active-profile state and unavailable-role messaging.
2. Implement command parsing against an explicitly supplied local state root in tests and the app-support default only for normal app/CLI use. Do not print secret values. `catalog --live`, `models test`, embeddings migration/promotion, and provider transport must return a typed not-permitted/not-implemented result until later proof gates.
3. Implement a compact Settings view that shows the active local profile, role assignments, revision, and health/availability; it must not make a network request or mutate a profile without a separate user action.
4. Re-run focused CLI/model tests and build the app.

### Task 5: Verify, receipt, and truthful task transition

**Files:**

- Modify: `scripts/verify.sh`
- Create: `docs/evidence/task-07-model-routing.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `DECISIONS.md` if a profile/rollback boundary changes

1. Add named `routing` and `models` verifier suites, then run their red/green tests plus the aggregate verifier.
2. Save a receipt recording marker matrix, profile persistence/rollback tests, local-only catalog fixture result, no-network boundary, commands, branch/dirty state, and limitations.
3. Mark CAM-007 complete only if all marker/profile acceptance tests pass. Keep CAM-008 pending and retain the explicit prohibition on cloud-context, web, spend, and CAM execution.
4. Run `/bin/zsh scripts/verify.sh routing`, `/bin/zsh scripts/verify.sh models`, `/bin/zsh scripts/verify.sh all`, and `git diff --check`.
5. Commit only the verified CAM-007 batch; do not bundle existing uncommitted recovery changes unless they are deliberately part of the same verified commit.
