# Full-Vault Backup and Restore Design

**Date:** 2026-07-29

**Status:** Approved direction for the first local recovery implementation.
The integrity-checked package is the format-neutral foundation. Password
encryption may wrap a validated package later without changing its manifest or
restore rules.

## Outcome

CAM Assistant can create one local backup package from its current vault and
restore that package into a new empty application-support root. The operation
recovers immutable source bytes, SQLite-owned metadata and audit state, user
preferences, tasks, research plans and packets, retained knowledge,
repository receipts, and any other recognized app-owned durable state.

The first restore path never overwrites or merges an existing vault.

## Package

The first package is a directory ending in `.camvault`:

```text
CAM-Assistant-Backup.camvault/
  manifest.json
  payload/
    vault.sqlite
    content/objects/...
    models.json
    hotkeys.json
    watched-sources.json
    repository-sources.json
    research-plans.json
    research-packets.json
    knowledge-claims.json
    contradictions.json
    approvals.json
    module-state.json
```

Only existing recognized files are included. `vault.sqlite` is required.
Content objects and recognized JSON files are optional so a new or partially
configured vault remains backupable.

The manifest reserves a future coordination role, but V1 emits and accepts no
coordination entry because the app does not yet own one canonical typed run
layout. A package carrying that reserved role fails validation. Typed
coordination recovery requires its own path, migration, replay, and
authority-resumption contract.

The versioned manifest records a relative payload path, typed role, byte count,
SHA-256 digest, required status, source schema version where applicable,
product identity, package creation time, and entry count. It contains no
source text, prompt content, credentials, approval payloads, or other raw
vault data.

## Backup flow

1. Resolve an explicit source vault root and destination package URL.
2. Reject a missing source database or an existing destination.
3. Create a private sibling staging directory.
4. Use SQLite's online backup API to capture `vault.sqlite` first.
5. Copy recognized immutable objects and state files into `payload/`.
6. Reject symlinks, temporary files, unrecognized root state, invalid object
   names, or changed bytes.
7. Hash every payload file and write the sorted manifest atomically.
8. Validate the staged package as if it were untrusted input.
9. Atomically move staging to the requested `.camvault` destination.
10. Return a status-only receipt with package path, counts, bytes, and
    manifest digest.

Capturing the database before immutable objects preserves every object
referenced by the database because ingestion writes immutable bytes before
committing their metadata. Concurrent later objects may be included but cannot
invalidate restored database references.

## Validation and restore

Validation rejects:

- unsupported manifest versions;
- absolute paths, `..`, empty components, duplicate paths, or path escape;
- symlinks anywhere in the package;
- missing, extra, or unrecognized payload files;
- byte-count or SHA-256 mismatch;
- malformed content-object paths or object IDs;
- invalid SQLite integrity or unsupported schema;
- a destination that already contains a CAM Assistant vault.

Restore validates the complete package before creating the destination. It
then copies into a private staging root, applies authority-safe recovery, opens
the database and retained stores, and atomically moves the staged vault into
the new destination.

If any step fails, the destination remains absent.

## Authority-safe recovery

- Every restored watched source is persisted as paused.
- Repository selections remain status-only and are revalidated only when the
  user explicitly inspects or indexes them.
- Expired and consumed approvals remain non-authoritative. Unexpired approvals
  are restored as historical records but are not automatically consumed or
  executed.
- Module state is retained only as review state. Restore grants no capability
  and starts no module.
- Coordination lock files, process leases, temporary files, and retrieval
  generations are excluded.
- Retrieval generations are rebuilt from restored source truth after the
  restored vault opens.

## User experience and approvals

Backup is one explicit local action plus a save destination. Restore is one
package selection, validation summary, and confirmation of a new destination.
There is no per-file approval.

V1 exposes no overwrite, merge, cloud upload, scheduling, password recovery,
or automatic external-drive operation. Those are separate product decisions.

## Verification

Core tests use only disposable roots and prove:

- complete round-trip of SQLite, immutable bytes, and every recognized store;
- exact manifest and content-object integrity;
- tampering, traversal, symlink, duplicate, unexpected-file, and schema
  rejection;
- paused watched sources and excluded leases/caches;
- failed restore leaves no destination;
- CLI backup, validate, and fresh-root restore;
- packaged native backup and restart/recovery journey against an isolated
  application-support root.
