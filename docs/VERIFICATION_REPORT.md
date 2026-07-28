# GOAL_FINISH_WIKI Current Completion Audit

**Date:** 2026-07-28
**Status:** In progress — the tested foundation is real, but the full
GOAL_FINISH_WIKI outcome is not yet proven or complete.

## Current reproduced commands

| Command | Result |
|---|---|
| `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` | Repository portability gate plus 188 tests pass; native app and CLI release build pass |
| `/bin/zsh scripts/verify.sh generated` | Frozen generated-answer evaluator, structured local-model inference, explicit abstention, and conversation-boundary tests pass |
| `/bin/zsh scripts/verify.sh portability` | Required truth files are local; no external governing links or tracked generated artifacts; diff check passes |
| `/bin/zsh scripts/verify.sh fresh-clone` | Temporary non-local clone of ingest-lifecycle commit `7d8b820` passes portability, 188 tests, app/CLI release builds, package validation, and offline smoke from a clean source tree |
| `/bin/zsh scripts/verify.sh smoke` | Offline native smoke reports capture/local search available and cloud auto-routing disabled |
| `/bin/zsh scripts/verify.sh package` | Builds unsigned `artifacts/CAM Assistant.app`; `Info.plist` validates |
| Native accessibility inspection of `artifacts/CAM Assistant.app` | Real global open/capture hotkeys, watched-source lifecycle, persisted cancellation/restart/resume, and independent Activity Cancel/Resume accessibility controls pass against disposable roots |
| `git diff --check` | Passes after the latest documentation update |

## Requirement-by-requirement evidence

| GOAL_FINISH_WIKI proof area | Current evidence | Audit status |
|---|---|---|
| Native local foundation | Content-addressed storage, SQLite/audit, component backup tests, ingestion/restart tests, offline smoke; real packaged global open/capture hotkeys with collision handling; local Library detail/provenance/lifecycle/raw inspection; packaged watched-folder add/enable/pause/resume/remove with live Library refresh; and persisted native ingest Pending/Cancel/restart/Resume/Completed recovery with immutable-byte retention | Partial: full-vault backup/restore into a fresh application-support root, background ingestion policy, and secure deletion remain unproven |
| Sourced retrieval and chat | Frozen synthetic mixed-modality retrieval v2 report, plus separately frozen project-contract retrieval and generated-answer corpora; the generated evaluator measures retrieval, selected loopback-model generation, deterministic claim coverage, exact context citations, explicit abstention, and warm latency; local chat shows bounded cited extractive evidence, exact-match `Open in Library` navigation, one local-only low-confidence follow-up, explicit Keep/Discard, task promotion, and a native task workspace | Partial: retrieval passes the narrow approved corpora, but no tested Ollama/MLX model passes generated-answer v1; this is not broad personal-vault/repository quality or semantic-entailment proof |
| Privacy, routing, models | Marker/profile tests, deterministic privacy fixtures, zero-byte block and exact approval tests; typed selected-local-model health and generation against loopback-only OpenAI-compatible endpoints; no-auth requests, redirect refusal, exact response-model identity, JSON-Schema-constrained current-context passage IDs, explicit abstention, native health/route/model/endpoint display, ephemeral output, and visible no-fallback failure; live local receipts exist for Ollama `llama3.2:1b`, `ornith:9b`, and LM Studio MLX `vibethinker-3b-optiq-5bpw-mlx` | Partial: all live model receipts fail the frozen claim-support and/or latency gates, no packaged selected-profile GUI journey is proven, and live catalog, embedding promotion, and provider/web execution remain unproven |
| Repository and idea intelligence | Persisted user-selected repository paths with explicit later inspection, read-only temporary Git intake, restart-safe local snapshot receipts keyed by canonical path and commit, digest-aware committed-byte snapshots, local permitted-file indexing with repository provenance, incremental local reindexing of added/content-changed files, visible cancellation that prevents a new receipt while preserving immutable captured bytes, native commit-cited TODO/FIXME, Swift declaration, and literal import-dependency review rows, and a user-authored counterevidence/validation-experiment idea that must first create a proposal then can be explicitly kept or rejected as a cited local card, saved as a cited local-read task, explicitly promoted into a kept local research plan, or saved as a cited proposal-authority Codex-plan handoff | Partial: indexing lacks persisted jobs and a background scheduler; observations remain deterministic markers/declarations/import facts rather than semantic analysis; the Codex handoff does not invoke a live Codex coordinator; no exact-approved CAM mining execution proof exists |
| Research, Mac Care, modules | Citation-bound local facts/assumptions and unresolved contradiction candidates can be explicitly retained; native Library controls select two distinct claims, require a steelman, optionally retain a bridge, and keep both positions visible; research plans and citation-validated fact/inference packets have separate explicit local Keep stores and checkpoint resume; an explicit repository-idea promotion preserves source/commit/citation/confidence/counterevidence/validation provenance without repository bytes; user-triggered non-blocking read-only Mac assessment with free-space percentage plus bounded storage/startup/application inventory review findings; module tests | Partial: no web/document acquisition, outbound/cost receipts, native verified-packet authoring/review UI, app-usage/need assessment, or available Mac apply/undo executor |
| CAM/Codex coordination | Fixture-pinned CAM contract/schema, unavailable/incompatible handling, proposal-only adapter; one bounded local loop with macOS OS-file-lock ownership, native child-process contention proof, content-addressed evidence, versioned reducer transitions, atomic v1-to-v2 event/snapshot migration, digest-bound snapshots, restart replay, stale-version/sequence refusal, integrity checks, and JSON/Markdown handoff packets | Partial: no remote/multi-machine lease, tool/retry executor, graph dispatch, live pinned runtime/database/config verification, or CLI/UI controls |
| Usability, evidence, release | Native chat/capture surface, local task promotion, empty/offline/accessibility labels, real packaged hotkey and capture-source journeys, independent accessible ingest Cancel/Resume controls, package/smoke scripts, and exact-commit temporary fresh-clone proof with repository-local truth | Partial: no complete keyboard/focus/VoiceOver/reduced-motion matrix, selected-model packaged journey, full backup/recovery journey, signed/notarized distribution, or final release audit |

