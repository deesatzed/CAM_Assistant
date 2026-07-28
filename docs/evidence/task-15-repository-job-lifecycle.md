# Task 15 Repository Job Lifecycle Evidence

**Date:** 2026-07-28
**Scope:** Durable local repository indexing jobs and non-destructive saved
source lifecycle
**Status:** Passing bounded slice; CAM-015 remains in progress

## Proven behavior

- SQLite schema version 8 persists `repository_jobs` and
  `repository_source_lifecycle`.
- A repository job has typed pending, running, cancelled, failed, or completed
  state; a positive bounded attempt limit; stable status-only failures; and
  timestamps.
- App restart recovery changes persisted running work to failed with the
  display-safe `interrupted` code only after obtaining the job's OS `flock`
  lease. A lease held by another live app process prevents false recovery.
  Retry reuses the same job identity and increments its bounded attempt count.
- Persistent runners require one stateful cancellation token. Cancellation
  wins before the terminal snapshot boundary; a later request is refused
  rather than reported as cancelling an already-committing receipt.
- Cancellation produces no new repository snapshot. A later successful retry
  links the exact snapshot commit and captured-source count to that same job.
- The runner test verifies selected repository bytes and
  `git status --porcelain` before and after cancellation and completion.
- SQLite source lifecycle is authoritative; reload repairs JSON after simulated
  add/remove crash splits. Removing a saved source updates only selection state.
  Existing snapshot evidence remains, and synchronous write failures roll back.
- Native job rows expose path, status, attempt count, safe result/failure text,
  and only a valid Cancel or Resume action.

## Red-to-green receipts

The focused tests first failed because the durable job store, runner, lifecycle
store, and presentation did not exist. The native view contract then failed
until job history, bounded actions, and the removal-preserves-evidence language
were present.

Final reproduced commands:

```text
swift test --filter repositoryJobPresentationExposesOnlyValidBoundedActions
swift test --filter repositoryViewExposesDurableJobLifecycle
./scripts/verify.sh repositories
swift test --filter CAMAssistantAppTests
CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all
./scripts/verify.sh package
./scripts/verify.sh smoke
git diff --check
./scripts/verify.sh fresh-clone
```

Results:

- presentation: 1/1 pass;
- native view contract: 1/1 pass;
- repository suite: 33/33 pass;
- app suite: 10/10 pass;
- aggregate suite: 202/202 pass;
- portability checks, app/CLI production builds, unsigned package validation,
  and offline smoke: pass;
- diff check: pass.
- pushed code checkpoint
  `3762c2c7e55c49a5f161f0d21d3ae78cfc2f7c1c`: temporary non-local clone,
  202 tests, release builds, package validation, offline smoke, and clean source
  status all pass.

The final adversarial re-review reported zero Critical, Important, or Minor
findings after removing the unsafe closure-only persistent-runner API.

## Data and authority boundary

Repository job records contain status facts, canonical path, optional saved
source ID, attempt counts, optional completed snapshot receipt, and stable error
codes. They do not contain raw repository text, prompts, model output, secrets,
or exception descriptions.

Indexing remains an explicit local action. It reads committed permitted files
and writes only to the isolated local CAM Assistant vault and derived index. It
does not alter the selected repository, invoke CAM or Codex, or contact a
network.

## Non-claims

This evidence does not prove or implement background scheduling, remote clone
acquisition, submodule traversal, issue ingestion, secret scanning, semantic
observation evaluation, live Codex/CAM execution, network authority, or
source-byte deletion. Those require separate authority, fixtures, tests, and
proof.
