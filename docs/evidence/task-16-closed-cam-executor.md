# Closed CAM Statistics Executor Proof

**Date:** 2026-07-30
**Status:** Verified partial CAM-016 implementation. This is a closed,
read-only-in-effect statistics tool, not mining authority.

## Implemented boundary

`cam.stats.live-disposable.v1` is the first process-launching CAM tool owned by
CAM Assistant. Its registry contains exactly one compiled invocation:

```text
cam stats --json --config <disposable-config>
```

It accepts no caller-provided command, arguments, environment, database path,
or source content. Before each attempt it revalidates the selected runtime pin,
copies the secret-screened configuration and a WAL-consistent SQLite snapshot,
then launches only the pinned executable through macOS `sandbox-exec`.

The child has a sanitized environment, a private `HOME` and `TMPDIR`, no
network access, and write permission only under its disposable run directory.
The executor caps stdout/stderr, enforces a monotonic timeout, terminates and
escalates a cancelled/timed-out child, decodes only typed statistics, requires
the reported database path to be the disposable copy, independently reads the
same statistics from that copy, revalidates every donor surface, and removes
the workspace. Receipts retain only status, digests, byte counts, exit status,
and typed counts--not raw output, configuration bytes, source content, or
credentials.

Requests carry a runtime identity and idempotency key. A completed identical
request replays the atomically persisted terminal receipt; the same key bound
to a different request fails closed. At most three bounded attempts are
permitted, and only retryable child-launch/process failures retry on a fresh
copy.

Before a child can launch, the executor atomically writes a status-only
in-flight journal keyed by the idempotency-key digest. It contains only schema,
tool, request/runtime/key digests, and start time. A later process finding a
matching journal refuses to relaunch and returns the non-successful
`interrupted_previous_run` receipt. It does not resume, terminate, inspect,
delete, or clean up an unknown previous process/workspace. A terminal receipt
is saved before the executor removes its own journal, so stale journals cannot
override a canonical terminal receipt.

The native closed-tool workspace is app-owned Application Support state, not a
purgeable cache. On restart, the CAM screen reads and validates every journal
before showing its tool, start time, and shortened runtime identity. Invalid
state is visible as unavailable. The UI intentionally has no resume, retry,
kill, cleanup, delete, mining, or corpus action for these records.

The CLI entry point is:

```text
cam-assistant cam runtime-execute-stats PIN_INPUT WORKSPACE RECEIPT_OUTPUT IDEMPOTENCY_KEY [--timeout-seconds N] [--maximum-attempts N]
```

The native CAM screen now exposes the same operation as `Run Closed CAM
Statistics Tool`. It is current-session-only after a fresh pin, has an
explicit `Cancel Closed CAM Statistics Tool` control, reports only typed
receipt fields, and keeps its `Mining, provider calls, MCP serving, and
personal-corpus mutation remain disabled` boundary visible. It accepts no
command text, repository root, approval token, or mutation target.

## Test evidence

Expected-red tests preceded implementation. The focused CAM suite passed:

- `./scripts/verify.sh cam`: 37 runtime/executor tests plus 5 restart-state
  tests; and
- `./scripts/verify.sh app`: 26 native/app tests, including the visible
  closed-tool/cancellation/no-mining contract; and
- the CLI test executed the tool twice and confirmed the second invocation
  replayed its durable receipt.

The tests cover invalid request bounds, runtime drift before launch, external
write denial, mismatched database output, timeout, cancellation, output
limits, retry-on-fresh-copy, idempotent replay, conflicting idempotency keys,
durable interrupted-run refusal without a new launch, and the CLI round trip.
A process failure, timeout, cancellation, output cap, drift, invalid output,
interrupted prior run, or postcondition mismatch produces a non-verified typed
receipt.

The native accessibility/source contract requires the restart-visible
interruption section and its explicit no-resume/no-cleanup explanation.

## Installed-runtime proof

The actual selected CAM installation was pinned at runtime identity:

```text
a6d929e58c1c3beb5d9fcbc9e1571ffbe170881084b1c2aa3b0b4f0b8ace799e
```

The executor ran once against a disposable configuration/database family and
returned a verified receipt:

| Field | Value |
|---|---:|
| CAM process exit | 0 |
| methodologies | 2,557 |
| source repositories | 199 |
| attempts | 1 |
| sandboxed | true |
| workspace retained | false |
| stdout / stderr bytes | 741 / 290 |

The second identical CLI call returned the byte-identical persisted receipt
with `replayed=true`; it did not launch a second CAM process. All seven donor
surfaces--configuration, database family, executable, installation metadata,
interpreter, package, and sqlite extension--matched their before/after
digests. The known pre-existing CAM donor changes (`claw.toml` and empty
SQLite sidecars) stayed exactly as they were.

The first live attempt failed with a typed `process_failed` receipt because
the Codex-hosted sandbox forbade nesting macOS `sandbox-exec`. A scoped launch
permission allowed the same closed command to run in the normal macOS context;
the verified receipt above is the valid proof. The failed host-harness receipt
is not promoted as success.

## Exact-checkpoint aggregate proof

The aggregate verifier retains the strict sub-second wall-clock assertion for
the bounded-hash timeout test. A first 326-test aggregate run exposed
test-runner scheduling contention rather than a missed internal deadline. The
repository aggregate command pins Swift Testing's maximum parallelization width
to one, which keeps that timing proof reproducible without relaxing its
assertion. A release-proof guard rejects missing this control or reintroducing
SwiftPM parallel scheduling.

A temporary non-local clone of exact checkpoint
`acefa12531094cab49fdf46a81e9deaa2cead2c3` then passed repository
portability, the 48-gate map (`16 passed`, `28 partial`, `4 missing`), all
`326` tests, release app/CLI builds, two-build package reproducibility manifest
`b9087a47ded2d6920a45621b892357808edc8f80bc26c290bce71ee192ffe1f3`, package
identity with `dirty=false`, the `57`-file zero-finding credential-signature
scan, and offline smoke.

## Remaining boundary

This does not authorize arbitrary CAM commands, mining, providers, MCP,
network access, source-repository reads, or a personal/live corpus action. It
does not auto-resume, terminate, inspect, or clean up an interrupted process.
Exact-approved mining, mining postconditions, trajectory proof, and a
transaction/rollback checkpoint for corpus mutation remain later CAM-016
slices.
