# Policy-Gated Research Acquisition V1 Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use executing-plans and
> test-driven-development to implement this plan task-by-task.

**Goal:** Add one exact-approved, durable, cancellable public HTTPS document
acquisition path whose source bytes enter the local vault and whose validated
packet remains ephemeral until explicit Keep or Discard.

**Architecture:** Core owns a strict public-URL policy, injected streaming
transport, schema-v9 job store, exact approval coordinator, vault ingestion,
typed receipts, and packet lifecycle. AppModel injects the async operation and
SwiftUI presents one action card plus bounded lifecycle and review controls.

**Tech Stack:** Swift 6.3, Foundation URLSession, CryptoKit, SQLite3, Swift
Testing, SwiftUI, existing CAM Assistant privacy/approval/ingestion/audit
contracts.

---

### Task 1: Freeze request, URL-policy, receipt, and packet contracts

**Files:**
- Create: `Sources/CAMAssistantCore/Research/ResearchAcquisition.swift`
- Modify: `Sources/CAMAssistantCore/Research/ResearchRun.swift`
- Modify: `Sources/CAMAssistantCore/Research/ResearchPacketStore.swift`
- Modify: `Tests/CAMAssistantCoreTests/ResearchTests.swift`

1. Write failing tests for canonical public HTTPS requests, invalid local/IP/
   port/credential targets, typed zero-cost constraints, complete source
   receipts, typed unanswered questions/recommendations/contradictions/
   limitations, and an ephemeral-to-kept packet transition.
2. Run `/bin/zsh scripts/verify.sh research` and confirm the failures are the
   missing contracts.
3. Implement the minimal value types, deterministic canonical request bytes,
   URL policy, packet fields, retained-copy helper, and store invariant.
4. Re-run the focused suite and keep every existing fact/citation and inference
   validation test green.

### Task 2: Add durable acquisition jobs and migration

**Files:**
- Create: `Sources/CAMAssistantCore/Research/ResearchAcquisitionJobStore.swift`
- Modify: `Sources/CAMAssistantCore/Storage/Migrations.swift`
- Modify: `Tests/CAMAssistantCoreTests/ResearchTests.swift`
- Modify: `Tests/CAMAssistantCoreTests/StorageTests.swift`
- Modify: `Tests/CAMAssistantCoreTests/FullVaultBackupTests.swift`

1. Write failing tests for pending/start/cancel/fail/complete transitions,
   bounded attempts, state-version increments, late-result refusal,
   status-only failure codes, restart interruption recovery, and v8-to-v9
   migration.
2. Add a representative populated job to the full-vault round trip and require
   post-restore reopening.
3. Observe the intended failures with the research, storage, and backup focused
   verifiers.
4. Add schema-v9 `research_acquisition_jobs`, required-column validation, the
   atomic typed job store, and restore validation.
5. Re-run all three focused suites.

### Task 3: Connect exact approval, transport, and vault ingestion

**Files:**
- Modify: `Sources/CAMAssistantCore/Research/ResearchAcquisition.swift`
- Modify: `Sources/CAMAssistantCore/Capture/CaptureService.swift`
- Modify: `Sources/CAMAssistantCore/Ingest/IngestQueue.swift`
- Modify: `Tests/CAMAssistantCoreTests/ResearchTests.swift`
- Modify: `Tests/CAMAssistantCoreTests/PrivacyTests.swift`
- Modify: `Tests/CAMAssistantCoreTests/IngestTests.swift`

1. Write a deterministic transport spy and failing tests proving proposal
   creates no transport, one explicit approval creates exactly one request,
   exact target/limits/state are bound, approval is consumed once, and every
   protected fixture produces zero transport calls.
2. Add failing tests for cancellation and same-job reapproval/resume,
   unsupported MIME, byte overflow, final-URL drift, HTTP failure, inert
   prompt-like content, repeated-byte deduplication, and research provenance.
3. Add a source-targeted ingest operation test so acquisition cannot process
   an unrelated pending source.
4. Implement the injected coordinator, safe failure mapping, source-targeted
   ingestion, research capture origin, typed result, and ephemeral packet.
5. Re-run research, privacy, ingestion, storage, and backup suites.

### Task 4: Add the bounded live HTTPS transport

**Files:**
- Create: `Sources/CAMAssistantCore/Research/PublicDocumentTransport.swift`
- Modify: `Tests/CAMAssistantCoreTests/ResearchTests.swift`

1. Write failing URL-protocol/delegate tests for no credentials/cookies/cache,
   same-origin redirect enforcement, response-status/MIME checks, streaming
   size refusal, and cancellation.
2. Implement an ephemeral `URLSession` streaming adapter with no authorization
   header, no provider fallback, and typed response metadata.
3. Re-run research and privacy suites. Do not make a public request yet.

### Task 5: Add native proposal, execution, recovery, and packet review

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/ResearchView.swift`
- Modify: `Tests/CAMAssistantAppTests/AppModelTests.swift`
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`

1. Write failing injected-operation tests for proposal, policy block, one-click
   approve/acquire, progress, cancellation, interrupted/failed resume
   proposal, ready packet, explicit Keep, explicit Discard, and retained packet
   restart.
2. Write failing source/accessibility contracts for exact target/limits,
   model/tool/route identity, source-quality and safety receipts, typed result
   sections, and every lifecycle action/state.
3. Implement non-blocking AppModel operations with run identity and stale-task
   protection.
4. Implement the native review surface. Remove the obsolete claim that all web
   execution is disabled; state the exact bounded V1 and its exclusions.
5. Re-run app, research, privacy, accessibility, backup, and model suites.

### Task 6: Prove the bounded live path and update repository truth

**Files:**
- Create: `docs/evidence/task-14-research-acquisition.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`

1. Run the live adapter once against a stable public HTTPS plaintext standards
   document, after all deterministic proofs pass. Use a disposable vault and
   record status-only request/response receipts, exact content identity, zero
   cost, and limitations; never save response text in evidence.
2. Build the unsigned package and exercise proposal, one-click acquisition,
   packet review, Keep/Discard, cancellation/recovery, and restart against an
   isolated application-support root.
3. Re-run `/bin/zsh scripts/verify.sh research`,
   `/bin/zsh scripts/verify.sh privacy`, `/bin/zsh scripts/verify.sh backup`,
   `/bin/zsh scripts/verify.sh app`, and `/bin/zsh scripts/verify.sh goal-map`.
4. Update only gates directly proved by current evidence. Preserve partial or
   missing status for provider search, model-generated findings, HTML/browser
   acquisition, or any unproven packaged state.
5. Run `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all`,
   `git diff --check`, commit, run `/bin/zsh scripts/verify.sh fresh-clone`,
   push, and confirm the exact remote head.
