# Task 8 — Privacy and Action Cards Receipt

**Date:** 2026-07-26
**Scope:** CAM-008 only; deterministic local classification, outbound policy,
exact approval binding, and status-only audit evidence.
**Branch:** `feat/cam-assistant-foundation`
**Commit at verification:** `7f80d29` (the recovery and CAM-007/CAM-008 work
remain intentionally uncommitted in this dirty checkout)

## Verified behavior

- A frozen synthetic fixture manifest covers `public`, `generic`,
  `contextual`, `proprietary`, secret, credential, PII, PHI, path-traversal,
  and prompt-injection cases.
- Classification is deterministic. A multi-fragment result cannot have a lower
  risk than any contributing fragment. Restricted text is represented as
  `[REDACTED:RESTRICTED]`; proprietary/contextual content is abstracted.
- Local requests remain local. Public/generic cloud or web intent creates only
  a typed redacted proposal. Contextual, proprietary, and restricted requests
  are blocked. Every frozen restricted fixture reports outbound byte count `0`,
  including explicit `WRGR` intent.
- Action cards require nonempty goal/module/target/access/exclusion/risk/undo
  details. An exact approval binds the card ID, operation, target, payload
  SHA-256, state version, and expiry. Reuse, expiry, and stale binding fail
  closed. Consuming an approval records only local approval state; it does not
  dispatch an action.
- Privacy audit events store risk, decision, payload digest, and byte count.
  SQLite and exported JSON omit every raw restricted fixture payload.
- The native Activity surface renders action cards read-only. It cannot approve
  or dispatch a proposal in this milestone.

## Commands and results

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh routing` | Passed 7 routing tests, including policy handoff |
| `/bin/zsh scripts/verify.sh privacy` | Passed 8 privacy tests and 3 audit tests |
| `/bin/zsh scripts/verify.sh all` | Passed 70 tests and a release build |
| `git diff --check` | Passed after this receipt/tracker update |

## Deliberate limitations and next gate

This milestone adds no network client, web client, cloud provider call, CAM
runtime call, account access, spend, file mutation, model execution, or action
dispatch. The deterministic patterns are a fail-closed baseline, not a claim
to infer every possible sensitive context. Future outbound clients must use
this policy and an exact approved card; CAM-009 will next add typed,
health-checked CAM/Codex adapter contracts without touching a live CAM corpus.
