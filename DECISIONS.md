# CAM Assistant Decisions

## Decision Log Overview

This file records product and architecture decisions that materially affect
scope, security, data ownership, licensing, or verification.

## Active Decisions

| Date | Decision | Status |
|---|---|---|
| 2026-07-24 | Build a new native SwiftUI product repo | Active |
| 2026-07-24 | CAM_Codx is the workflow hub; CAM_CAM remains runtime owner | Active |
| 2026-07-24 | The wiki is a core module, not the entire product | Active |
| 2026-07-24 | Local inference and deterministic retrieval are defaults | Active |
| 2026-07-24 | Use manifests/adapters instead of merging donor repos | Active |
| 2026-07-24 | Treat GPL repos as concept donors until licensing is explicit | Active |
| 2026-07-24 | Begin on a feature branch because no prior repo/worktree exists | Active |
| 2026-07-24 | Discovery and enablement do not grant module permissions | Active |
| 2026-07-25 | Retrieval generations use typed fingerprints and isolated atomic promotion | Active |
| 2026-07-25 | Retrieval citation metric is exact quote availability, not semantic entailment | Active |
| 2026-07-26 | Model routing defaults local; profiles are atomic, receipted, and user-selected | Active |
| 2026-07-26 | Outbound/mutating intent is policy-classified and exact-approval-bound before execution | Active |
| 2026-07-26 | CAM integration begins with fixture-pinned, non-executing conformance; live runtime/mining stays disabled | Active |
| 2026-07-26 | Research begins as local, ephemeral, citation-bound packets; web and automatic retention remain separately gated | Active |
| 2026-07-26 | Repository intake and Mac Care are read-only by default; idea and maintenance plans are proposals, not executors | Active |
| 2026-07-26 | Repository intake receipts are local derived records keyed by canonical path and commit; they never write to the inspected repository | Active |
| 2026-07-26 | CAM mining plans are digest-only, bounded, exact-approval-bound, and fail closed when no pinned live executor is attached | Active |
| 2026-07-26 | Coordination transitions are reducer-derived from versioned local events; stale sequence/version writes fail before terminal success can be asserted | Active |
| 2026-07-26 | Selected repository indexing captures only permitted files into the local vault with canonical path and commit provenance; it never writes to the repository or invokes CAM | Active |
| 2026-07-26 | Repository comparison reports only deterministic snapshot differences; it does not infer semantic behavior from file changes | Active |
| 2026-07-26 | Repository marker observations are read from the recorded Git commit, cite file and line, and remain review evidence rather than semantic claims | Active |
| 2026-07-26 | The first CAM/Codex coordinator is one bounded local event loop with content-addressed evidence and replay-based recovery; it cannot execute tools, models, CAM, or specialist agents | Active |
| 2026-07-26 | Every bounded coordination loop holds an exclusive macOS local-process ownership lease; a native child-process probe proves a competing process cannot acquire the same run until release | Active |
| 2026-07-26 | Orchestration snapshots are versioned, atomic local caches derived from and revalidated against the complete event log; they do not compact or replace event authority | Active |
| 2026-07-26 | Orchestration event logs and snapshots migrate atomically from schema v1 to v2 while preserving events and reducer-derived state | Active |
| 2026-07-26 | Repository symbol observations are deterministic declarations from committed Swift source, cited by commit/file/line and never elevated into behavior or architecture claims | Active |
| 2026-07-26 | Repository refresh records the current selected-repository snapshot locally and compares it only with the prior local receipt; it never writes the repository or invokes CAM | Active |
| 2026-07-26 | Incremental repository indexing derives receipt digests and captures only added or content-changed permitted files from the recorded Git commit; a receipt is saved only after local extraction succeeds | Active |
| 2026-07-26 | Watched sources are explicit, locally persisted multi-folder records. A picked folder begins paused; only an explicit enablement starts its foreground local watcher, and pause/remove never delete retained vault content | Active |
| 2026-07-26 | Repository idea drafting exposes only deterministic committed observations; the user must supply counterevidence and a smallest validation experiment. A displayed proposal can be explicitly kept or rejected as a cited local card, or saved as a cited `localRead` task; research-packet and Codex-plan promotion remain unavailable | Active |
| 2026-07-26 | Saved repository sources are canonical local path selections only. Selecting or retaining a path grants no repository read, indexing, scheduling, CAM, or mining authority; each later inspection remains explicit | Active |
| 2026-07-26 | Retrieval v2 remains frozen synthetic mixed-modality regression evidence. A separate frozen project-contract corpus may use only user-approved local contract excerpts with path/digest provenance; it does not substantiate personal-vault, donor-repository, semantic-entailment, or model-faithfulness claims | Active |
| 2026-07-26 | Default local chat is bounded extractive evidence: at most three displayed local excerpts and their exact matching citations. It is not a hidden model invocation or generated synthesis | Active |
| 2026-07-26 | Mac Care may surface read-only low-space and application/startup inventory review findings. It does not infer application necessity from counts, recommend removal, or enable maintenance execution | Active |
| 2026-07-26 | Research plans are persisted only after the user explicitly selects Keep. A repository-idea promotion additionally preserves commit-cited provenance, confidence, counterevidence, and validation criteria, but never source bytes. Findings, web output, model output, and automatic retention remain unavailable | Active |
| 2026-07-26 | A repository idea may be explicitly saved as a local Codex-plan handoff with proposal authority and cited evidence. This preserves planning context only; it does not invoke Codex/CAM, gain repository access, or execute a plan | Active |
| 2026-07-26 | A low-confidence local chat result exposes exactly one local capture/index follow-up. It never offers automatic retry, provider, web, CAM, or other escalation | Active |
| 2026-07-26 | Repository dependency observations are limited to literal Swift `import` declarations read from a clean commit. They are cited structural facts, not semantic architecture or behavior claims | Active |
| 2026-07-26 | Citation-bound knowledge claims and unresolved contradiction candidates persist only after explicit Keep. Facts, assumptions, and both contradiction positions remain distinct; no automatic truth promotion or resolution occurs | Active |
| 2026-07-26 | Verified research packets may be retained only through an explicit local Keep store after citation validation. The store contains typed facts/inferences, never raw source bytes, automatic output, or acquisition authority | Active |
| 2026-07-26 | Repository indexing supports explicit cancellation through UI-to-operation checkpoints. Cancellation prevents a new snapshot receipt but preserves immutable already-captured vault content for safe recovery | Active |
| 2026-07-26 | `GOAL_FINISH_WIKI.md` is the self-contained controlling completion contract for the canonical `cam_wiki` repository. It preserves the approved three-layer product, makes the verified foundation explicit, and defines the remaining native wiki, local model, research, repository mining, CAM/Codex, Mac Care, module, usability, and release proof gates | Active |
| 2026-07-26 | The confirmed recovered working tree is published as the canonical repository baseline on `main`. External parent-workspace goal files remain historical design inputs rather than required files for a fresh clone | Active |
| 2026-07-26 | Aggregate verification begins with repository-local truth and tracked-artifact checks, then runs a non-recursive temporary local clone of the committed revision for tests, release build, package validation, and offline smoke. `CAM_ASSISTANT_SKIP_FRESH_CLONE=1` is an internal recursion guard used only inside that clone | Active |
| 2026-07-27 | Library source detail is a read-only projection of derived text plus every stored capture provenance record. Citation navigation requires an exact local source and passage match, reveals no immutable raw source bytes, and grants no retention or mutation authority | Active |
| 2026-07-27 | Selected local-model chat uses an explicitly configured OpenAI-compatible loopback endpoint only. A separate health check must find the selected model; requests carry no authorization header, redirects are rejected, response model identity must match, and generated answers may cite only exact passage IDs from the current local retrieval context. Failure never falls back to cloud, web, CAM, or another model, and output remains ephemeral until explicit promotion | Active |
| 2026-07-27 | Generated-answer evaluation uses a separately frozen approved product-contract corpus and measures retrieval, context assembly, selected loopback-model generation, exact context-citation validation, deterministic claim coverage, explicit abstention, and warm latency as one operation. Structured generation constrains citations to current passage IDs; empty answer plus empty citations is the only abstention. Failed and invalid-environment runs remain separate receipts and cannot satisfy CAM-013 | Active |
| 2026-07-27 | Local source lifecycle is reversible visibility metadata, not deletion. Hiding a source excludes its derived document from active Library rows, citation navigation, and local chat context while preserving content-addressed bytes, capture provenance, derived history, and retained citations. Hidden sources remain reviewable and can be explicitly restored after restart | Active |
| 2026-07-27 | Immutable source inspection is explicit, local, integrity-checked, and bounded. Object IDs must be lowercase SHA-256 identities, stored bytes are re-hashed before display, text previews are capped, and binary or invalid UTF-8 content exposes metadata only. Inspection grants no edit, export, deletion, retention, or lifecycle authority | Active |
| 2026-07-27 | Packaged global shortcuts use explicit Carbon virtual key constants rather than arithmetic key-code assumptions. The default open shortcut is Command-Option-K because macOS Finder owns Command-Option-Space; capture remains Command-Option-C. Packaged verification may redirect all CAM application-support state only through the explicit absolute-path `CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT` override, while normal launches retain the standard macOS location | Active |
| 2026-07-28 | A successful watched-folder capture must publish a local status and refresh the native Library on the main actor. Pause stops event handling; Resume may capture files that appeared while paused when a later filesystem event causes a bounded rescan; Remove stops watching and removes only source configuration, never retained immutable vault content | Active |
| 2026-07-28 | Native ingest cancellation is a persisted job-state transition, not source deletion. Only Pending may become Cancelled; only Cancelled/Failed may resume; exact resume processes the selected job and preserves immutable bytes. Normal capture remains automatic, while the explicit deferral environment is limited to disposable packaged verification. Activity must expose Cancel/Resume as independent accessibility actions | Active |
| 2026-07-28 | Database-backed local chat must rebuild and open the persistent retrieval generation, then rank through `HybridRetriever`; it may not use a separate all-question-token substring filter. Retrieved chunks map to the existing canonical `source#0` derived-document citation so exact Library navigation and current retention boundaries remain stable | Active |
| 2026-07-28 | A workspace summary accessibility label must preserve descendant controls and state descriptions with contained-child semantics. Summary labels may add context but cannot replace empty, error, recovery, or action elements in the native accessibility tree | Active |
| 2026-07-28 | Every explicit repository-index operation is a durable status-only local job with bounded attempts. An OS `flock` lease prevents another live app process from recovering its running job; an atomic cancellation/terminal-commit token refuses late cancellation instead of misreporting a committed snapshot. Unleased interrupted jobs may resume under the same identity, completion links the exact snapshot receipt, and errors never persist source text or exception details. SQLite lifecycle state is authoritative and repairs stale JSON selection state after restart; removing a saved source never deletes vault bytes, provenance, derived history, snapshots, jobs, or ideas | Active |
| 2026-07-28 | Aggregate release verification scans the unsigned package and saved evidence for bounded credential/private-key signatures, emits only status/counts in an atomic JSON receipt, and fails without exposing matched bytes. This is a credential-signature gate, not a claim that arbitrary sensitive content is mechanically detectable | Active |
| 2026-07-28 | Every unsigned app package embeds the exact Git commit, deterministic commit-count build number, and source dirty state in `Info.plist`; aggregate release verification rejects an identity mismatch. Wall-clock timestamps and branch names are excluded from package identity because they are not reproducible source identities | Active |
| 2026-07-28 | The machine-readable finish-goal map keys every Proof-of-Done bullet to its exact source line, current verdict, evidence, and limitation under a pinned goal digest. Aggregate validation passes when the map is complete and honest even if its overall product verdict is `incomplete`; only an all-`passed` map may support final completion | Active |
| 2026-07-28 | Unsigned package reproducibility compares two same-source builds through a canonical sorted manifest of every bundle entry type, permission mode, and content digest. Filesystem timestamps are intentionally excluded; exact package commit/build/dirty identity is verified separately after each build | Active |
| 2026-07-28 | Module capabilities are advertised only when the module is enabled, healthy, and has every permission declared by its manifest. Discovery, enablement, and partial grants provide no capability authority; disable clears grants | Active |
| 2026-07-28 | Repository semantic evidence uses the approved evidence-first hybrid: deterministic clean-commit observations remain authoritative; an explicitly selected loopback local model may propose candidates only when deterministic citation and abstention validation can fail closed | Active |
| 2026-07-28 | Codex verification is batched through the repository-owned `scripts/verify.sh` entry point with SwiftPM's nested sandbox disabled. Repeated raw Swift command variants are not part of the normal workflow | Active |

