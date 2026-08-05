# CAM Assistant Reset Inventory

**Audited:** 2026-08-05
**Branch / commit:** `agent/add2cam-integration-20260731` / `3443650`
**Purpose:** identify what is worth preserving, what is genuinely distinctive,
what is unfinished, and what should leave the default product while CAM
Assistant is rebuilt one independently verified feature at a time.

## Bottom Line

CAM Assistant is not a failed codebase. It is a collection of many individually
tested systems presented as one product before a coherent daily-use path was
proven.

The safest reset is not a rewrite. Preserve the local vault, capture, retrieval,
backup, privacy, and audit substrate; replace the current twelve-destination
product surface with one small capture -> find -> answer -> keep loop. Move all
specialist features behind experimental boundaries until each earns its place
through an isolated packaged journey and real user utility.

## Current Evidence Snapshot

- `448` Swift tests pass on the current checkout.
- Release build, unsigned package reproducibility, package identity, and the
  bounded credential-signature scan pass.
- The controlling 48-gate map remains incomplete: `17 passed`, `28 partial`,
  and `3 missing`.
- The packaged app exposes twelve top-level destinations: Assistant, Meaning
  Preview, Library, Activity, Tasks, Modules, CAM, Research, Repositories, Mac
  Care, Approvals, and Settings.
- The main `AppModel.swift` is 4,005 lines and coordinates nearly every product
  concern.
- The repository contains 115 Swift source files, 42 Swift test files, 42 plan
  documents, and 68 evidence files.
- Eleven untracked top-level entries and an untracked nested `pendoleum/` Git
  repository are present. They were not modified or classified as product code.

Passing component tests prove useful parts exist. They do not prove that the
combined app is understandable or useful.

## Inventory Ranked by Present Utility

| Rank | Capability | Present utility | Current proof | Newness / distinctiveness | Reset disposition |
|---:|---|---|---|---|---|
| 1 | Immutable local vault, SQLite metadata, audit, backup/restore | Very high | Strong component and package proof; full-vault gate passed | Foundation, mostly conventional but well defended | **Keep as core** |
| 2 | Clipboard and watched-folder capture with restart/cancel/resume | Very high | Real packaged slices exist; overall lifecycle gate remains partial | Foundation; automatic consent-bound capture is a useful product choice | **Keep as Feature 1** |
| 3 | Library, source provenance, visibility lifecycle, raw inspection | Very high | Implemented and tested; complete daily-use proof remains partial | Added after foundation; provenance-first handling is differentiating | **Keep as Feature 1/2** |
| 4 | Deterministic local retrieval and exact citations | Very high | Frozen suites pass; broad personal-vault quality is unproven | Strong practical differentiator, not algorithmically novel | **Keep as Feature 2** |
| 5 | Full-vault validation and fresh-root recovery | High | One of the few fully passed product gates | Mature safety feature | **Keep, expose simply** |
| 6 | Selected loopback local-model answer with no silent fallback | High when a model is installed | Model selection/health gate passed; grounded presentation and live named-model performance remain partial | Useful local-first differentiator | **Keep as Feature 3** |
| 7 | Ephemeral answers with explicit Keep / task promotion | High | Core behavior exists; end-to-end promotion gate remains partial | Product-level distinction aligned with the original intent | **Keep as Feature 4** |
| 8 | Restricted-data egress block, typed approvals, redacted audit | High safety value | Zero-egress, routing, and audit gates passed; action approval remains partial | More rigorous than typical personal assistants | **Keep underneath the core** |
| 9 | Activity, retry, cancellation, and recovery states | Medium-high | Strong ingest/research-specific tests; no unified product journey | Good operational hygiene | **Keep but consolidate** |
| 10 | Tasks and local knowledge/contradiction records | Medium | Persistence and citation tests pass; weak primary-product justification | Conventional | **Keep hidden until core loop is proven** |

## Promising or Distinctive, but Not Yet Earned

