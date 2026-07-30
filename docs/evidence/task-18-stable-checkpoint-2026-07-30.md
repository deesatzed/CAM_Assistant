# Stable checkpoint — 2026-07-30

## Candidate

- Repository: `https://github.com/deesatzed/cam_wiki.git`
- Branch: `agent/portable-canonical-repo`
- Commit: `a01b150ab259f373cd576462d76a84749dc86a46`
- Working tree: clean before this documentation receipt was written.

## Reproduced proof

The repository-owned fresh-clone verifier completed from a disposable,
non-local checkout of the candidate commit:

```text
/bin/zsh scripts/verify-fresh-clone.sh
```

That verifier runs portability, the serial aggregate suite, release build,
deterministic package validation, credential-signature scan, offline smoke,
and a tracked-file cleanliness check in the clone. The current candidate also
has the saved release privacy receipt
`docs/evidence/task-18-release-privacy-scan.json`, which records 58 scanned
files and zero findings.

The serial scheduling is intentional: Swift test timing fixtures have shown a
parallel-scheduling flake. The verifier sets the supported serial scheduling
environment rather than hiding or skipping those tests.

## What this checkpoint proves

- A fresh checkout can build, test, package, and smoke-run without untracked
  parent-workspace dependencies.
- The native offline-first foundations and their current aggregate regression
  suite are portable at this commit.
- The current release privacy signature receipt is clean.

## What it does not prove

- It is not final product completion. The machine-readable goal map remains
  `incomplete`: 16 passed, 28 partial, and 4 missing gates out of 48.
- Synthetic isolated CAM mining mutation/rollback proof is not real `cam mine`
  execution, personal-corpus mutation, or a live CAM trajectory.
- Named local-model quality/latency, broad repository intelligence, complete
  coordination, packaged GUI/accessibility coverage, Mac actions, and module
  lifecycle proof remain active work.

## Admission rule for waiting integration arms

Do not merge an arm merely because it is available. Before admission, record a
small integration packet that names: its owner and license, data it reads or
writes, permissions/network/mutation boundary, visible user journey, rollback
or disable path, and an end-to-end proof target. The core app must remain
useful offline when that arm is disabled or unavailable.

This preserves the three-layer product direction while allowing one arm at a
time to earn a narrow, testable place in it.
