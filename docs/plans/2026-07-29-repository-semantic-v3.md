# Repository Semantic V3 and Native Mining Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Replace lexical phrase matching with a pre-registered closed-claim evaluation and connect the validated local-model path to a native clean-repository mining journey.

**Architecture:** Preserve semantic V1/V2 byte-for-byte. Add separate V3 manifest, candidate, validator, evaluator, and loopback generator types, then reuse their neutral evidence and strict transport boundary in a runtime snapshot analyzer whose output remains ephemeral until explicit Keep or promotion.

**Tech Stack:** Swift 6.3, Swift Testing, Foundation, CryptoKit, SwiftUI, Git read-only subprocesses, existing `LocalModelTransport`, repository-owned verification scripts.

---

### Task 1: Freeze semantic V3 before model use

**Files:**
- Create: `Tests/Fixtures/Repositories/semantic-v3/manifest.json`
- Create: `Tests/Fixtures/Repositories/semantic-v3/README.md`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

1. Write two observation and two abstention cases with claim catalogs,
   same-topic claim distractors, neutral evidence payloads, and hidden expected
   claim/evidence labels.
2. Add a test that decodes the wished-for V3 API and pins the exact fixture
   SHA-256.
3. Run `/bin/zsh scripts/verify.sh repositories`.
4. Require RED because the V3 manifest types do not exist.
5. Record the frozen hash in the fixture README before any named-model run.

### Task 2: Implement V3 manifest and structural validation

**Files:**
- Create: `Sources/CAMAssistantCore/Repositories/RepositorySemanticV3.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

1. Add failing tests for duplicate/unknown claims, missing required claims,
   claim distractors, evidence role swaps, missing counterevidence, malformed
   abstention, non-finite confidence, snapshot drift, and retained output.
2. Run the repository suite and confirm the intended RED.
3. Implement V3 manifest decoding/validation, claim/candidate types, and a
   deterministic validator without changing V1/V2.
4. Run the repository suite and require GREEN.
5. Commit the frozen contract and validator.

### Task 3: Implement V3 metrics and reports

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositorySemanticV3.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

1. Add a scripted perfect generator and failing contaminated generators.
2. Require exact claim recall/precision, support precision, counterevidence
   recall, abstention accuracy, failures, unanswered cases, identities, fixture
   hash, and sorted case results.
3. Observe RED for the missing evaluator.
4. Implement the evaluator and process-exit verdict.
5. Run `/bin/zsh scripts/verify.sh repositories` and require GREEN.

### Task 4: Add strict V3 loopback generation and CLI

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositorySemanticV3.swift`
- Modify: `Sources/CAMAssistantCLI/main.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

1. Add transport-spy tests proving the prompt exposes claim catalog and neutral
   evidence but not expected outcome, required IDs, or evidence roles.
2. Add tests for exact JSON schema, valid abstention, unknown IDs, model drift,
   redirect refusal, response bounds, cancellation, and no authorization
   header or fallback.
3. Observe RED, then implement the minimal generator and
   `evaluate-repository-semantic-v3` CLI command.
4. Run repository and privacy suites.
5. Commit the executable V3 contract.

### Task 5: Run one named local model without tuning

**Files:**
- Create: `docs/evidence/task-15-repository-semantic-v3-<model>-report.json`
- Modify: `docs/evidence/task-15-repository-semantic-evaluation.md`
- Modify: `PROGRESS.md`

1. Confirm the V3 fixture hash matches its pre-run README.
2. Start LM Studio bound to `127.0.0.1`, explicitly load one selected model,
   and run the unchanged V3 CLI.
3. Preserve the complete report and nonzero exit if it fails.
4. Unload the model and stop the server.
5. Do not change labels, claims, distractors, or thresholds after observation.

### Task 6: Build exact committed runtime evidence

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- Modify: `Sources/CAMAssistantCore/Repositories/RepositorySemanticV3.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

1. Add failing tests for clean-snapshot-only neutral bundles, physical lines,
   exact bounded excerpts, deterministic IDs/order, size/count bounds, Git
   status/byte preservation, cancellation, and commit drift.
2. Observe RED.
3. Add backward-compatible optional excerpts to repository observations and a
   read-only runtime bundle builder.
4. Run repository and storage suites.

### Task 7: Add native ephemeral analysis and promotion

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/RepositoryView.swift`
- Modify: `Tests/CAMAssistantAppTests/RepositoryJobAppModelTests.swift`
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`

1. Add failing AppModel tests using injected semantic operations for accepted,
   abstained, failed, cancelled, stale-snapshot, and unavailable-model states.
2. Add failing accessibility-source tests for named controls and honest
   no-CAM/no-retention authority.
3. Implement off-main analysis, cancellation, status-only failures, exact
   model identity, candidate presentation, and explicit Keep/Reject/promotion.
4. Run app, repository, model, and privacy suites.

### Task 8: Prove packaged native mining and publish

**Files:**
- Create: `docs/evidence/task-15-native-repository-semantic-journey.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`

1. Package a clean exact commit and launch only against an isolated
   application-support root.
2. Select a disposable clean repository and selected loopback model.
3. Save pre/post repository byte hashes and Git status.
4. Exercise accepted or abstained analysis, explicit disposition, and one
   proposal promotion without repository mutation or CAM execution.
5. Run `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all`.
6. Run `git diff --check`, commit, and run
   `/bin/zsh scripts/verify.sh fresh-clone`.
7. Push `agent/portable-canonical-repo` and verify the remote head.

