# Full-Vault Backup and Fresh-Root Recovery Evidence

**Date:** 2026-07-29
**Status:** Passed for the `wiki.full-vault-backup` goal gate. This evidence
does not claim that unrelated release, provider, web, CAM, Mac Care, or
accessibility gates are complete.

## Contract proved

CAM Assistant now creates one integrity-checked `.camvault` directory from an
explicit local vault root, validates it as untrusted input, and restores it
only into a new absent `CAMAssistant` root. The package contains the SQLite
online-backup snapshot, immutable content objects, and recognized app-owned
JSON state. It never overwrites or merges an existing vault.

The manifest is versioned, product-bound, deterministically sorted, and records
typed relative paths, byte counts, required status, and SHA-256 digests without
source text or credentials. Validation rejects path escape, symlinks, duplicate
or unexpected payloads, object-ID/hash mismatch, malformed recognized state,
corrupt SQLite, non-contiguous migration history, unsupported schema versions,
missing required tables or columns, and foreign-key violations.

Restore validates every byte before destination creation. Watched sources are
paused, approvals and module state are moved to `recovery-review`, and
retrieval generations, repository job leases, locks, and temporary process
state are excluded.

## Focused automated evidence

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh backup` | 18 full-vault manifest, creation, validation, CLI, state-schema checks, reserved-coordination refusal, authority-safe restore, and representative-state tests pass |
| `/bin/zsh scripts/verify.sh app` | 13 native app tests pass, including non-blocking recovery operations, bounded controls, safe errors, and concurrent-operation refusal |
| `/bin/zsh scripts/verify.sh repositories` | 51 tests pass, including the physical-line citation regression discovered during the packaged journey |
| `/bin/zsh scripts/verify.sh fresh-clone` | Exact checkpoint `988015954e42483f3f08c6796f08054fee746ebe` passes portability, the honest 48-gate map, all 244 tests, release builds, reproducible clean package identity, 50-file zero-finding credential scan, and offline smoke from a temporary non-local clone |

The representative full-vault test restores non-empty immutable bytes,
preferences, a cited task, an audit event, research plan, research packet,
knowledge claim, contradiction, repository selection, repository snapshot,
repository job, watched-source state, and schema-v8 SQLite data. It then opens
the restored database and every retained store and proves watched authority is
paused.

Two deliberate red states were observed before implementation:

- malformed recognized JSON was published in an otherwise valid package;
- a schema-v8 SQLite database missing `repository_jobs` passed integrity and
  schema-number checks.

Both now fail closed before package publication.

## Disposable CLI recovery receipt

An earlier populated disposable vault at
`/private/tmp/cam-populated-root.iXTj6b/CAMAssistant` completed:

```text
vault backup: pass
entries: 5
bytes: 156236
manifest: 1533918cd97ef74ccd155c1bda5fc0cacc53b801c8eff798e901890e8ce4bfcb

vault validation: pass
schema: 8

vault restore: pass
destination: /private/tmp/cam-vault-recovery-proof.20260729/restored-support/CAMAssistant
```

The source and restored database counts matched at 3 sources, 3 derived
documents, 1 repository snapshot, and 1 completed repository job. All three
immutable objects retained their exact content identities:

```text
2f504045477073cb7d01bf05c569173a42db0b7bf1fdfbfdaad69e2a416afedf
5c128e0f8661db85bacd9d3acef4fb679237e3f639add528fc7758117743b5d8
9f23fa3e6754f18793365410f20d478575dca6dd3263ee36fe4dfd3013a63011
```

Retrieval generations and repository-job leases were absent after restore.

## Packaged native journey

The unsigned packaged app was launched only against disposable
application-support roots. No normal personal vault was selected.

1. The restored disposable source opened with 3 active Library sources and a
   completed repository job for commit
   `fdb853dbb8729d22119f660cdf1205b62c641f38`.
2. Native repository inspection found a TODO at `README.md:5`. The first
   promotion failed because snapshot receipts counted non-empty lines while
   citations used physical lines. A regression test reproduced the
   self-rejecting citation, and the receipt now preserves physical blank
   lines. All 51 repository tests pass.
3. The rebuilt package created and kept a commit-cited repository idea, saved
   it as one local-read task, created and kept one research plan, generated a
   cited local answer, and kept one knowledge claim.
4. Settings → Backup & Recovery → Create Backup created:

   ```text
   /private/tmp/cam-vault-recovery-proof.20260729/Representative-UI.camvault
   entries: 7
   bytes: 158151
   manifest: ab7b533af8a41f3a7e0be8b156acb378e56e0beaac4d4f22573bdbdcaff75a08
   ```

5. Settings → Validate Backup reported schema 8 and the same entry, byte, and
   manifest receipt.
6. Settings → Restore to New Vault created the previously absent
   `/private/tmp/cam-vault-recovery-proof.20260729/CAMAssistant` root.
7. Relaunching the packaged app against that fresh root showed:

   - Library: 3 active, 0 hidden sources;
   - Tasks: 1 open cited local-read task;
   - Research: 1 kept repository-provenance plan;
   - Repositories: the saved path, completed job, and kept commit-cited idea.

8. Read-only post-relaunch inspection found 3 sources, 3 derived documents,
   1 task, 1 repository snapshot, 1 idea, 1 job, 1 research plan, 1 knowledge
   claim, and 1 repository source. The three immutable object hashes exactly
   matched the source. Retained JSON files were byte-identical, and neither a
   retrieval index nor repository-job lease was restored.

The packaged disposable fixture had no audit rows before backup. The non-empty
audit round trip is therefore proved by the representative integration test,
while the packaged journey proves the native user path and recovered
whole-product presentation.

## Authority and usability boundary

Backup requires one explicit action and one destination. Validation requires
one package selection. Restore requires one package selection and a fresh
parent folder. There is no per-file approval, overwrite control, merge path,
cloud upload, scheduling, or automatic external-drive operation.

The current app does not silently switch its running vault after restore.
Relaunching against the recovered root is explicit; a later convenience action
may streamline that transition without changing the package or authority
contract. Password encryption may wrap the validated package later and is not
part of this gate.
