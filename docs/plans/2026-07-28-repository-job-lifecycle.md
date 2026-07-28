# Repository Job Lifecycle Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make explicit local repository indexing restart-safe and reviewable by
persisting repository-level jobs, retry/cancellation outcomes, completed
snapshot links, and reversible saved-source lifecycle receipts.

**Architecture:** Add a version-8 SQLite migration for repository jobs and
saved-source lifecycle records. A typed job store owns state transitions and a
self-contained runner wraps the existing read-only incremental index operation,
so a crash leaves an interrupted job that can be retried idempotently. A
per-job OS lease distinguishes crashed work from another live app process, and
a required stateful cancellation token defines the terminal snapshot boundary.
SQLite source lifecycle is authoritative and reconciles its JSON compatibility
cache after a crash split. Saved-source removal retains status-only lifecycle,
immutable vault bytes, provenance, snapshots, and idea evidence.

**Tech Stack:** Swift 6.3, Foundation, SQLite3, SwiftUI, Swift Testing, existing
`RepositoryLocalIndexOperation`, `RepositorySnapshotStore`, and
`RepositorySourceConfigurationStore`.

---

### Task 1: Persist typed repository jobs

**Files:**
- Modify: `Sources/CAMAssistantCore/Storage/Migrations.swift`
- Create: `Sources/CAMAssistantCore/Repositories/RepositoryJob.swift`
- Test: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`
- Test: `Tests/CAMAssistantCoreTests/StorageTests.swift`

**Step 1: Write the failing migration and restart test**

Add a test that creates a job, moves it to `running`, closes the store, reopens
it, and calls interrupted-job recovery. Require a status-only `failed` record
with error code `interrupted`, one attempt, the original canonical path, and
the original timestamps ordered deterministically.

**Step 2: Run the focused test and verify red**

Run:

```text
swift test --filter RepositoryJob
```

Expected: compilation failure because `RepositoryJobStore`,
`RepositoryJobRecord`, and `RepositoryJobStatus` do not exist.

**Step 3: Add migration version 8**

Create `repository_jobs` with:

- `job_id` primary key;
- optional saved `source_id`;
- `canonical_path`;
- typed `status`;
- `attempts` and `max_attempts`;
- optional `snapshot_commit`, `captured_source_count`, and status-only
  `error_code`;
- `created_at` and `updated_at`;
- indexes by path/status/update time.

Create `repository_source_lifecycle` with source ID, canonical path, active or
removed status, and update time. Do not add cascades to source bytes, snapshots,
or idea records.

**Step 4: Implement the minimal job state machine**

In `RepositoryJob.swift`, add:

```swift
public enum RepositoryJobStatus: String, Codable, Sendable {
    case pending, running, cancelled, failed, completed
}
```

Add a `RepositoryJobRecord` display-safe value and
`RepositoryJobTransitionError`. Implement:

- `create(sourceID:canonicalPath:maxAttempts:createdAt:)`;
- `record(id:)` and `all()`;
- `start(id:at:)`, only from pending/cancelled/failed and below max attempts;
- `cancel(id:at:)`, only from pending/running;
- `fail(id:errorCode:at:)`, only from running and with a nonempty status code;
- `complete(id:snapshotCommit:capturedSourceCount:at:)`, only from running;
- `recoverInterrupted(at:)`, converting every persisted running record to
  failed with error code `interrupted`.

Each transition must update under one `SQLiteStore.transaction` and re-read the
typed record after the write.

**Step 5: Run focused tests and verify green**

Run:

```text
swift test --filter RepositoryJob
swift test --filter sqliteMigrationsAreDurableAcrossRestart
```

Expected: job restart/transition and migration tests pass.

### Task 2: Wrap indexing in the persistent job lifecycle

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryJob.swift`
- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryModule.swift`
- Test: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Step 1: Write the failing cancellation/retry test**

Create a temporary Git repository and isolated vault. Create one repository
job, run it with `shouldCancel == true`, close/reopen the store, and require:

- the same job is `cancelled`;
- no snapshot receipt exists;
- repository bytes and `git status --porcelain` are unchanged.

Run the same job again without cancellation and require:

- the same job ID is `completed`;
- attempts advance to two;
- its completed commit matches a persisted snapshot receipt;
- permitted files exist as derived local documents;
- repository bytes and Git status remain unchanged.

**Step 2: Run the focused test and verify red**

Run:

```text
swift test --filter persistentRepositoryJob
```

Expected: failure because `RepositoryJobRunner` does not exist.

**Step 3: Implement the runner**

Add `RepositoryJobRunner.run(...)` with explicit repository root, vault
database, content root, job ID, capture date, and cancellation closure.

The runner must:

1. transition the existing job to running;
2. invoke `RepositoryLocalIndexOperation.index`;
3. on success, link the job to the exact snapshot commit and captured count;
4. on `RepositoryIncrementalIndexError.cancelled`, persist cancelled and
   rethrow;
5. on any other error, persist a stable status-only error code and rethrow.

Do not store raw repository text, exception descriptions, prompts, or secrets
in the job table.

**Step 4: Run focused tests and verify green**

Run:

```text
swift test --filter persistentRepositoryJob
swift test --filter RepositoryTests
```

Expected: cancellation/retry/restart and existing repository suites pass.

### Task 3: Retain saved-source removal lifecycle

**Files:**
- Modify: `Sources/CAMAssistantCore/Repositories/RepositoryJob.swift`
- Modify: `Sources/CAMAssistantCore/Repositories/RepositorySourceConfiguration.swift`
- Test: `Tests/CAMAssistantCoreTests/RepositoryTests.swift`

**Step 1: Write the failing removal lifecycle test**

Use one configuration JSON and one isolated database. Add a source, persist one
snapshot and one lifecycle-active receipt, then remove the source. Reopen every
store and require:

- the active configuration no longer contains the path;
- the lifecycle record remains `removed`;
- the snapshot receipt remains;
- no content or snapshot deletion API was invoked.

Also require a failed lifecycle write to restore the previous active
configuration rather than silently splitting JSON and SQLite state.

**Step 2: Run the focused test and verify red**

Run:

```text
swift test --filter repositorySourceRemoval
```

Expected: failure because no lifecycle store is attached to the source service.

**Step 3: Implement lifecycle persistence and rollback**

Add `RepositorySourceLifecycleStatus`, `RepositorySourceLifecycleRecord`, and
`RepositorySourceLifecycleStore`. Extend `RepositorySourceService` with an
optional lifecycle store so existing isolated callers remain compatible.

On add:

1. save the next active configuration;
2. record lifecycle `active`;
3. if lifecycle persistence fails, restore the previous configuration and
   rethrow.

On remove:

1. save the configuration without the source;
2. record lifecycle `removed`;
3. if lifecycle persistence fails, restore the prior configuration and
   rethrow.

Removal must never delete immutable bytes, capture provenance, derived history,
snapshot receipts, job history, or idea cards.

**Step 4: Run focused tests and verify green**

Run:

```text
swift test --filter repositorySourceRemoval
swift test --filter RepositoryTests
```

Expected: lifecycle/restart/rollback and all repository tests pass.

### Task 4: Expose honest native job controls

**Files:**
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/RepositoryView.swift`
- Test: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- Test: `Tests/CAMAssistantAppTests/RepositoryJobAppModelTests.swift`

