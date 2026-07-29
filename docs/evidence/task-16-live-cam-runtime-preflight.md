# Live CAM Runtime Identity and Disposable Preflight

**Date:** 2026-07-29
**Status:** Partial proof. A real installed runtime, configuration, and corpus
were identified and a disposable-copy health path passed. CAM Assistant does
not yet perform this verification or execute CAM.

## Scope and authority

This was a bounded inspection of the selected CAM family:

- workflow hub: `/Volumes/WS4TB/repo622sn/CAM_Codx`;
- runtime owner: `/Volumes/WS4TB/repo622sn/CAM_CAM`;
- selected config: `/Volumes/WS4TB/repo622sn/CAM_CAM/claw.toml`;
- selected corpus: `/Volumes/WS4TB/repo622sn/CAM_CAM/claw.db`;
- selected environment file:
  `/Volumes/WS4TB/repo622sn/CAM_CAM/.env`, checked by key name only.

No environment value was printed or copied. No model/provider request, MCP
server, mining command, repository mutation, corpus write, or app integration
was authorized or performed.

## Pinned identities

| Surface | Reproduced identity |
|---|---|
| `CAM_Codx` | commit `60f747db61791a6addba8db1cbafbd5121fd2a29`; clean working tree; local `main` is two commits ahead of `origin/main` |
| selected `CAM_CAM` | commit `db5495a5b963688a9c29e5d06c5447e781544f1c`; `claw.toml` has a preserved local modification |
| installed `cam` | `/Users/o2satz/miniforge3/envs/py313/bin/cam`; distribution `claw` version `0.1.0`; entry point `claw.cli:app_main` |
| installed runtime source | `/Volumes/WS4TB/WS4TBr/CAM_Codx/CAM_CAM/src/claw`; commit `db5495a5b963688a9c29e5d06c5447e781544f1c`; clean working tree |
| selected config | SHA-256 `13c04f0939142042bc560849b0ea7193d9a9d9cbddfd02ee949094312f4f7597`; 22,068 bytes |
| selected corpus | SHA-256 `e391bf171f66c2086ad8b8785432d9b142f8f4c5a9ad5e7f8db41ea69339ca74`; 124,362,752 bytes |

The installed CLI resolves through a second checkout rather than the selected
runtime-owner path. The two runtime checkouts had the same commit during this
audit, but path identity remains different and must be pinned and drift-checked
separately.

`cam --version` is not implemented, so package metadata, executable digest,
entry-point identity, source path, and Git commit are required together. The
executable SHA-256 was
`9964dddbf518643a138782618d56f3b85f02e42f3c1e60d464aa3fd06f309fb8`.

## Read-only preflight

The CAM_Codx session preflight reported:

- target hub, runtime, corpus, config, and environment paths present;
- the `OPENROUTER_API_KEY` key present by name only;
- the `cam` CLI present with all 35 expected command names visible in help;
- the selected corpus directory not writable from this managed audit context,
  preventing SQLite WAL sidecars.

Direct immutable SQLite checks against the selected corpus passed
`PRAGMA quick_check` and reported:

| Metric | Value |
|---|---:|
| methodologies | 2,516 |
| source repositories reported by CAM | 197 |
| projects | 112 |
| mining outcomes | 1,768 |
| FTS methodology rows | 2,516 |
| embryonic / viable / thriving / declining | 2,352 / 144 / 3 / 17 |

The native SQLite client could not load CAM's `vec0` extension, so vector-table
row counts were not independently queried. The CAM disposable-copy path loaded
`sqlite-vec` successfully.

## Critical read-only defect

Running `cam stats` or `cam status` directly against the protected selected
corpus failed with `unable to open database file`. The runtime connection path
unconditionally executes `PRAGMA journal_mode=WAL`; both commands also apply
migrations and initialize schema. `cam status` additionally ran startup
governance.

Therefore these CLI commands are not observationally read-only even though
their command surface is described as read-only. CAM Assistant must not run
them against the personal/live corpus under a read-only permission.

## Disposable-copy proof

The exact selected database and config were copied to
`/private/tmp/cam-runtime-audit.4jZOMX`. With both
`CLAW_DB_PATH` and `CAM_CODEX_MCP_DB_PATH` pinned to the copied database:

- `cam stats --json` passed and reported 2,516 methodologies, 197 source
  repositories, federation enabled, and a stale/unloaded CAG cache;
- `cam status` passed, loaded `sqlite-vec`, initialized the configured four
  agent adapters, and reported Ollama unavailable;
- all four provider-backed agents were unavailable because credentials were
  intentionally not loaded into the disposable process;
- `cam doctor expectations` passed its configuration/wiring checks for learn,
  reassess, validate, standalone output, and builder wiring.

Those expectation checks prove that code paths are wired, not that an agent,
provider, builder, miner, or verifier executed successfully.

The copied database SHA-256 changed from the selected-corpus digest to
`373bd139c1369729aa98fd6854b35f3c8b5baf2a3945860880124638290c9dd4`
after the nominal health commands. Its size remained 124,362,752 bytes. This
directly confirms startup mutation and establishes disposable-copy probing as
the only safe current path.

After the audit, the selected corpus and config hashes were unchanged and both
donor Git states matched their preflight states.

## Gate effect

`cam.runtime-verification` moves from `missing` to `partial`:

- real runtime, executable, package, source checkout, config, database, corpus,
  capability-help, health, and drift identities are now reproducible;
- the mutation boundary and installed-source-path mismatch are directly
  evidenced;
- the current CAM Assistant still has only a fixture-pinned adapter and does
  not discover, pin, copy, verify, display, approve, or invoke this live
  runtime.

The next implementation must make a selected-runtime identity a typed,
digest-bound app record; copy the corpus/config into isolated disposable
state; run only a closed status probe there; compare source and copy hashes;
quarantine output; and refuse any runtime or configuration drift. Mining,
provider calls, MCP serving, and live-corpus mutation remain separate exact
approvals after that proof.
