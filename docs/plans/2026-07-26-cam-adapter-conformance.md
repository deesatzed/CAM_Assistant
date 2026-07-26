# CAM Adapter Conformance Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Add a typed, local CAM_Codx/CAM_CAM adapter that validates pinned
contract/schema snapshots, proposes safe capabilities, and degrades cleanly
when either donor runtime is unavailable.

**Architecture:** Treat donor contract and runtime schema data as versioned
read-only snapshots. A pure adapter validates capability IDs, owner/runtime
identity, safety class, and explicit request arguments, producing a proposal or
typed degraded/error state—never a CLI/MCP call. CAM-008 policy/action cards
remain the required gate for any mutation-capable capability.

**Tech Stack:** Swift 6.3, Foundation Codable/JSON, Swift Testing, synthetic
fixtures, existing privacy/action-card types. No Python runtime, donor edit,
network, live `claw.db`, config sourcing, or MCP connection.

---

## Donor facts pinned for this milestone

- `CAM_Codx` contract: `agent-packs/contract/cam_agent_capabilities.json`,
  schema `1.0`, declares CAM_Codx as workflow hub and CAM_CAM as runtime/MCP
  owner.
- `CAM_CAM` exposes typed MCP schema metadata from
  `src/claw/tools/schemas.py` and dispatches via `src/claw/mcp_server.py`.
- Donor checkouts stay read-only. The observed `CAM_CAM` checkout has a dirty
  `claw.toml`, so no config, database, command, or runtime smoke is allowed.

### Task 1: Freeze capability contract and runtime schema snapshots

**Files:**
- Create: `Tests/Fixtures/CAM/v1/capabilities.json`
- Create: `Tests/Fixtures/CAM/v1/runtime-tools.json`
- Create: `Sources/CAMAssistantCore/CAM/CAMContract.swift`
- Create: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

1. Write failing decoder/conformance tests for the contract owner identity,
   required safe capability IDs, mutation capability classification, duplicate
   IDs, and runtime-tool mapping.
2. Run `/bin/zsh scripts/verify.sh cam`; expect missing CAM contracts.
3. Implement strict versioned snapshot decoding and a pure conformance report.
4. Rerun the focused suite; expect contract/schema mismatches to fail visibly.

### Task 2: Add health/degraded adapter and proposal boundary

**Files:**
- Create: `Sources/CAMAssistantCore/CAM/CAMAdapter.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

1. Write failing tests for absent runtime, identity mismatch, safe read-only
   proposal, mutation proposal requiring exact approval, and no invocation.
2. Implement `CAMRuntimeIdentity`, `CAMHealth`, and a pure adapter that emits
   `CAMProposal` only. Do not import a process, MCP, DB, or environment API.
3. Verify CAM outage yields a typed degraded result while local assistant state
   remains usable.

### Task 3: Native visibility, verifier, and evidence

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Create: `Sources/CAMAssistantApp/Views/CAMStatusView.swift`
- Modify: `scripts/verify.sh`
- Create: `docs/evidence/task-09-cam-adapter.md`
- Modify: `DECISIONS.md`, `PROGRESS.md`, `TASK_QUEUE.md`

1. Add a read-only native CAM status screen showing contract identity and
   unavailable/degraded state without a runtime start button.
2. Run focused contract/adapter tests, the full suite, release build, and diff
   check.
3. Mark CAM-009 complete only if conformance is fixture-backed and CAM outage
   is proven non-fatal. Keep live CAM mining/runtime calls disabled pending a
   separately approved adapter execution milestone.
