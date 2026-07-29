# Native CAM Runtime Pin and Disposable Snapshot Proof

**Date:** 2026-07-29
**Status:** Verified partial CAM-016 slice. No CAM process or mining executor
ran.

## Implemented boundary

CAM Assistant now derives a schema-v2 runtime pin from the selected `cam`
launcher instead of trusting typed identity claims. The pin binds:

- launcher, resolved interpreter, installed distribution metadata and editable
  loader;
- imported `claw` package tree and its actual Git commit;
- the installed `sqlite-vec` dependency when present;
- a secret-screened config digest; and
- a stable SQLite main/WAL-family snapshot identity.

The native tool is `cam.stats.snapshot.v1`. It never launches the selected
executable. It stable-copies the selected database plus WAL/SHM sidecars,
copies the config into a temporary workspace, reads fixed statistics from that
copy, re-hashes every donor surface, emits a typed success or failure receipt,
and removes the copied workspace. Inline secret-like config values fail before
copying. No environment file, provider key, model, network transport, CAM
startup, migration, governance, MCP server, or mining command is available to
this tool.

The statistics reader opens SQLite with `SQLITE_OPEN_READONLY` and
`PRAGMA query_only=ON`. A closed WAL-mode main database with no sidecars uses
SQLite's immutable read-only mode; an active WAL snapshot requires the copied
WAL and SHM pair. It streams lifecycle/tag rows under methodology, row, byte,
per-row, and distinct-source ceilings. A monotonic deadline is checked at every
phase boundary, every streamed file/hash chunk and package entry, and SQLite's
progress handler. Package file-count and surface byte ceilings bound inspection
and copying. Cancellation is rechecked after explicit workspace cleanup at the
terminal-state linearization point, a cleanup failure is truthfully retained
in the failure receipt, and a changed disposable-family digest cannot receive
`verified`.

The CLI supports:

```text
cam-assistant cam runtime-inspect EXECUTABLE CONFIG DATABASE PIN_OUTPUT [--timeout-seconds N]
cam-assistant cam runtime-probe PIN_INPUT WORKSPACE RECEIPT_OUTPUT
```

The native CAM screen exposes the same explicit file selection, derived pin,
bounded/cancellable initial hashing, disposable probe cancellation, receipt,
and authority boundary.

## Red/green and adversarial evidence

The initial implementation launched `cam stats --json` against copied state.
Independent review correctly rejected it: output pipes and termination were
not hard-bounded, launcher bytes did not bind the interpreter/package behind
them, plain SQLite copy was not WAL-safe, donor postconditions were incomplete,
and no OS-enforced process confinement existed. The managed macOS environment
also refuses `sandbox-exec`.

That subprocess design was discarded. The replacement native verifier removes
the executable boundary entirely. Focused proof now covers:

- derived interpreter/package/metadata/source identity and behind-launcher
  package drift;
- consistent committed-WAL capture;
- inline credential refusal;
- config, package, executable, interpreter, dependency, and database drift;
- a selected executable that emits unbounded output, ignores termination, or
  attempts an external write is never launched;
- bounded typed statistics and typed terminal receipts;
- deterministic in-hash timeout, cancellation-race, scan-ceiling, disposable
  mutation refusal, and forced-cleanup failure truth;
- initial runtime-pin timeout and cancellation during package hashing;
- read-only closed-WAL and active-WAL handling without creating donor
  sidecars;
- automatic disposable workspace removal;
- CLI pin/probe round trip; and
- native controls and authority wording.

`/bin/zsh scripts/verify.sh cam` passed all 25 CAM tests.
`/bin/zsh scripts/verify.sh app` passed all 24 app tests, including rejection of
stale pin/probe completions after selection invalidation.
The exact final worktree aggregate passed all 307 tests, release-built the
native app and CLI, reproduced two packages with canonical manifest
`b0cf81e4293c43ee3d53d4394ddefd9fe71eae389c137c03be2212c65bbf09b9`,
scanned 55 package/evidence files with zero credential-signature findings, and
passed direct offline smoke.

## Real installed-runtime receipt

The selected installation was:

- launcher `/Users/o2satz/miniforge3/envs/py313/bin/cam`;
- runtime package resolved through the editable install to commit
  `db5495a5b963688a9c29e5d06c5447e781544f1c`;
- config `/Volumes/WS4TB/repo622sn/CAM_CAM/claw.toml`; and
- corpus `/Volumes/WS4TB/repo622sn/CAM_CAM/claw.db`.

The derived runtime identity was
`557d14e9fd5b9e276a2b4d58920bd0a39e2efb220b71743f04bae19f6c2cb45a`.
The stable database-family identity was
`6869f874147511b6ed2f86cc53390dae61fecf1dd2735d52966f4fa319e5a81e`.

The native disposable snapshot returned:

| Field | Value |
|---|---:|
| methodologies | 2,516 |
| source repositories | 197 |
| embryonic / viable / thriving / declining | 2,352 / 144 / 3 / 17 |
| federation configured | true |
| typed output bytes | 156 |
| stderr bytes | 0 |

All seven donor identities—launcher, interpreter, package, installation
metadata/loader, sqlite extension, config, and database family—were identical
before and after. The workspace was automatically removed. The original
launcher/config/main-database file hashes also remained
`9964dddb...fb8`, `13c04f09...597`, and `e391bf17...a74`.

## Backup decision

This slice does not require a second product-managed backup of the personal CAM
corpus. Safety comes from never passing the donor database to CAM, making a
stable disposable snapshot, proving donor identities unchanged, and deleting
the copy. CAM Assistant's existing full-vault package remains the recovery
mechanism for app-owned durable state. Runtime pins and disposable snapshots
are reproducible external-environment evidence, not authoritative personal
vault data; they are re-derived after restore or runtime drift.

Time Machine, APFS snapshots, or an encrypted external backup remain sensible
host-level protection for the external CAM corpus, but they are not a
prerequisite for this native read-only verifier.

## Remaining CAM-016 boundary

This does not implement a live CAM executor, exact-approved mining, durable
runtime-pin/receipt restart state, coordination trajectory, retry/idempotency,
verified mining postconditions, recovery, or personal-corpus mutation. Those
remain separately gated. The first attempted subprocess receipt is invalid
evidence and is not promoted.
