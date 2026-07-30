# CAM Isolated Mining Checkpoint Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this
> plan task-by-task.

**Goal:** Prove a bounded, exact-approved CAM mining mutation and rollback on
an isolated disposable corpus without opening, copying, or changing a live or
personal CAM corpus.

**Architecture:** `CAMMiningPlan` remains the exact digest-bound authority.
The new executor receives only a fixture/synthetic operation directory that it
owns, persists a status-only checkpoint before any mutation, and runs a typed
in-process synthetic mining adapter against a copied corpus. It verifies the
postcondition digest and expected write set. Failed, cancelled, drifted, or
postcondition-failed attempts retain status-only evidence and discard the
operation copy; no promotion path exists.

**Tech Stack:** Swift 6.3, Foundation, CryptoKit, Swift Testing, existing
`ActionCard` and `ApprovalStore`, temporary directories, synthetic CAM corpus
fixtures only.

---

## Non-negotiable boundary

- No selected real repository, CAM launcher, external process, configuration,
  live database, personal database, network, provider, credential, or donor
  checkout is opened by these types or tests.
- A checkpoint is operation-local evidence, not a backup of a live corpus and
  not a full-vault payload.
- Success means the disposable fixture passed all typed checks. It does not
  authorize or imply a successful live mining operation.
- Cancellation/failure never promotes or overwrites any corpus. The executor
  deletes only its own operation directory after storing a status-only receipt.

### Task 1: Define typed isolated-mining request and receipt values

**Files:**

- Modify: `Sources/CAMAssistantCore/CAM/CAMMiningLifecycle.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

1. Write a failing test for a request that rejects unsafe fixture paths,
   malformed expected corpus digests, unbounded mutation limits, or a plan/run
   that is not active with a consumed exact approval.
2. Run `./scripts/verify.sh cam`; observe the missing-type failure.
3. Add immutable request, checkpoint, expected-write, receipt, status, and
   typed-error values. Every persisted value contains identifiers, digests,
   counts, timestamps, and status only; it contains no corpus/source/config
   bytes or absolute donor paths.
4. Re-run the focused CAM suite.

### Task 2: Persist checkpoint before an isolated mutation

**Files:**

- Modify: `Sources/CAMAssistantCore/CAM/CAMMiningLifecycle.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

1. Write a failing test that a synthetic operation creates a checkpoint before
   the adapter can mutate its copied corpus, and that its initial digest binds
   the exact plan and approval receipt.
2. Implement atomic operation-directory creation, source-copy validation,
   checkpoint persistence, and a private typed synthetic adapter protocol.
3. Make path validation reject symlinks, traversal, outside-root paths, and
   non-regular corpus inputs.
4. Run the focused CAM suite.

### Task 3: Verify promotion is impossible and rollback is disposal

**Files:**

- Modify: `Sources/CAMAssistantCore/CAM/CAMMiningLifecycle.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

1. Write failing tests for success, mutation failure, cancellation, expected
   write mismatch, and postcondition mismatch.
2. Implement postcondition validation: exact expected write identifiers,
   bounded write count, changed copy digest, and terminal receipt persistence.
3. On every non-success path, discard only the executor-owned copy after
   writing a status-only terminal receipt. On success, also discard the copy:
   this slice has no promotion capability.
4. Assert original synthetic corpus bytes are identical before/after every
   path and that no live-corpus path API exists.
5. Run the focused CAM suite.

### Task 4: Record truthful product status

**Files:**

- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `docs/evidence/task-16-closed-cam-executor.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json` only if its
  requirement wording changes truthfully

1. Record the exact test count and commands.
2. State that isolated mutation/rollback proof is real but the actual CAM
   executable, live corpus, personal corpus, repository mining, live approval
   action, and corpus promotion remain absent.
3. Do not add the operation-local checkpoint to full-vault backup inventory.

### Task 5: Verify and publish one coherent checkpoint

**Files:**

- Verify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`
- Verify: `scripts/verify.sh`

1. Run `git diff --check`.
2. Run `./scripts/verify.sh cam`, `./scripts/verify.sh goal-map`, and the
   aggregate verifier with a fresh clone.
3. Confirm the remote SHA after pushing
   `agent/portable-canonical-repo`.
4. Report the remaining live-mining boundary without calling CAM-016 complete.