**Step 1: Write failing presentation tests**

Require display rows that expose path, status, attempt count, completed commit
when available, status-only error when failed, and only the valid action:
Cancel for pending/running or Resume for cancelled/failed below the attempt
limit. Completed and exhausted jobs expose no action.

**Step 2: Run the focused test and verify red**

Run:

```text
swift test --filter RepositoryJobPresentation
```

Expected: compilation failure because the presentation does not exist.

**Step 3: Integrate the store and runner**

- Build the job store from `LocalVaultPaths.databaseURL()`.
- Recover interrupted jobs during app initialization.
- Creating an indexing request persists a job before detached execution.
- Cancellation remains cooperative but always resolves to a persisted state.
- Resume runs the same job ID and increments its attempt.
- Reload jobs after create/start/cancel/fail/complete and after app restart.
- Bind a saved source UUID when the selected canonical path matches one;
  otherwise retain the explicit path with a nil source ID.

**Step 4: Add the native Recent Repository Jobs section**

Expose:

- path, state, attempt count, completed commit/count, and status-only failure;
- independent accessible Cancel or Resume buttons;
- explicit text that removal hides a saved selection but preserves local vault
  bytes, provenance, snapshots, job history, and retained ideas.

No UI action may automatically inspect, retry, clone, contact CAM, or contact a
network.

**Step 5: Run focused tests and verify green**

Run:

```text
swift test --filter RepositoryJobPresentation
swift test --filter RepositoryTests
```

Expected: app presentation and core repository tests pass.

### Task 5: Verify, document, review, and publish

**Files:**
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Create: `docs/evidence/task-15-repository-job-lifecycle.md`

**Step 1: Run focused and aggregate verification**

Run:

```text
/bin/zsh scripts/verify.sh repositories
CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all
/bin/zsh scripts/verify.sh package
/bin/zsh scripts/verify.sh smoke
git diff --check
```

Expected: all focused tests, aggregate tests, release builds, package
validation, smoke, and diff checks pass.

**Step 2: Save bounded evidence**

Record exact test counts, red/green failures, migration version, persistent
state transitions, repository before/after byte and Git-status evidence,
application-support isolation, and non-claims. Do not claim semantic analysis,
remote clone acquisition, issue ingestion, CAM mining, or source deletion.

**Step 3: Request adversarial code review**

Require zero Critical or Important findings before checkpoint acceptance.
Classify every recommendation as Accepted, Rejected, or Needs Investigation.

**Step 4: Commit and push the scoped checkpoint**

Commit only the files in this plan and push
`agent/portable-canonical-repo`.

**Step 5: Run exact-commit clean-clone proof**

Run:

```text
/bin/zsh scripts/verify.sh fresh-clone
```

Expected: the pushed commit passes portability, all tests, release builds,
package validation, and offline smoke from a clean temporary clone.

## Explicit deferrals

This batch does not implement approved remote cloning, submodule ingestion,
issue metadata acquisition, secret scanning, semantic observation evaluation,
live Codex/CAM execution, or source-byte deletion. Those remain separate
Task-5 batches with their own frozen fixtures and authority gates.
