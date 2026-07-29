# CAM Runtime Historical Restart State

**Date:** 2026-07-29
**Status:** Verified core/native implementation slice; packaged GUI restart
journey remains open.

## Implemented

CAM Assistant now stores one atomic, schema-versioned
`cam-runtime-history.json` snapshot under its local app root. The snapshot
contains only:

- the latest fully revalidated schema-v2 `CAMVerifiedRuntimePin`;
- at most one bound terminal `cam.stats.snapshot.v1` receipt; and
- the local update time.

Loading revalidates the pin identity instead of trusting ordinary JSON decode.
It fails closed for corrupt or unsupported state, mismatched runtime identity,
invalid receipt digests, invalid timestamps, and contradictory terminal
receipt shapes. Pinning a different runtime clears the stale receipt.

The native CAM view restores saved paths, identity, and receipt as
**historical** evidence. It does not treat restart as runtime verification:
`Run Disposable Statistics Probe` stays disabled until a fresh
current-session `Pin Selected Runtime` succeeds. A local persistence failure
does not become a durable verified result.

## Backup boundary

This file is machine-specific, re-derivable evidence. It contains no config
bytes, secrets, environment, source text, approval, command, capability grant,
mining plan, or personal-corpus content. It is deliberately absent from
`LocalVaultStateFile` and from full-vault package manifests. Ordinary app
restart preserves it; portable restore requires deriving the runtime again.

This is consistent with the established backup design:

- full-vault backup protects authoritative app-owned personal state;
- disposable CAM snapshots protect read-only inspection;
- runtime pins/history describe the current external installation; and
- Time Machine/APFS/encrypted external backup may independently protect the
  external CAM corpus.

## Test evidence

Observed expected failures preceded implementation for the missing core store,
missing native historical gate, and malformed verified-receipt acceptance.

Focused verification passes:

- `./scripts/verify.sh cam`: 25 runtime/probe tests plus 5 restart-state tests;
- `./scripts/verify.sh app`: 24 app tests; and
- `./scripts/verify.sh backup`: 18 backup tests, including explicit runtime
  history exclusion.

The exact final worktree aggregate passes all 312 Swift tests, native app and
CLI release builds, deterministic two-build package manifest
`9ae5537913528eae2e4e9a3f9bc1744ad6344f0ad32a3db18710bc1e2d8d1542`, a
56-file zero-finding credential-signature scan, and direct current debug-binary
offline smoke. The validated 48-gate map remains honestly incomplete at
16 passed, 27 partial, and 5 missing.

## Non-claims

No CAM process, capability discovery, mining executor, provider, MCP server,
network request, approval consumption, personal-corpus mutation, or packaged
GUI restart journey is implemented or claimed by this slice. A future live
executor still requires separately bounded exact approval, postconditions,
idempotency, cancellation, retry, and recovery evidence.
