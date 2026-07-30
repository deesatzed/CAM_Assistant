# Closed CAM Executor Design

**Date:** 2026-07-29  
**Status:** Approved by the controlling `GOAL_FINISH_WIKI.md` CAM/Codex
execution contract.

## Problem

CAM Assistant can pin a real CAM runtime and read statistics natively from a
disposable database snapshot, but it deliberately never launches CAM. The
next product gate requires a closed executor that can prove one real,
enumerated CAM tool without granting arbitrary command, mining, provider, MCP,
network, or personal-corpus authority.

## Approaches considered

### 1. Keep the native snapshot verifier only

This is the safest current behavior, but it cannot satisfy the live bounded
CAM/Codex goal because no CAM code executes.

### 2. Add a generic subprocess wrapper

This would make future tools easy to add, but an argument- or shell-driven
interface would create ambient command authority, make approval binding weak,
and make postconditions tool-dependent and easy to omit. This approach is
rejected.

### 3. Add a closed typed tool registry

The registry initially contains exactly one tool:
`cam.stats.live-disposable.v1`. Its arguments, environment, output schema,
retry policy, bounds, sandbox, and postconditions are compiled into the app.
This is the selected approach.

## Architecture

`CAMClosedToolRequest` names a typed tool, a verified runtime pin, an
idempotency key, a bounded attempt count, timeout, and output limit. It contains
no free-form executable, arguments, environment, shell, or repository path.

`CAMClosedToolExecutor`:

1. validates the request and re-derives the complete runtime identity;
2. checks a local idempotency receipt store;
3. creates a unique operation directory beneath an explicit app-owned
   workspace;
4. copies the secret-free config and a WAL-consistent SQLite snapshot;
5. launches the pinned CAM executable through `/usr/bin/sandbox-exec`;
6. supplies only compiled `stats --json --config <copy>` arguments and a
   sanitized environment pointing `CLAW_CONFIG` and `CLAW_DB_PATH` at copies;
7. denies network and writes outside the operation directory;
8. bounds time, attempts, stdout, and stderr and propagates cancellation;
9. decodes only the typed statistics fields and rejects output whose database
   path is not the disposable database;
10. independently reads the disposable database and requires exact statistic
    agreement;
11. revalidates all donor runtime/config/database surfaces;
12. removes the disposable workspace before verified success; and
13. atomically saves a status-only receipt keyed by a digest of the
    idempotency key.

A repeated identical request returns the prior terminal receipt without
launching CAM. Reusing an idempotency key for a different request fails closed.

## Failure and recovery

Typed terminal outcomes distinguish invalid request, runtime drift, sandbox
failure, launch failure, nonzero exit, timeout, cancellation, output limit,
invalid output, postcondition failure, donor drift, and cleanup failure.
Retries are allowed only for a closed retryable failure set, always on a fresh
copy, and never after cancellation, drift, invalid output, postcondition
failure, or cleanup failure. No failure can become verified success without a
successful final attempt and all postconditions.

The first slice persists terminal receipts and fail-closed durable in-flight
state. An interrupted run is safe because its authority is limited to a
disposable directory; the native app shows restart-visible status only. It
does not resume, inspect, clean up, or control the unknown prior process.

## User and authority boundary

The existing native-only probe stays available. The live disposable tool is a
separate, explicitly labeled operation. It does not accept mining plans,
repository roots, provider configuration, credentials, or personal database
targets. Adding any later tool requires a new enum case, typed input/output,
tests, postconditions, and an explicit authority decision.

## Proof

The implementation must demonstrate:

- expected failing tests before production code;
- successful sandboxed execution against a synthetic pinned runtime;
- denied external write and network attempts;
- runtime and donor-database nonmutation;
- typed output and independent SQLite postcondition agreement;
- bounded output, timeout, cancellation, retry, and cleanup;
- idempotent replay plus conflicting-key refusal;
- a CLI receipt path with status-only output;
- a real disposable execution against the selected installed CAM runtime;
- focused CAM verification, aggregate verification, and clean-clone proof.