| Capability | Potential utility | What is genuinely interesting | What is not proven | Disposition |
|---|---|---|---|---|
| Meaning Preview | Medium, possibly high for some users | Opt-in, isolated, reversible, one-card practical assistance with explicit feedback and no default authority | Human usefulness; `ADD2CAM-060` explicitly requires authentic pilot evidence | **Incubate as a separate experiment** |
| Repository evidence and semantic idea cards | Medium for developers | Commit-cited support and counterevidence, abstention, and non-mutating intake | No named model passes the frozen V3 contract; no convincing packaged daily journey | **Incubate outside the default app** |
| Policy-gated public-document acquisition | Medium | Exact URL, same-origin bounded fetch, zero-cost receipt, ephemeral review | Search, browser research, synthesis, and complete typed result authoring | **Optional Feature 6, after core** |
| Exact routing grammar and provider-visible failure | Medium | No silent provider substitution and explicit outbound choice | Whether suffix grammar is discoverable or desirable in normal use | **Preserve policy; redesign UX** |
| Bounded event/reducer coordination | Low direct user value today | Fail-closed terminal states, replay, leases, and content-addressed evidence | Any need for this complexity in the simplified product | **Keep as a library only if used** |
| Packaged native module trust lifecycle | Low direct value today | Enablement does not grant permission; lifecycle is explicit | Only shipped module counts words and characters; no compelling module utility | **Archive as infrastructure proof** |

## Newest Additions

| Added | Capability | Current reality | Reset disposition |
|---|---|---|---|
| 2026-08-03 | LM Studio/Ollama catalog selection and OpenRouter settings | Code and focused tests exist; today's app had no active local endpoint and OpenRouter was not configured | Keep local selection; remove OpenRouter from the first simplified release |
| 2026-07-30 to 2026-08-03 | Meaning Preview and packaged pilot | Packaged deterministic path is green; reflective lane has no admitted named model; human evidence is pending | Separate opt-in pilot, not primary navigation |
| 2026-07-29 to 2026-07-30 | Closed CAM runtime statistics and synthetic mining lifecycle | Can inspect/run bounded statistics on disposable copies; real mining is unavailable | Remove from ordinary app navigation |
| 2026-07-29 | Research acquisition | Exact-approved public document acquisition works; it is not general web research | Defer until capture/search/chat are useful |
| 2026-07-28 to 2026-07-29 | Repository jobs and semantic V3 | Extensive deterministic contracts; named-model proof remains red | Separate developer experiment |
| 2026-07-28 to 2026-08-03 | Mac Care planning/manual guidance | Read-only facts and copyable manual `mv` examples; app apply/undo is intentionally unavailable | Remove from the product for now |

## Low-Utility or Misleading Surfaces to Remove From the Default App

### CAM

The current CAM surface is specialized runtime pinning, disposable snapshot
verification, and one closed `stats --json` executor. It does not provide the
mining or general coordination implied by the name. Preserve the code and tests
as an integration lab; remove the workspace from normal navigation.

### Mac Care

The app can show selected read-only facts and manual shell guidance. It cannot
apply or undo a maintenance action. This is honest scaffolding, but not enough
utility to justify a first-class workspace.

### Modules

The packaged module lifecycle is a useful security proof. The only module's
"summary" is a word and character count. Calling this a user feature makes the
product feel unfinished. Retain it as a test fixture, not a destination.

### Repository Intelligence

The deterministic repository intake is credible, but the semantic layer has no
passing named model and the UI competes with the actual personal-memory goal.
Move it to a separate developer-mode tool or later companion.

### Meaning Preview

This is the most novel recent work, but it is not yet validated as useful by a
human pilot. Keep its isolation and opt-in boundary. Do not let its novelty make
it the center of the rebuilt app.

### OpenRouter

This is the newest provider surface and the least aligned with a simple,
local-first restart. The privacy boundary is thoughtful, but the feature adds
credentials, catalog loading, health, provider selection, and a second answer
button before the local daily-use loop is proven.

## Structural Causes of the Current Wonky Experience

