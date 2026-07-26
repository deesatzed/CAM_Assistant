# Task 10 — Research and Knowledge Receipt

**Date:** 2026-07-26
**Scope:** CAM-010 only; local research checkpoints, citation-bound packets,
fact/inference separation, knowledge candidates, and read-only native status.
**Branch:** `feat/cam-assistant-foundation`
**Commit at verification:** `7f80d29` (recovery and Tasks 6–10 intentionally
remain uncommitted in this dirty checkout)

## Verified behavior

- Local research runs validate nonblank, unique queries, start ephemeral, and
  resume deterministically from an exact checkpoint version. A stale resume
  fails visibly.
- A research packet accepts facts only when every supplied quote is present in
  the local `ContextBundle`. Forged facts fail. Inferences are labeled
  separately and must reference verified facts in the same packet.
- Knowledge claims and assumptions are citation-bound candidates. Manual
  contradiction records retain two distinct cited positions and an optional
  bridge suggestion; they do not merge sources or select a winner.
- The native Research section is informational only and says that external
  execution and automatic retention are disabled.

## Commands and results

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh research` | Passed 5 research lifecycle/evidence/presentation tests |
| `/bin/zsh scripts/verify.sh knowledge` | Passed 2 claim/contradiction tests |
| `/bin/zsh scripts/verify.sh all` | Passed 81 tests and a release build |
| `git diff --check` | Passed before this receipt/tracker update |

## Deliberate limitations and next gate

No web request, cloud model, CAM request, database persistence, background
schedule, automatic retention, spend/cost collection, or external source
acquisition exists here. This milestone provides the local evidence and
checkpoint contract those future adapters must honor. CAM-011 next adds
read-only repository/Mac assessment boundaries, with any mutation remaining
separately exact-approved and undo-bound.
