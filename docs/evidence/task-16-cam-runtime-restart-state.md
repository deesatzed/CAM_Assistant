# CAM Runtime Historical Restart State

**Date:** 2026-07-29
**Status:** Verified core/native implementation plus packaged GUI restart
journey.

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
- `./scripts/verify.sh app`: 25 app tests; and
- `./scripts/verify.sh backup`: 18 backup tests, including explicit runtime
  history exclusion.

The exact final worktree aggregate passes all 313 Swift tests, native app and
CLI release builds, deterministic two-build package manifest
`628822441262b3bfc75d03629464e3049d534c002aa6d154474b06eadf6b69a0`, a
56-file zero-finding credential-signature scan, and direct current debug-binary
offline smoke. The validated 48-gate map remains honestly incomplete at
16 passed, 27 partial, and 5 missing.

A clean temporary non-local clone of pushed checkpoint
`0528cb8aca357504d2292fbf4bf876878c20c76a` independently passed the same
312-test, release-build, package, identity, privacy, and offline-smoke path.
It reported `dirty=false` and clean-clone reproducibility manifest
`e2707e1c1f948551004a8a949011dce89e12a629a04520b1e1568fd93f0c1830`.

## Packaged native restart journey

The package was launched only against disposable application-support root
`/private/tmp/cam-runtime-gui-proof.FQO9Vl`.

The initial accessibility tree revealed a genuine failure before the journey:
the visible Executable picker was absent while the Configuration and Database
pickers were exposed. After adding an explicit contained and named boundary to
each reusable selection row, the rebuilt package exposed:

- `Executable runtime selection` and `Select CAM Executable…`;
- `Configuration runtime selection` and `Select Configuration…`; and
- `Database runtime selection` and `Select Database…`.

The packaged app then selected:

- `/Users/o2satz/miniforge3/envs/py313/bin/cam`;
- `/Volumes/WS4TB/repo622sn/CAM_CAM/claw.toml`; and
- `/Volumes/WS4TB/repo622sn/CAM_CAM/claw.db`.

Pinning displayed runtime identity
`557d14e9fd5b9e276a2b4d58920bd0a39e2efb220b71743f04bae19f6c2cb45a`
and the explicit message `No CAM process was started`. The native disposable
probe displayed `2,516` methodologies, `197` repositories,
`cam.stats.snapshot.v1`, and verified copied-state status.

The atomic history receipt independently reported:

- `workspaceRetained=false`;
- all seven executable/interpreter/package/install-metadata/sqlite/config/
  database donor surfaces unchanged; and
- the expected stable launcher/config/main-database hashes.

After quitting and relaunching the package against the same root, the
accessibility tree exposed `Historical pinned identity`, `Historical receipt`,
the prior statistics, and a disabled `Run Disposable Statistics Probe`.
`Re-pin this runtime before running another probe` was visible. Re-pinning
changed the heading to current `Pinned identity` and re-enabled the probe.

This is an actual packaged lifecycle proof. It is not source inspection,
fixture-only persistence, or a claim that CAM executed.

After the implementation was committed and pushed, the same bounded journey
was repeated with the package built from exact implementation commit
`3ed8704e67a24e08aab5300d5cd1eedf1b68436d`, bundle build `75`, and embedded
`dirty=false`. Re-pin and disposable probe again returned `2,516`
methodologies, `197` repositories, and output hash
`11d5213255813eca1ec0b2c601b0ca64c57bdbcaef4ac5709da91e3677824fdf`.
Quit/relaunch again restored `Historical pinned identity` and `Historical
receipt`, disabled the probe, and required re-pin.

A clean temporary non-local clone of that implementation commit then passed
all `313` tests, release builds, package identity, the `56`-file zero-finding
credential-signature scan, and offline smoke. Its deterministic package
manifest is
`8287301b9725b3b136953827e51fab3285cba4240ace5ab9e97bf089fe34eaa9`.

## Non-claims

No CAM process, capability discovery, mining executor, provider, MCP server,
network request, approval consumption, or personal-corpus mutation is
implemented or claimed by this slice. A future live executor still requires
separately bounded exact approval, postconditions, idempotency, cancellation,
retry, and recovery evidence.
