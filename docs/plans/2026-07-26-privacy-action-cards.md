# Privacy and Action Cards Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Build CAM-008's deterministic local privacy classifier, outbound
decision boundary, exact action-card/approval binding, and status-only audit
evidence without adding an outbound transport.

**Architecture:** A pure classifier labels individual fragments and aggregate
context with the controlling risk class. A policy router produces either a
sanitized local proposal or a blocked/deferred decision with zero transport
bytes. Action cards bind a digest of the precise redacted payload and state to
an expiring approval; the audit store receives status-only receipt facts.

**Tech Stack:** Swift 6.3, Foundation, CryptoKit-compatible SHA-256 helper or
existing content addressing, Swift Testing, SQLite audit store, synthetic
fixtures only.

---

## Invariants

- Risk classes remain `public`, `generic`, `contextual`, `proprietary`, and
  `restricted`; aggregate risk never falls below any protected component.
- Secret, credential, PII, PHI, path traversal, prompt-injection, and
  proprietary/reconstructible-context fixtures are blocked or sanitized
  deterministically; restricted requests produce zero outbound bytes.
- An action card is a proposal, not authority. Exact approval binds the action,
  redacted payload digest, state version, target, expiry, and rollback text.
- Audit exports contain status-only, redacted facts; neither raw payloads nor
  fixture secrets are persisted.
- No cloud, web, CAM, account, spend, or mutating transport is added in CAM-008.

### Task 1: Freeze synthetic privacy fixtures and classifier contracts

**Files:**
- Create: `Tests/Fixtures/Privacy/v1/manifest.json`
- Create: `Sources/CAMAssistantCore/Privacy/DataClassification.swift`
- Create: `Tests/CAMAssistantCoreTests/PrivacyTests.swift`

1. Write focused failing tests for every risk class and secret/credential/PII/
   PHI/path-traversal/prompt-injection/proprietary fixture.
2. Run `/bin/zsh scripts/verify.sh privacy`; expect missing privacy contracts.
3. Implement pure fragment/context classification and deterministic sanitizing
   evidence without logging raw input.
4. Rerun the focused suite; expect class/reason and sanitized/blocked result.

### Task 2: Add outbound policy and zero-byte enforcement

**Files:**
- Create: `Sources/CAMAssistantCore/Privacy/OutboundPolicy.swift`
- Modify: `Sources/CAMAssistantCore/Routing/RequestRouter.swift`
- Modify: `Tests/CAMAssistantCoreTests/PrivacyTests.swift`

1. Write failing tests for local allowance, sanitized public/generic proposal,
   restricted zero-byte block, and `WR` not bypassing local-data policy.
2. Implement a typed decision with provider/model facts, redacted manifest,
   exact byte count, and no network client.
3. Verify every restricted fixture reports byte count `0` and no fallback route.

### Task 3: Add exact action-card and approval binding

**Files:**
- Create: `Sources/CAMAssistantCore/Authority/ActionCard.swift`
- Create: `Sources/CAMAssistantCore/Authority/ApprovalStore.swift`
- Modify: `Tests/CAMAssistantCoreTests/PrivacyTests.swift`

1. Write failing tests for card completeness, deterministic payload digest,
   valid approval, expired/reused/mismatched/state-stale rejection, and no
   mutation from a proposal.
2. Implement local atomic approval persistence and receipt lifecycle.
3. Verify only a matching unexpired exact approval changes its own local
   approval record; it still does not execute an external action.

### Task 4: Extend status-only audit evidence

**Files:**
- Modify: `Sources/CAMAssistantCore/Audit/AuditEvent.swift`
- Modify: `Sources/CAMAssistantCore/Audit/AuditStore.swift`
- Modify: `Tests/CAMAssistantCoreTests/AuditTests.swift`
- Modify: `Tests/CAMAssistantCoreTests/PrivacyTests.swift`

1. Write failing export tests using synthetic restricted values.
2. Add only typed classification/decision/digest/status fields needed for
   privacy receipts; retain backward-compatible audit decoding/migration.
3. Verify SQLite bytes and JSON export contain no raw fixture secret or payload.

### Task 5: Native proposal state, verifier, and evidence

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Create: `Sources/CAMAssistantApp/Views/ActionCardView.swift`
- Modify: `scripts/verify.sh`
- Create: `docs/evidence/task-08-privacy-action-cards.md`
- Modify: `DECISIONS.md`, `PROGRESS.md`, `TASK_QUEUE.md`

1. Add a read-only native proposal view that presents policy outcome, access,
   excluded data, approval requirement, expiry, and rollback without dispatch.
2. Add a named `privacy` verifier suite and run focused, aggregate, release,
   secret-pattern, and diff checks.
3. Mark CAM-008 complete only with saved zero-byte restricted-fixture and
   status-only audit evidence. Do not enable live catalog, web, cloud, CAM, or
   action execution; those require later adapters and approval paths.
