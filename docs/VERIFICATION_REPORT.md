# GOAL_FINISH_WIKI Baseline Completion Audit

**Date:** 2026-07-26
**Status:** In progress — the tested foundation is real, but the full
GOAL_FINISH_WIKI outcome is not yet proven or complete.

## Current reproduced commands

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh all` | Repository portability gate plus 172 tests pass; native app and CLI release build pass; clean committed runs also execute the fresh-clone gate |
| `/bin/zsh scripts/verify.sh portability` | Required truth files are local; no external governing links or tracked generated artifacts; diff check passes |
| `/bin/zsh scripts/verify.sh fresh-clone` | Temporary local clone of raw-inspection commit `3ed92c5` passes portability, 172 tests, release build, package, and offline smoke |
| `/bin/zsh scripts/verify.sh smoke` | Offline native smoke reports capture/local search available and cloud auto-routing disabled |
| `/bin/zsh scripts/verify.sh package` | Builds unsigned `artifacts/CAM Assistant.app`; `Info.plist` validates |
| Native accessibility inspection of `artifacts/CAM Assistant.app` | Launches the packaged app and exposes local chat/capture controls plus `Global hotkeys active` |
| `git diff --check` | Passes after the latest documentation update |

## Requirement-by-requirement evidence

| GOAL_FINISH_WIKI proof area | Current evidence | Audit status |
|---|---|---|
| Native local foundation | Content-addressed storage, SQLite/audit, backup/restore, ingestion/restart tests, offline smoke; Carbon hotkey manager, collision-safe persisted shortcut configuration, local Library source list/detail with citation passage identity and every capture provenance record, reversible Active/Hidden source lifecycle that preserves immutable bytes/provenance while excluding hidden sources from citation navigation and local chat, explicit integrity-checked bounded source inspection with metadata-only binary handling, and explicit persisted multi-folder watched-source controls with isolated failure state | Partial: hotkey dispatch still needs an end-to-end operating-system key-event proof; watched sources still need live packaged-UI and background-lifecycle proof |
| Sourced retrieval and chat | Frozen synthetic mixed-modality retrieval v2 report, plus a separately frozen five-source approved project-contract corpus with path/digest provenance, cited-claim labels, and a saved 1.0 Recall@10/MRR/quote-support report; local chat shows at most three cited extractive excerpts, exact-match `Open in Library` navigation, one local-only low-confidence capture/index follow-up, explicit Keep/Discard and persisted task promotion, and a native task workspace with explicit status-only completion | Partial: the approved corpus is narrow product-contract evidence, not broad personal-vault/repository quality; extractive output is not a generated-answer faithfulness evaluation or a selected local-model answer |
| Privacy, routing, models | Marker/profile tests, deterministic privacy fixtures, zero-byte block and exact approval tests; typed selected-local-model health and generation against loopback-only OpenAI-compatible endpoints; no-auth requests, redirect refusal, exact response-model identity, exact current-context passage citations, explicit native health/route/model/endpoint display, ephemeral output, and visible no-fallback failure | Partial: no active local profile/service was available for a live selected-model smoke or frozen generated-claim faithfulness/latency evaluation; live catalog, embedding promotion, and provider/web execution also remain unproven |
| Repository and idea intelligence | Persisted user-selected repository paths with explicit later inspection, read-only temporary Git intake, restart-safe local snapshot receipts keyed by canonical path and commit, digest-aware committed-byte snapshots, local permitted-file indexing with repository provenance, incremental local reindexing of added/content-changed files, visible cancellation that prevents a new receipt while preserving immutable captured bytes, native commit-cited TODO/FIXME, Swift declaration, and literal import-dependency review rows, and a user-authored counterevidence/validation-experiment idea that must first create a proposal then can be explicitly kept or rejected as a cited local card, saved as a cited local-read task, explicitly promoted into a kept local research plan, or saved as a cited proposal-authority Codex-plan handoff | Partial: indexing lacks persisted jobs and a background scheduler; observations remain deterministic markers/declarations/import facts rather than semantic analysis; the Codex handoff does not invoke a live Codex coordinator; no exact-approved CAM mining execution proof exists |
| Research, Mac Care, modules | Citation-bound local facts/assumptions and unresolved contradiction candidates can be explicitly retained; native Library controls select two distinct claims, require a steelman, optionally retain a bridge, and keep both positions visible; research plans and citation-validated fact/inference packets have separate explicit local Keep stores and checkpoint resume; an explicit repository-idea promotion preserves source/commit/citation/confidence/counterevidence/validation provenance without repository bytes; user-triggered non-blocking read-only Mac assessment with free-space percentage plus bounded storage/startup/application inventory review findings; module tests | Partial: no web/document acquisition, outbound/cost receipts, native verified-packet authoring/review UI, app-usage/need assessment, or available Mac apply/undo executor |
| CAM/Codex coordination | Fixture-pinned CAM contract/schema, unavailable/incompatible handling, proposal-only adapter; one bounded local loop with macOS OS-file-lock ownership, native child-process contention proof, content-addressed evidence, versioned reducer transitions, atomic v1-to-v2 event/snapshot migration, digest-bound snapshots, restart replay, stale-version/sequence refusal, integrity checks, and JSON/Markdown handoff packets | Partial: no remote/multi-machine lease, tool/retry executor, graph dispatch, live pinned runtime/database/config verification, or CLI/UI controls |
| Usability, evidence, release | Native chat/capture surface, local task promotion, empty/offline/accessibility labels, Carbon registration status in the running packaged app, local package/smoke scripts, and exact-commit temporary fresh-clone proof with repository-local truth | Partial: no end-to-end global-hotkey action proof, reduced-motion/UI automation proof, signed/notarized distribution, or full user journey verification |

## Hard remaining gates

1. Complete the selected-local-model chat journey with a live packaged GUI
   proof and a frozen generated-claim citation-support/latency evaluation.
   Typed route/model/endpoint identity and fail-closed citation binding are
   implemented, but no compatible local service was active for live proof.
2. Prove user-configurable, collision-aware **global** macOS hotkey registration
   and its capture action in a live GUI session; run a live packaged-UI proof
   for watched-source picker/enable/pause/remove and decide whether background
   lifecycle is required for the initial release.
3. Add explicit, policy-gated web/provider execution adapters with real selected
   model/catalog/embedding receipts; retain zero-egress guarantees for protected
   data.
4. Add cancellation/persisted jobs, source removal lifecycle, semantic-but-evidence-evaluated observations, and
   a typed live Codex coordinator adapter; bind the synthetic mining
   lifecycle to a separately approved live pinned config/database integration
   with idempotency, cancellation, receipt, and recovery proof.
5. Add research source acquisition, retained-output policy, and outbound-cost
   receipts. Kept plans currently retain questions/checkpoints only.
6. Add exact-approved, verified, undo-capable Mac Care executors only for a
   closed safe action set.
7. Extend the local CAM/Codex bounded-loop foundation with snapshots/migrations,
   verifier postconditions, a closed safe tool/retry executor, and native
   controls before considering a graph or specialist agents. Remote or
   multi-machine coordination remains a separate future design.
8. Complete accessibility/reduced-motion verification, packaging/launch checks,
   an aggregate verifier, and final release evidence after all above gates pass.

## Non-claims

This report does not claim that CAM mining, web research, cloud providers,
global hotkeys, real personal data workflows, Mac maintenance execution, or a
complete three-layer assistant are implemented. No live CAM database/config,
donor repository, cloud account, or Mac state was modified during this audit.
