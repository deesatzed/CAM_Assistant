# Full-Vault Backup and Restore Gap Audit

**Date:** 2026-07-28  
**Status:** Read-only implementation inventory. Full-vault backup and restore
are not implemented or proven.

## Scope

This audit maps the durable state currently owned by CAM Assistant against the
backup/restore requirements in `GOAL_FINISH_WIKI.md`. It does not inspect or
copy the user's live application-support directory. It is based on the current
source, migrations, tests, and existing component receipts at commit
`1aef2466d1978006f4c0d516723779f552fefc20`.

The packaging choice remains deliberately open:

- integrity-checked local package; or
- password-encrypted portable package.

Both choices require the same format-independent inventory, integrity
manifest, staging, validation, and fresh-root restore behavior.

## Current durable-state inventory

| State | Canonical current location | Existing evidence | Full-vault gap |
|---|---|---|---|
| Immutable source bytes | `CAMAssistant/content/objects/` | `ContentStore` content-addresses bytes, verifies hashes on read, and has an exact-byte component backup/restore test | No whole-root manifest, consistent snapshot, fresh-root journey, or atomic restore |
| Source metadata, capture provenance, ingest jobs, derived documents, warnings, source visibility | `CAMAssistant/vault.sqlite` | SQLite migrations and ingestion/restart tests | No one-operation database backup tied to the same manifest as immutable bytes and JSON state |
| Status-only audit | `CAMAssistant/vault.sqlite` | `AuditStore` uses SQLite online backup; component test reopens the copied database | Component proof does not establish a consistent whole-vault point in time |
| Tasks | `CAMAssistant/vault.sqlite` | Save/status/restart tests | Not included in a full-root restore journey |
| Repository snapshots, ideas, jobs, and source lifecycle | `CAMAssistant/vault.sqlite` | Restart, cancellation, retry, snapshot-linkage, and removal-lifecycle tests | Not included in a full-root restore journey |
| Model profiles and change receipts | `CAMAssistant/models.json` | Atomic versioned registry and rollback tests | No backup inventory entry or restored-profile journey |
| Hotkey preferences | `CAMAssistant/hotkeys.json` | Atomic persistence and packaged restart journey | No backup inventory entry or restored-registration journey |
| Watched-source selections and enabled state | `CAMAssistant/watched-sources.json` | Atomic persistence and packaged lifecycle journey | No backup inventory entry; restore must not silently begin watching before review |
| Saved repository source selections | `CAMAssistant/repository-sources.json` with SQLite lifecycle authoritative | Crash reconciliation and removal tests | Restore must revalidate path availability and reconcile from SQLite without granting read/index/mining authority |
| Kept research plans | `CAMAssistant/research-plans.json` | Explicit-Keep and restart tests | No full-root restore proof |
| Kept knowledge claims | `CAMAssistant/knowledge-claims.json` | Explicit-Keep and restart tests | No full-root restore proof |
| Kept contradiction candidates | `CAMAssistant/contradictions.json` | Explicit-Keep and restart tests | No full-root restore proof |
| Verified research packets | Store type exists, but no canonical app path is wired | Component Keep/restart test | Define a canonical app-owned path before the full-vault contract can include packets |
| Exact approvals | `ApprovalStore` exists, but no canonical app path is wired | Exact binding, expiry, and one-use tests | Define ownership/path and restore policy; expired approvals must not regain authority |
| Module enablement and permission grants | `ModuleRegistry` state exists, but no canonical app path is wired | Manifest, enable/disable, permission, and health tests | Define ownership/path; restore must not grant permissions merely because a module is present |
| Coordination events, snapshots, handoffs, and evidence | Stores accept caller-selected paths; no canonical app run root is wired | Replay, migration, lease, snapshot, and handoff tests | Define the app-owned run layout and distinguish resumable evidence from disposable leases |
| Retrieval generations | `CAMAssistant/retrieval-index/` | Fingerprinted generation, restart, failed-promotion, and rollback tests | Treat as derived and rebuildable; backup inclusion is optional and must not replace source truth |
| Repository and orchestration lease files, temporary files | Derived process state | Lease and atomic-write tests | Exclude from a portable backup; never restore a stale ownership lease |

## Required format-independent core

A valid full-vault implementation must provide one typed operation with these
properties regardless of the final package format:

1. **Explicit source and destination roots.** Tests and packaged journeys use
   disposable absolute application-support roots. Normal state is never
   selected implicitly during proof.
2. **Consistent database capture.** Copy `vault.sqlite` through SQLite's online
   backup API rather than copying a potentially live database file.
3. **Immutable-object verification.** Re-hash every included object and require
   its lowercase SHA-256 filename to match.
4. **Atomic JSON capture.** Include only recognized app-owned state files and
   hash their exact bytes.
5. **Versioned manifest.** Record relative path, typed role, byte count,
   SHA-256, required/optional status, source schema version, product/build
   identity, and creation time. Do not record raw secrets or source text in the
   manifest.
6. **No path escape.** Reject absolute archive paths, `..`, symlinks, duplicate
   paths, unexpected required entries, invalid hashes, and unsupported critical
   schema versions.
7. **Validate before restore.** Verify every manifest entry and database
   integrity in staging before creating a usable destination root.
8. **Fresh-root restore first.** The initial supported restore target must be a
   new empty application-support root. Overwrite/merge is a separate,
   potentially destructive design.
9. **Authority-safe recovery.** Restored watched sources begin paused until
   reviewed; expired approvals cannot be revived; process leases are excluded;
   unavailable repository paths remain status-only; module discovery or
   enablement cannot create permission grants.
10. **Post-restore proof.** Reopen the database and every retained store;
    confirm object identity, provenance, preferences, tasks, research,
    knowledge, repository receipts, and audit state; then rebuild or validate
    derived retrieval state.

## Current proof boundary

Existing tests prove exact-byte `ContentStore` backup/restore and a separate
SQLite audit backup. They do not prove a consistent full-vault snapshot,
manifest validation, all-state restoration, recovery safety, or a packaged
fresh-root user journey.

No backup package was created, no live application-support state was read, no
credentials were used, and no restore or deletion occurred during this audit.

