# Task 11 — Repositories and Mac Care Receipt

**Date:** 2026-07-26
**Scope:** CAM-011 only; read-only selected-repository intake/idea proposals
and bounded Mac Care assessment/planning.
**Branch:** `feat/cam-assistant-foundation`
**Commit at verification:** `7f80d29` (recovery and Tasks 6–11 intentionally
remain uncommitted in this dirty checkout)

## Verified behavior

- Repository intake uses read-only Git identity/status queries and local file
  enumeration. A temporary fixture proves its source bytes and Git status are
  unchanged while canonical path, branch, commit, dirty state, license, and
  sorted file evidence are captured.
- Idea cards require exact commit/file/line/symbol evidence, counterevidence,
  license, confidence, and a smallest validation experiment. Promotion yields
  a research-packet proposal only; it cannot copy code, change a repository,
  or invoke CAM mining.
- Mac Care can read caller-selected volume capacity and selected application/
  startup directories. Its assessment produces a stable digest. Plans bind to
  that digest, require exact approval, and refuse stale state.
- Apply and undo have no executor and fail closed. The native Repository and
  Mac Care sections communicate these boundaries read-only.

## Commands and results

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh repositories` | Passed 2 read-only intake/idea proposal tests |
| `/bin/zsh scripts/verify.sh mac-care` | Passed 3 assessment/plan/unavailable-executor tests |
| `/bin/zsh scripts/verify.sh all` | Passed 86 tests and a release build |
| `git diff --check` | Passed before this receipt/tracker update |

## Deliberate limitations and next gate

No user repository, donor repository, CAM database, CAM config, CAM mining
command, Homebrew package, application, startup item, service, preference, or
file was modified. A future execution milestone must bind each requested CAM
mine or Mac action to an exact approved card, live state, verification, and an
available undo path before it can run.