## Initial Default Decisions

- Swift 6, SwiftUI, Swift Package Manager, native macOS services, and SQLite3.
- Human-readable Markdown plus local SQLite metadata and replaceable indexes.
- One base config plus versioned model profiles.
- Synthetic fixtures for privacy and evaluation.
- Automations and optional modules disabled initially.
- Only the native Memory module is core-enabled. Every other initial module is
  discovered but disabled until the user enables it, and permission grants are
  persisted separately from enablement.
- A retrieval index fingerprint includes source-manifest hash, schema,
  tokenizer/preprocessing, chunking, semantic provider/model/dimension, and
  fusion version. A new build writes an isolated generation and atomically
  promotes it only after its SQLite index is complete.
- Retrieval reports may claim only exact quote availability in the retrieved
  context. They do not prove arbitrary generated claims are semantically
  entailed; that requires a separate evaluation contract.
- A usable model profile always includes a local assignment. `CL`, `GR`, and
  `OA` are explicit named roles; `AR`, `WR`, `WRGR`, and `CAM` are parsed but
  deferred until their privacy/adapter gates pass. Profile revisions and their
  change receipts share one atomic local registry document; endpoint credential
  query data is rejected.
- CAM-008 uses deterministic, fail-closed synthetic-fixture rules as the
  baseline privacy boundary. Restricted/proprietary/contextual outbound intent
  does not produce a payload; exact approval can only consume its own local
  binding and cannot itself execute an action or network request.

## Superseded Decisions

- The earlier product framing as only a personal wiki is superseded by CAM
  Assistant; the wiki design remains applicable to the Memory/Wiki module.

## Decision Rules for Future Agents

- Prefer the smallest reversible option that preserves the full goal.
- Never move personal data ownership into CAM or a cloud provider.
- Never silently change model/provider or permission class.
- Require measured evidence before architecture optimization.
- Record a decision before copying donor code.

## Pending Decision Questions

- Product license.
- Signing/notarization/distribution strategy.
- Whether a later direct MLX Swift path outperforms the local service adapter.