1. **Feature count became the product architecture.** Twelve peer destinations
   expose internal subsystems instead of a small user journey.
2. **Evidence grew faster than usability.** The repo has more plans and evidence
   files than application views, while the overall gate map remains mostly
   partial.
3. **One state object owns nearly everything.** A 4,005-line `AppModel` binds
   unrelated lifecycles, increasing coupling and regression risk.
4. **Infrastructure proofs became visible features.** Module trust, CAM runtime
   containment, and orchestration are valuable engineering assets but poor
   default destinations.
5. **Truth surfaces are internally inconsistent.** The task tracker calls many
   areas complete while the controlling gate map calls their user outcomes
   partial or missing.
6. **The repository boundary is noisy.** Untracked Common Reality, Pendoleum,
   ReAgent, archive, and schema materials sit at the product root, including a
   nested Git repository.
7. **A passing synthetic suite is easy to overread.** Tests strongly validate
   contracts and failure boundaries, but several intelligent or external paths
   still lack a passing named model or real daily-use evidence.

## Recommended Simplified Product

The default app should initially have three places, not twelve:

1. **Home** — capture, ask, and see the current answer.
2. **Library** — sources, citations, visibility, and recovery.
3. **Settings** — local model, capture sources/hotkeys, and backup.

Activity should appear contextually as progress/errors, not as a separate
product. Keep and task actions should live beside the answer. Approvals should
appear only when an exact outbound action is pending. Every other subsystem
should be absent from default navigation.

## Feature-by-Feature Restart Sequence

No feature advances until its packaged journey is independently green and its
failure state is understandable without reading documentation.

| Sequence | Feature | Independent confirmation required |
|---:|---|---|
| 0 | Reset shell and boundaries | Fresh profile launches into three destinations; no specialist workspace is reachable by accident; untracked foreign materials are quarantined by an approved file task |
| 1 | Capture -> Library | Clipboard and one watched folder ingest automatically after explicit setup; source appears once; restart, failure, retry, cancel, and provenance are visible |
| 2 | Find -> cite | Exact search returns the expected local passage and opens its source; no model or network is required; representative personal fixtures pass |
| 3 | Ask local | User chooses one local model, sees health/model identity, receives a cited answer or clear abstention, and never gets silent cloud fallback |
| 4 | Keep or discard | Answer remains ephemeral until Keep; Keep creates or updates a cited memory/task; discard leaves no answer record |
| 5 | Backup and recover | One visible backup and fresh-root restore journey preserves the complete simplified state without overwriting live data |
| 6 | Optional outbound research | Only after an explicit need: one approval, one bounded public source, visible receipt, review, Keep/Discard |
| 7 | Experiments | Meaning Preview, repository intelligence, CAM, Mac Care, modules, and orchestration each require their own utility hypothesis and human validation before re-entry |

## Preserve, Park, and Quarantine

### Preserve now

- `Storage`, `Capture`, `Ingest`, `Retrieval`, `Conversation`, `Privacy`,
  `Authority`, `Audit`, and backup/recovery code.
- Library and capture UI patterns.
- Local model health and explicit no-fallback behavior.
- Existing tests for any preserved code, without weakening gates.

### Park behind build-time or developer-only boundaries

- `Meaning`, `Research`, `Repositories`, `CAM`, `MacCare`, `Modules`, and
  `Coordination`.
- OpenRouter and routing-marker UX.
- Advanced evaluation CLIs and experimental views.

### Quarantine after a separately approved file move

- Untracked ReAgent, Common Reality, Pendoleum, transfer-map, schema, ZIP, and
  `more2consider.md` material at the repository root.
- The untracked nested `pendoleum/.git` repository.

Nothing was deleted or moved during this inventory.

## Smallest Safe Next Step

Write a new reset goal that freezes the preserved core, defines the three-place
shell, and makes Feature 1 (Capture -> Library) the only implementation target.
Do not begin by deleting code. First hide specialist surfaces behind explicit
compile-time or developer-mode boundaries and prove the simplified packaged
journey against an isolated application-support root.
