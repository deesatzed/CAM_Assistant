# Task 7 — Model Routing and Profile Ownership Receipt

**Date:** 2026-07-26
**Scope:** CAM-007 only; native local routing/profile foundation.
**Branch:** `feat/cam-assistant-foundation`
**Commit at verification:** `7f80d29` (working tree intentionally contains
uncommitted recovery and CAM-007 work)

## Verified behavior

- Terminal backtick markers preserve user text and cover local default, `CL`,
  `GR`, `OA`, `AR`, `WR`, `WRGR`, and `CAM`.
- A missing explicit role is a typed error; it never silently substitutes a
  different provider. `AR`, web, and CAM requests are typed deferred decisions,
  not transport calls.
- A selectable profile must contain a local role. Local JSON state is atomic,
  revisioned, restart-safe, rollback-capable, and has ordered change receipts
  for create, select, replace, and rollback.
- Model assignments reject credential-bearing local endpoint URLs. The native
  CLI and Settings view use the same local Application Support state location.
- The recorded catalog is a versioned fact-only fixture. It cannot select a
  profile. A requested live catalog, provider test, migration, or embedding
  operation returns a typed policy/proof-gate error before any transport exists.

## Commands and results

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh routing` | Passed 6 routing tests |
| `/bin/zsh scripts/verify.sh models` | Passed 13 profile/catalog/command tests |
| `/bin/zsh scripts/verify.sh all` | Passed 60 total tests and a release build |
| `git diff --check` | Passed after this receipt and tracker update |

## Deliberate limitations and next gate

This receipt does **not** prove a local model is installed or reachable, a
cloud provider works, an OpenRouter catalog was queried, embeddings are
selected, or a web/CAM request may run. The test catalog is synthetic and
offline. CAM-008 must first prove restricted-data classification, zero outbound
bytes for restricted fixtures, exact action cards, and scrubbed audit evidence.
Only then may an explicitly approved outbound client be considered.
