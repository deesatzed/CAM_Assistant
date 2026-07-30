# Isolated Synthetic CAM Mining Checkpoint Proof

**Date:** 2026-07-30  
**Status:** Verified partial CAM-016 implementation. This is an in-process,
structured synthetic mutation proof; it is not a CAM executable invocation or
repository-mining action.

## What is implemented

`CAMIsolatedMiningExecutor` accepts an already-active `CAMMiningRun` with a
consumed exact approval, a typed `CAMIsolatedMiningRequest`, an executor-owned
workspace, and a synthetic adapter seam.

The request accepts a `CAMSyntheticMiningCorpus` made only of fixture and
repository identifiers. It has no source path, database path, configuration,
command, environment, credential, raw repository source, or runtime target.
The request binds the corpus digest, sorted expected write identifiers, and a
strict maximum write count.

Before the adapter receives anything, the executor creates a new operation
directory, materializes one private synthetic JSON copy, and atomically writes
a status-only checkpoint containing the plan digest, run ID, consumed approval
ID, initial corpus digest, expected write IDs, limit, timestamp, and operation
ID. The adapter can return only write identifiers; the executor applies those
identifiers to the copy itself.

The executor rejects an unexpected write set or count as
`postconditionFailed`. A pre-mutation cancellation records `cancelled` and
does not invoke the adapter. Adapter and private-copy failures record `failed`.
Each terminal receipt is saved outside the operation directory before the
executor removes only that operation directory. Successful synthetic mutation
also has no promotion path: its copied corpus is discarded after its receipt is
saved.

Receipts and checkpoints retain IDs, digests, counts, timestamps, terminal
status, and opaque failure codes. They do not retain synthetic corpus bytes or
operation filesystem paths. This operation-local evidence is deliberately not
part of the full-vault backup inventory.

## Verification

Expected-red compilation failures preceded the types and executor:

1. Missing synthetic corpus/request types.
2. Missing checkpoint/adapter/executor types.
3. Missing cancellation parameter.

Then the focused command passed:

```text
swift test --disable-sandbox --scratch-path .swift-build --filter CAMAdapterTests
```

Result: **41 CAM adapter/runtime tests passed**. The new tests prove:

- malformed digest and invalid write bounds fail before mutation;
- the persisted checkpoint binds the active plan, consumed approval, and
  corpus digest before the adapter runs;
- success has a typed receipt and discards the executor-owned operation copy;
- cancellation happens before adapter mutation and discards that copy; and
- unexpected writes fail postconditions, retain no final corpus digest, and
  discard that copy.

## Deliberate boundary

This evidence does **not** prove that `cam mine` works, that a real CAM
configuration/database can be mutated safely, that a selected repository is
read, that a live corpus has an executable rollback, or that the application
can promote an isolated result. It does not grant a live-mining approval.

The next CAM integration slice must attach one separately enumerated external
mining command to an isolated disposable CAM config/database/repository
fixture, revalidate the pinned runtime after approval, enforce the plan's
repository/time limits and idempotency identity, and verify the real post-run
write set before any separately approved personal/live-corpus action.
