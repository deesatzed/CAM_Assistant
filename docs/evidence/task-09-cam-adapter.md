# Task 9 — CAM Adapter Receipt

**Date:** 2026-07-26
**Scope:** CAM-009 only; typed CAM_Codx/CAM_CAM snapshot conformance,
non-executing proposal boundary, and native unavailable-state visibility.
**Branch:** `feat/cam-assistant-foundation`
**Commit at verification:** `7f80d29` (recovery and Tasks 6–9 intentionally
remain uncommitted in this dirty checkout)

## Verified behavior

- Versioned, synthetic fixtures pin a safe subset of the inspected
  CAM_Codx capability contract and CAM_CAM tool names. The contract requires
  CAM_Codx as hub, CAM_CAM as runtime owner, schema version 1, nonempty tool
  names, and unique capability IDs.
- A pure conformance evaluator reports missing or unexpected runtime tools.
  An adapter is `ready` only when the supplied identity, schema version, owner,
  and tool set all match. Missing runtime data is `unavailable`; mismatches are
  `incompatible`.
- A ready adapter produces a `CAMProposal` containing a capability ID, tool
  name, payload digest, state version, and approval class. Read-only proposals
  need no approval; `local_mutation` proposals require exact approval. This is
  only a description: no CAM command, MCP client, process, database, config,
  environment variable, network request, or action dispatch exists in this
  adapter.
- The native CAM section shows the pinned identity and unavailable/degraded
  state read-only. It explicitly explains that execution is disabled and has no
  start, configure, mine, or dispatch control.
- The synthetic mining lifecycle pins only a selected repository identity,
  source-root identifiers, runtime/configuration/database digests, limits,
  expected writes, verification command, recovery path, idempotency key, and
  state version. Its exact action card must be consumed before the lifecycle
  enters `active`; cancellation is terminal; its only executor returns an
  unavailable receipt and performs no I/O.

## Commands and results

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh cam` | Passed 7 CAM contract/adapter/mining-lifecycle tests |
| `/bin/zsh scripts/verify.sh all` | Passed 100 tests and a release build |
| `git diff --check` | Passed before this receipt/tracker update |

## Deliberate limitations and next gate

These are fixture-backed conformance results, not live CAM/Codx runtime
verification. No donor checkout was edited or executed. The observed CAM_CAM
donor has a dirty `claw.toml`, so this milestone did not source configuration,
open a CAM database, inspect secrets, invoke `cam`, call MCP, or mine a repo.
Live CAM execution, mining, and mutating workflows require a separate approved
milestone with privacy policy, exact action-card approval, runtime ownership,
and dedicated integration proof.
