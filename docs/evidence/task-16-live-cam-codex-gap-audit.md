# Live Bounded CAM/Codex Gap Audit

**Date:** 2026-07-28  
**Status:** Read-only implementation inventory. Live CAM/Codex execution is not
implemented or proven.

## Scope

This audit compares the current fixture-pinned CAM adapter, digest-bound mining
plan, exact approval lifecycle, local orchestration reducer/stores, native CAM
status, and CLI lock probe with CAM-016 and `GOAL_FINISH_WIKI.md`. It does not
inspect or invoke a CAM_Codx/CAM_CAM runtime, configuration, or database. The
source baseline is commit
`45e27e9abdb4b6826fcd177239c9d2b28c2c444e`.

## What is currently real

### CAM contract and mining foundation

- A versioned fixture contract names `CAM_Codx` as hub owner, `CAM_CAM` as
  runtime owner, and a closed capability/tool set.
- A supplied runtime-schema snapshot must have exact ownership, schema version,
  and tool-set conformance. Missing or additional tools fail conformance.
- Runtime identity mismatch, unavailable runtime data, invalid input digest,
  unknown capability, and invalid state version fail before proposal creation.
- A mining plan binds canonical repository path and commit, selected source
  root IDs, runtime/config/database digests, repository/time bounds, expected
  writes, verification command, recovery description, idempotency key, and
  state version into one plan digest.
- Mining begins only after an exact action card and one-use approval are
  consumed.
- Cancellation is a typed terminal state and cannot report success.
- The only current executor is intentionally unavailable and returns a
  status-only failure receipt without touching a runtime or corpus.

### Local coordination foundation

- Versioned append-only events and a reducer enforce legal phases, expected
  state version, ordered sequence, evidence-required verified success, and
  terminal-state refusal.
- Content-addressed evidence, digest-bound snapshots, restart replay, snapshot
  validation, atomic v1-to-v2 migration, and machine/human handoff packets are
  tested.
- An operating-system file lock provides one-process ownership for a run; a
  separately spawned native process proves contention.
- The bounded loop preflights invalid transitions before writing their evidence.
- Current focused verification passed:
  - seven `CAMAdapterTests`; and
  - sixteen `CoordinationTests`, including the native child-process lock probe.

## Missing live integration behavior

| Required behavior | Current state | Missing proof or implementation |
|---|---|---|
| Select and verify a real CAM runtime | Identity is caller-supplied fixture data | No path/process discovery, executable/version digest, live capability query, configuration target, database/corpus identity, or drift check |
| Isolated disposable CAM state | Synthetic JSON fixtures only | No copied disposable config/corpus/database, seeded test data, mutation boundary, cleanup receipt, or before/after proof |
| Closed typed executor | No available executor exists | Define enumerated tool IDs, typed request/response schemas, input bounds, output quarantine, and refusal of undeclared tools |
| Timeout and retry | Plan has maximum duration only | No per-tool timeout, bounded retry classification, backoff, attempt receipt, or non-retriable error policy |
| Idempotency | Plan carries a string key | No durable idempotency registry, duplicate-request replay, write-set comparison, or exactly-once/at-least-once semantics |
| Postconditions | Plan carries a verification command string | No typed verifier execution, expected result, output digest, database/write-set inspection, or proof that failed verification cannot reach success |
| Recovery | Plan carries descriptive recovery text | No executable recovery step, compensating action, restored-state digest, or recovery verification |
| Persisted mining run | `CAMMiningRun` is in-memory and not Codable/stored | No restart, resume cursor, attempt history, runtime-drift recheck, or canonical app-owned run path |
| Approval lifecycle | Generic exact approval is tested | No canonical app approval store, native pending-review flow, expected-current-status resolution, or persisted mining linkage after restart |
| Budget | Step count, repository count, and duration fields exist | No token, byte, tool-call, cost, or per-stage budget accounting and no budget receipt |
| Evidence trajectory | Events cite evidence IDs | No expected/forbidden tool sequence evaluation tying observe/plan/execute/verify to actual executor calls |
| Native controls | CAM screen is status-only | No runtime picker/probe, plan review, approve, run, cancel, resume, recovery, evidence, or receipt controls |
| CLI controls | CLI exposes only an orchestration lock probe | No plan/inspect/approve/run/cancel/resume/status/receipt commands |
| Backup and recovery | Stores accept caller paths | No canonical app-owned CAM/coordination state layout or full-vault restore policy |
| Parallel/graph agents | Disabled by design | No frozen benefit comparison; they must remain disabled |

## Correctness and convergence notes

- `CoordinationRun` and `OrchestrationRunState` are overlapping state models
  with different budget-boundary behavior. A live executor should converge on
  one authoritative reducer before adding controls.
- `OrchestrationStatus.verifiedPartial` exists but the current reducer never
  produces it. It must either gain explicit evidence semantics or remain
  unavailable rather than being inferred by UI.
- Mining lifecycle status has no persisted failed, recovered, completed, or
  verified-success state. The unavailable receipt is honest, but cannot serve
  as a live-run state machine.
- Content-addressed evidence written successfully before an event-log I/O
  failure can remain as an unreferenced derived object. This does not corrupt
  event authority, but cleanup/reconciliation should be explicit for long-lived
  runs.

## Required authority boundary

1. Runtime selection and read-only verification must be separate from action
   authority.
2. Every run pins runtime executable/version, contract, configuration, target
   database/corpus, tool schema, and disposable-state identity before approval.
3. Exact approval binds the complete plan digest, target, state, expiry,
   budgets, expected writes, verifier, and recovery contract.
4. Runtime drift after approval invalidates the approval rather than silently
   re-pinning.
5. Only a closed enumerated executor can run. Retrieved text, repository
   instructions, model output, CAM output, and tool output cannot add tools or
   change policy.
6. Tool outputs are untrusted evidence until typed decoding, size limits,
   redaction, and postcondition verification pass.
7. Cancellation, timeout, exhausted budget, missing/stale approval, retry
   exhaustion, runtime drift, failed postcondition, or failed recovery cannot
   produce `verifiedSuccess`.
8. The first integration uses only isolated disposable CAM state. Any personal
   or live corpus action remains a separate exact approval after the isolated
   proof passes.

## Candidate first bounded proof

The first executor can expose a minimal read-only runtime-status tool plus one
bounded idempotent write to a disposable synthetic corpus, followed by a typed
read-back verifier and tested recovery. The test trajectory should require the
exact declared tools in order and reject any unexpected call. This is a
candidate direction, not an approved implementation design or authorization to
inspect the live CAM repositories/databases.

## Current proof boundary

The 23 focused tests prove contract validation, honest unavailability,
digest-bound planning, exact-approval consumption, cancellation, reducer
authority, durable evidence/replay, snapshots/migration, handoffs, and
cross-process local ownership. They do not prove a live runtime, executable
tool, database/corpus mutation, retry, timeout, postcondition, recovery, native
control, or isolated CAM end-to-end journey.

No CAM process, MCP server, configuration, database, corpus, donor repository,
credential, network request, or live command was inspected or invoked during
this audit.

