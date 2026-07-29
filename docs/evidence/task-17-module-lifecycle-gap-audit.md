# Dynamic Module Lifecycle Gap Audit

**Date:** 2026-07-28  
**Status:** Read-only implementation inventory. The packaged home-grown module
lifecycle required by `GOAL_FINISH_WIKI.md` is not implemented or proven.

> **Subsequent correction:** Commit `86d08c89e6acb2e86b2bcf2996a7365528554c85`
> added complete declared-permission enforcement to
> `ModuleRegistry.capabilities()`. Current seven-test evidence is recorded in
> `docs/evidence/task-17-module-permission-enforcement.md`. The packaged
> lifecycle, trust, receipts, real health execution, dispatcher, and uninstall
> gaps below remain.

## Scope

This audit compares the current manifest and registry implementation with the
dynamic-module proof gate. It inspects only repository-owned source, fixtures,
tests, schema, and package configuration at commit
`988a53b3b80f90f7f364d149df1110fac7c0f59d`.

## What is currently real

- `ModuleManifest` decodes a versioned typed manifest and validates IDs,
  semantic versions, required text fields, positive health timeout, and unique
  capability IDs.
- Seven repository-owned manifests describe Memory, Capture, Privacy,
  Research, Mac Care, Repositories, and Prompt Library.
- `ModuleRegistry` discovers JSON manifests from a caller-provided directory.
- Discovery alone does not enable a non-core module.
- Enable and disable state is written atomically to a caller-provided JSON
  state file and survives registry restart.
- Permission grants are stored separately from enablement. Undeclared
  permissions are rejected.
- Disabling a non-core module clears its stored grants.
- An unhealthy module removes only its own advertised capabilities.
- Focused tests cover duplicate IDs, invalid versions/permissions, discovery,
  enable/disable persistence, empty initial grants, and isolated health
  degradation.
- Current focused verification:
  `swift test --disable-sandbox --scratch-path .swift-build --filter
  ModuleRegistryTests` passed all six tests. The first run without
  `--disable-sandbox` was invalid because SwiftPM's nested sandbox was denied;
  it is not treated as a product failure.

## What is not yet a usable module system

| Required behavior | Current state | Missing proof or implementation |
|---|---|---|
| Versioned signed or locally trusted manifests | Schema version and provenance/license strings exist | No signature, digest, trust-root, local-trust decision, or receipt policy |
| Packaged discovery | Manifests live under repository `Modules/Core/` | Swift package declares no manifest resources; packaged app does not locate or initialize a registry |
| Native Modules workspace | Goal names a Modules workspace | No Modules section, presentation model, install/enable/permission/health UI, or accessibility journey |
| Install | Adding a JSON file then calling `reload()` is tested | No bounded installer, staging, path validation, package identity, collision policy, atomic promotion, or install receipt |
| Enable without authority leakage | Enablement and grants are stored separately | `capabilities()` advertises enabled healthy capabilities without checking their required grants; no executor currently consumes them, so this is not yet live authority, but dispatch must fail closed |
| Explicit permission changes | Registry can persist a supplied grant set | No expected-state/revision check, approval binding, receipt, native review surface, revocation journey, or audit event |
| Real health checks | A caller-supplied closure returns health | Default health is always healthy; manifest kind/target/timeout is not executed or verified |
| Exercise one home-grown module | Manifests describe possible entry points | No packaged module implementation is installed and invoked through a closed typed capability boundary |
| Disable | Registry disables non-core modules and clears grants | No native or packaged exercise proves capability loss and core isolation |
| Remove/uninstall | Deleting a fixture manifest then reloading would remove it in memory | No uninstall API, receipt, data-retention policy, rollback, or packaged removal journey |
| Rollback | Manifest contains descriptive rollback text | No executable, typed, verified rollback behavior |
| Schema enforcement | A JSON Schema file exists and typed decoding validates a subset | Tests inspect the schema header but do not run a complete JSON Schema validator; Swift validation does not enforce every schema constraint |
| Backup/recovery | Registry state accepts a caller-selected URL | No canonical app-owned module state path or full-vault restore policy |

## Authority and safety conclusions

1. Manifest discovery, installation, enablement, permission grant, capability
   availability, execution, disablement, and removal must remain separate
   state transitions.
2. A capability dispatcher must require the manifest's declared permissions to
   be satisfied by current explicit grants. `isEnabled` and health alone are
   insufficient authority.
3. The first packaged proof should use a native, repository-owned, read-only
   module with no network, process execution, deletion, account, or spend
   permission.
4. Install and uninstall must operate only inside an app-owned module root
   through staging and atomic promotion. They must reject symlinks, path
   escapes, duplicate IDs, incompatible schema/product versions, untrusted
   provenance, and unexpected executable content.
5. Uninstall must define retained-data behavior separately from removing the
   installed module package. It must never delete Layer 1 vault content merely
   because a module is removed.
6. Health failure may withdraw only that module's capabilities. Core local
   memory and chat remain available.
7. Module lifecycle state and receipts need a canonical app-owned location so
   full-vault backup can preserve review history without restoring stale
   runtime health or implicit authority.

## Suggested first bounded proof

A safe first home-grown module can expose one typed, deterministic,
read-only operation over synthetic input—for example, a local text statistics
summary. The proof must package its manifest and implementation, install it
into a disposable application-support root, show zero grants after discovery
and enablement, explicitly grant only `readLocal`, execute the typed operation,
revoke/disable it, remove the package, restart, and prove both capability loss
and unchanged core memory state.

This is a candidate design direction, not an approved implementation design.

## Current proof boundary

The existing module tests prove a useful registry foundation. They do not prove
packaged discovery, trust, installation, real health, permission-enforced
dispatch, executable rollback, uninstall, backup, or an end-to-end home-grown
module lifecycle.

No module was installed, enabled in the live app, executed, removed, or granted
access during this audit.