## Hard remaining gates

1. Complete the selected-local-model chat journey with a live packaged GUI
   proof and a local strategy that passes the frozen generated-answer gates.
   The evaluator and live loopback receipts now exist, but every tested
   Ollama/MLX model fails claim-support and/or latency requirements.
2. Implement and prove full-vault backup/restore into a fresh isolated
   application-support root, including bytes, metadata, preferences, tasks,
   retained research/knowledge, repository receipts, and audit state.
3. Add explicit, policy-gated web/provider execution adapters with real selected
   model/catalog/embedding receipts; retain zero-egress guarantees for protected
   data.
4. Add persisted repository-intelligence jobs, source removal lifecycle,
   semantic-but-evidence-evaluated observations, and a typed live Codex
   coordinator adapter; bind the synthetic mining lifecycle to a separately
   approved live pinned config/database integration with idempotency,
   cancellation, receipt, and recovery proof.
5. Add research source acquisition, retained-output policy, and outbound-cost
   receipts. Kept plans currently retain questions/checkpoints only.
6. Add exact-approved, verified, undo-capable Mac Care executors only for a
   closed safe action set.
7. Extend the local CAM/Codex bounded-loop foundation with snapshots/migrations,
   verifier postconditions, a closed safe tool/retry executor, and native
   controls before considering a graph or specialist agents. Remote or
   multi-machine coordination remains a separate future design.
8. Complete keyboard/focus/VoiceOver/reduced-motion verification and final
   release evidence after all above gates pass.

## Non-claims

This report does not claim that CAM mining, web research, cloud providers,
passing local-model synthesis, full-vault recovery, real personal-data
workflows, Mac maintenance execution, or a complete three-layer assistant are
implemented. No live CAM database/config, donor repository, cloud account, or
personal source was read or transmitted during this audit. One excluded
harmless marker was added to normal application-support state by an invalid
proof launch and remains local because deletion was not authorized.
