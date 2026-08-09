# CAM Assistant Barebones Goal

## Product Promise

Build a private memory inbox for one person:

> Capture something once, find it later, ask questions grounded in it, and
> deliberately keep only what remains useful.

The default experience is designed for a general iPhone user. It reduces
organization work and technical mental overhead. Normal use must not require
the user to understand indexes, embeddings, routes, models, endpoints,
manifests, hashes, or permission classes.

## Default Product

The ordinary app has exactly three destinations:

1. **Home** — save, find, ask, and Keep or discard.
2. **Library** — browse recognizable sources, search, inspect citations, hide,
   and restore.
3. **Settings** — configure Capture, Local AI, Backup & Restore, and optional
   Advanced details.

Home uses one obvious Ask action. Details use progressive disclosure. Capture,
Library, exact search, citations, backup, and recovery remain useful with no model
and no network.

### Phase 2 note (does not change barebones gates)

After Gates 1–6 machine evidence, Pattern A **Direction** (people, promises,
north star, optional Talk) may appear as a **thin strip on Home** only, under
[`GOAL_DIRECTION.md`](GOAL_DIRECTION.md). Direction is not a fourth primary
destination and must not regress these barebones gates. Phase 2 code starts
only after human approval of the Direction implementation plan.

## Authority and Data Boundaries

- Captured source bytes and provenance remain local and authoritative.
- Derived indexes are replaceable.
- Answers remain ephemeral until Keep.
- No cloud, web, CAM, or alternate provider is selected silently.
- Restricted data produces zero outbound payload bytes.
- Hidden specialist workspaces gain no new authority.
- Existing specialist code and records are preserved during the reset.

## Proof Gates

Each gate is independently verified. Work does not advance because a later
component already exists.

## Gate 1: Shell gate

A fresh production profile exposes only Home, Library, and Settings. Primary
copy is plain language, accessible, and contains no implementation jargon.

## Gate 2: Capture gate

Clipboard and one explicitly selected watched folder save automatically and
idempotently, show friendly success/failure/retry states, survive restart, and
preserve understandable provenance without network access.

## Gate 3: Find gate

Representative personal fixtures retrieve exact passages without a model.
Results use recognizable source names and open the cited Library item. Missing
support is reported honestly.

## Gate 4: Ask gate

One selected, health-checked local model may produce a citation-validated
answer. If Local AI is unavailable, the same Ask action visibly returns local
matching passages. It never falls back to cloud, web, CAM, or another provider.

## Gate 5: Keep gate

Keep creates or updates one concise cited memory rather than saving a chat
transcript. Discard leaves no durable answer. Duplicate/update choice, restart,
and exact Undo are proven.

## Gate 6: Recover gate

A validated backup restores the complete simplified state into a fresh root
without overwriting live data. Restored watched folders remain paused.

## Gate 7: Human gate

A general non-developer completes capture, find, supported and unsupported Ask,
citation inspection, Keep, Undo, backup, and recovery without assistance. They
can explain where their content lives and whether anything went online.
Synthetic, source-contract, and agent evidence cannot satisfy this gate.

## Parked Specialist Scope

Research, Repositories, CAM, Mac Care, Modules, Meaning Preview, orchestration,
OpenRouter, cloud routing, and specialist approvals are absent from default
navigation. They may be tested through an explicit developer experience, but
cannot re-enter the ordinary product without a separate utility hypothesis,
packaged proof, and human approval.

## Stop Rules

Stop the active feature when:

- its focused or packaged gate is red;
- a primary screen exposes technical identities instead of recognizable names;
- normal use requires Terminal, endpoint knowledge, or architectural concepts;
- a no-model or no-network journey stops working;
- existing privacy, storage, audit, or recovery tests regress;
- fixing the feature would require exposing a parked specialist workspace;
- user content, credentials, or live external state would be placed at risk;
- a destructive action, production deployment, legal decision, or missing
  credential requires the user.

## Completion

The barebones reset is complete only when Gates 1-6 have current repository-
owned packaged evidence and Gate 7 has authentic human evidence **or an
explicit human waiver recorded in the repository**. Passing component tests
alone is not completion of Gate 7 without waiver.

**Waiver (2026-08-09):** Gate 7 waived by product owner — see
`docs/evidence/HUMAN_GATE_WAIVER_2026-08-09.md`.
