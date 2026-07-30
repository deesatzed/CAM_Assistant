# Real Disposable CAM Mining Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this
> plan task-by-task.

**Goal:** Run one exact-approved `cam mine` command against an app-owned,
temporary CAM configuration, SQLite corpus family, and Git repository fixture;
record bounded status-only evidence; and discard every mutable copy.

**Architecture:** This is a new closed executor beside the existing synthetic
proof, not a widening of it. The caller supplies an already-active
`CAMMiningRun`, a revalidated runtime pin, and fixture descriptors that are
restricted to an executor-owned temporary root. Before launch, the executor
copies the fixture repository/config/database family, writes a status-only
checkpoint, launches only the enumerated `mine` argument vector through the
existing sandboxed process pattern, verifies the copied database family and
donor fixture digest, saves a status-only receipt outside the operation, and
deletes the operation on every terminal path. No result is promoted.

**Tech Stack:** Swift 6.3, Foundation, CryptoKit, SQLite3, macOS
`sandbox-exec`, Swift Testing, shell-script CAM fixture, temporary directories.

---

## Non-negotiable boundary

- The executor accepts no personal/live CAM config, database, corpus, or
  selected user repository path.
- A test fixture is constructed beneath a temporary root and the executor
  rejects symlinks, paths outside that root, non-Git repositories, and dirty
  fixture input before copying.
- The only subprocess is the fixed `cam mine <copied-repository>` invocation
  with fixed bounded flags. It has no shell command, provider, MCP, network,
  arbitrary environment, or promotion channel.
- A successful disposable run proves only that the closed integration works on
  the fixture. It is not live mining authorization.

## Current platform finding

The first test-first external runner was not retained. Its fixed `mine`
argument vector launched a shell CAM fixture, but three candidate
`sandbox-exec` profiles all denied the fixture's write to the copied SQLite
database. The executor therefore reported a non-success terminal state and
was removed rather than weakening the profile or treating a no-op as mining.
The separately committed fixture-root admission contract remains green.

Before Task 2 is resumed, add one minimal platform probe that proves a child
can write inside an executor-owned operation root while a companion probe
proves it cannot write a sibling/outside marker. Only then may that profile be
used for the real disposable command.

### Task 1: Freeze the disposable external-command contract

**Files:**

- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`
- Modify: `Sources/CAMAssistantCore/CAM/CAMMiningLifecycle.swift`

1. Add a test for a `CAMDisposableMiningRequest` that rejects non-fixture
   paths, symlinks, dirty/non-Git input, mismatched runtime digest, unsafe
   expected output identifiers, and unbounded repository/duration values.
2. Run `/bin/zsh scripts/verify.sh cam` and observe the missing request/error
   failure.
3. Add only typed request, checkpoint, receipt, status, and error values.
   Persisted data may contain IDs, digests, counts, fixed tool ID, and times;
   it may not include source bytes, command output, configuration bytes,
   absolute paths, or credentials.
4. Re-run the focused CAM suite and record the green result.

### Task 2: Implement closed execution and disposal

**Files:**

- Modify: `Sources/CAMAssistantCore/CAM/CAMMiningLifecycle.swift`
- Modify: `Tests/CAMAssistantCoreTests/CAMAdapterTests.swift`

1. Add a failing fixture integration test proving the checkpoint exists before
   launch, the argument vector is exactly `mine` plus bounded options, and the
   fixture donor repository/database bytes and Git status remain unchanged.
2. Add the minimal executor: copy config/database SQLite family and clean Git
   fixture under a generated operation root, sandbox the command, bound time
   and output, and write terminal status-only evidence before deleting the
   root.
3. Add failing cancellation, timeout, process-failure, unexpected-write, and
   postcondition-drift tests. Each must prove no `verified` receipt and no
   retained mutable copy.
4. Implement only the resulting terminal paths, reusing the bounded process
   termination approach already tested by `CAMClosedToolExecutor`.
5. Run `/bin/zsh scripts/verify.sh cam` and then the serial focused suite.

### Task 3: Prove, document, and publish the isolated vertical slice

**Files:**

- Create: `docs/evidence/task-16-real-disposable-cam-mining.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json` only if a gate's
  verdict truthfully changes

1. Run `git diff --check`, `./scripts/verify.sh cam`,
   `./scripts/verify.sh goal-map`, and the aggregate verifier.
2. Run the disposable integration test with the fixture's real shell `cam`
   command and save only command/result counts and digests.
3. State exactly what remains: selected-repository intake, actual runtime
   admission, live/personal corpus exact approval, promotion, trajectory
   proof, and coordination UI/CLI are still absent.
4. Commit the code, tests, and evidence together; push only the repository
   branch after all checks pass.
