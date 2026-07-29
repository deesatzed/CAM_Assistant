# CAM Runtime Restart State Design

**Date:** 2026-07-29
**Status:** Approved by the existing `GOAL_FINISH_WIKI.md` CAM-016 contract and
the user's autonomous-continuation confirmation.

## Goal

Preserve the latest derived CAM runtime pin and terminal disposable-probe
receipt across app restart without treating restored evidence as current
authorization or enabling CAM execution.

## Approaches considered

1. **Atomic versioned JSON snapshot — selected.** This matches existing local
   state conventions, is small, inspectable, reversible, and needs no database
   migration. One snapshot binds a validated schema-v2 pin to at most one
   terminal receipt.
2. **SQLite tables.** This would provide queryable history, but adds migration
   and backup coupling before the product needs multi-run reporting.
3. **Coordination event log.** This would provide a trajectory, but incorrectly
   mixes passive machine-specific evidence with future execution authority and
   is larger than the restart-state gate requires.

## Data and authority boundary

The file `cam-runtime-history.json` lives in the app-owned local root and uses
atomic replacement. Its decoder revalidates the embedded runtime pin and
receipt binding rather than trusting ordinary `Codable` decoding.

Restored state is historical:

- it may prefill the six selected runtime paths;
- it may display the last terminal receipt;
- it cannot run another disposable probe until the app derives a fresh pin in
  the current process;
- it contains no configuration bytes, secret values, environment, approval,
  capability grant, mining plan, command, or personal-corpus content.

A new successful pin replaces the prior pin and clears an incompatible prior
receipt. A terminal probe receipt is persisted only when it binds to that pin.
Corrupt, unsupported, or mismatched state fails closed and does not become
usable UI state.

## Backup and recovery

This machine-specific history is intentionally not added to
`LocalVaultStateFile` and therefore is not part of portable full-vault backup.
The local file survives ordinary app restart. After a vault restore or move to
another Mac, the runtime must be selected and derived again. This preserves the
existing decision that portable backup owns personal vault truth while runtime
pins are reproducible external-environment evidence.

## UI behavior

The CAM screen loads saved evidence on appearance. Restored identity and receipt
sections are labeled historical, and the probe button remains disabled with a
clear “re-pin to revalidate” message. A fresh current-session pin changes the
label to current and enables the existing disposable read-only probe. Save
failure is shown as a local-state failure and does not turn an operation into
verified success.

## Proof

Tests must first fail for:

- pin and receipt round-trip across store recreation;
- corrupt/unsupported state refusal;
- receipt-to-pin binding refusal;
- replacement pin clearing a stale receipt;
- explicit exclusion from portable recognized state;
- native source contract showing historical restoration and current-session
  revalidation before probing.

Focused CAM, app, backup, and aggregate verification remain required. No CAM
process, mining, network, provider, MCP, donor mutation, or user approval is
part of this slice.
