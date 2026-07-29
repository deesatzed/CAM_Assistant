# Semantic Repository Intelligence Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use executing-plans to implement this plan task-by-task.

**Goal:** Add frozen, deterministic evidence/abstention evaluation and an explicitly selected loopback local-model candidate path for repository semantic observations.

**Architecture:** Deterministic clean-commit evidence remains authoritative. A candidate generator may propose a structured observation, but a separate deterministic validator must re-check snapshot identity, support, counterevidence, concept coverage, confidence, and abstention before the candidate can become an ephemeral result or an explicit idea-card proposal.

**Tech Stack:** Swift 6.3, Foundation, Swift Testing, existing `LocalModelTransport`, JSON fixtures, SHA-256 receipts, repository-owned verification scripts.

---

### Task 1: Freeze the semantic evaluation corpus

**Files:**
- Create: `Tests/Fixtures/Repositories/semantic-v1/manifest.json`
- Create: `Tests/Fixtures/Repositories/semantic-v1/README.md`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Steps:**

1. Create synthetic cross-file support, counterevidence, and abstention cases
   without donor or personal source.
2. Add a failing fixture test that decodes the wished-for manifest API,
   validates every case, and pins the exact SHA-256.
3. Run `./scripts/verify.sh repositories`.
4. Confirm RED is caused by the missing semantic manifest types.

### Task 2: Implement the frozen manifest and deterministic validator

**Files:**
- Create: `Sources/CAMAssistantCore/Repositories/RepositorySemanticEvaluation.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Steps:**

1. Add failing tests for accepted support/counterevidence, unknown evidence,
   role swaps, missing concept groups, non-finite confidence, and malformed
   abstention.
2. Run `./scripts/verify.sh repositories` and record the expected RED.
3. Implement only the manifest decoder/validator, candidate types, and
   deterministic candidate validator needed by the tests.
4. Run `./scripts/verify.sh repositories` and require GREEN.

### Task 3: Add the evaluator and machine-readable report

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositorySemanticEvaluation.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`
- Modify: `scripts/verify.sh`

**Steps:**

1. Add a failing evaluator test using a deterministic scripted generator.
2. Require exact metrics, failed/unanswered case IDs, runtime identity,
   manifest hash, per-case results, and frozen threshold verdict.
3. Run the focused suite and observe RED for the missing evaluator.
4. Implement the minimal generator protocol, evaluator, deterministic report,
   and named `repository-semantic` verification suite.
5. Run focused and named suites and require GREEN.

### Task 4: Add explicit loopback local-model candidate generation

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositorySemanticEvaluation.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Steps:**

1. Add failing transport-spy tests for loopback-only assignment, health/model
   identity, bounded evidence serialization, no authorization header, strict
   structured response, explicit abstention, unknown evidence, redirect
   refusal, and no fallback.
2. Run the focused suite and observe the intended failures.
3. Implement the local generator using the existing transport boundary and
   strict schema response.
4. Run the focused and privacy suites and require GREEN.

### Task 5: Connect accepted candidates to explicit idea proposals

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositorySemanticEvaluation.swift`
- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- Modify: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Steps:**

1. Add failing tests proving only validated non-abstaining candidates can form
   an ephemeral `RepositoryIdeaCard` draft with exact evidence,
   counterevidence, confidence, license, rejected alternatives, and smallest
   experiment.
2. Run focused tests and observe RED.
3. Implement the smallest typed conversion; do not persist or promote
   automatically.
4. Run focused tests and require GREEN.

### Task 6: Save evidence and checkpoint

**Files:**
- Create: `docs/evidence/task-15-repository-semantic-evaluation.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json`
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`

**Steps:**

1. Run `./scripts/verify.sh repository-semantic`.
2. Run `./scripts/verify.sh all`.
3. Run `git diff --check`.
4. Update the gate map only to the verdict supported by current evidence.
5. Commit, run `./scripts/verify.sh fresh-clone`, and push the checkpoint.

