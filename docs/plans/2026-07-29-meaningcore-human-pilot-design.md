# MeaningCore Human Pilot Design

## Status

Approved for planning on 2026-07-29. This document defines a non-destructive,
opt-in human pilot. It does not authorize implementation, default-product
integration, migration of existing CAM data, notifications, or autonomous
actions.

Planning baselines:

- CAM Assistant: `agent/portable-canonical-repo` at
  `287a1fd0db57e201a3bb5d42c42bb936ce9d5222`
- MeaningCore: `main` at
  `23db68044ebdc410edf3b7f436e433ffba6e94b8`
- MeaningCore upstream:
  `https://github.com/deesatzed/meaningcore.git`

The CAM checkout continued to receive unrelated work while this design was
prepared. Implementation must refresh both identities before changing code.

## Product Decision

MeaningCore will first appear as an explicitly enabled **Meaning Preview**
inside CAM Assistant. It will not shape default chat, search, tasks,
notifications, capture, or routing. Humans will use the preview deliberately,
and promotion into normal CAM behavior will require a separate evidence-backed
decision.

MeaningCore remains a deterministic domain library. CAM remains the owner of:

- source capture and the immutable vault;
- SQLite lifecycle, retention, backup, and recovery;
- retrieval and context assembly;
- model and provider routing;
- permissions, privacy classification, and transmission;
- audit, action approval, and execution;
- native UI, accessibility, and application lifecycle.

## Architecture

CAM will pin MeaningCore as a Swift package dependency. A CAM-owned adapter
layer will translate between existing CAM types and MeaningCore without
copying MeaningCore policies into CAM.

The pilot consists of:

1. `CAMMeaningContextAdapter`: converts only explicitly selected, permitted
   CAM-derived context into typed MeaningCore context and memory.
2. `MeaningPreviewCoordinator`: an actor that serializes pilot state changes
   and invokes deterministic MeaningCore policies.
3. `MeaningPreviewStore`: a CAM-owned, versioned SQLite store in a separate
   application-support namespace. MeaningCore's JSON reference store is not
   production storage.
4. `MeaningPreviewAuditSink`: records bounded pilot decisions and failures
   without raw sensitive content.
5. `MeaningPreviewWorkspace`: an opt-in native SwiftUI surface for one
   practical memory or one proportionate possibility, plus Inspect.
6. `MeaningActionProposalAdapter`: converts any future external or mutating
   request into an ordinary CAM proposal or ActionCard. The pilot never
   executes it.

Meaning Preview may be represented by CAM's native module registry for
discovery and enablement, but enablement grants no data, model, network,
notification, or mutation permission.

## Data Flow

```text
Explicit user selection
        |
        v
CAM permission and active-source checks
        |
        v
Read-only typed context projection
        |
        v
MeaningPreviewCoordinator
        |
        +--> isolated MeaningPreviewStore
        |
        v
Ambient / Glance / Inspect projection
        |
        v
Meaning Preview workspace
        |
        v
Now / Later / Release / Helpful / Not helpful
        |
        v
local pilot receipt and isolated state only
```

No raw immutable source bytes are copied into pilot state. Generated
possibilities remain ephemeral unless the user explicitly keeps them. `Now`,
`Later`, `Release`, and selection do not count as helpful-outcome evidence.

## Human Experience

The pilot is user-pull only:

- no onboarding questionnaire;
- no scheduled daily ritual;
- no notification or background nudge;
- no default-chat injection;
- no meaning, contentment, stress, usefulness, or human-performance score;
- no streak, badge, leaderboard, or unfinished-work dashboard;
- normally zero or one opening;
- visible Preview labeling and a direct disable control;
- concise Inspect evidence, uncertainty, provenance, and why-surfaced text;
- ordinary CAM remains available and unchanged when the preview is disabled.

The first human slice is deliberately narrow:

1. select approved local context;
2. request a Meaning Preview;
3. receive silence, one practical memory, or one proportionate possibility;
4. inspect why it appeared;
5. choose `Now`, `Later`, `Release`, `Helpful`, or `Not helpful`;
6. return to ordinary CAM without a follow-up obligation.

## Failure And Recovery

- Disabled or unavailable Meaning Preview produces no default-product change.
- Missing, stale, restricted, secret-like, or invalid context is excluded
  before MeaningCore invocation.
- Store corruption fails closed, preserves the CAM vault, and offers bounded
  archive/reinitialize recovery for pilot state only.
- Unsupported MeaningCore or adapter versions fail compatibility checks before
  state loading.
- MeaningCore host escalation remains a typed CAM-owned boundary; it does not
  become diagnosis, treatment, reassurance, or an emergency service.
- A failed or rejected suggestion does not retry automatically, increase
  intrusiveness, invoke a model, or escalate to CAM, cloud, or web.
- Disabling the preview stops its behavior but does not delete CAM data or
  silently delete pilot evidence.

## Verification

Implementation requires focused proof for:

- exact MeaningCore revision and license/provenance;
- adapter type mappings and unsupported-case refusal;
- no default CAM behavior when disabled;
- separate persistence, migration, restart, backup boundary, and rollback;
- zero mutation of existing CAM memory and source records;
- explicit context selection and permission enforcement;
- no raw-secret or restricted-data leakage;
- one-item/silence behavior and Inspect provenance;
- `Now` not becoming helpful-outcome evidence;
- user-pull-only behavior with no notification path;
- keyboard, VoiceOver, reduced-motion, empty, loading, error, and disable
  states;
- packaged offline operation after dependencies are resolved;
- aggregate CAM and MeaningCore verification;
- an isolated packaged human-pilot journey.

## Human Pilot Evidence

Pilot evaluation measures the system, never human worth or meaning:

- whether the first use is understandable without instruction;
- useful-surfacing and correct-silence judgments;
- nuisance, pressure, confusion, and correction burden;
- evidence/Inspect comprehension;
- ease of disabling and returning to ordinary CAM;
- whether suggestions feel upbeat, adult, confident without false certainty,
  and meaningfully different from self-help/task apps;
- qualitative reports of participation, enoughness, usefulness, and
  contentment without converting them into a person score.

All pilot receipts remain local and user-owned. No engagement optimization or
automatic telemetry is introduced.

## Promotion Boundary

No capability becomes ingrained in CAM merely because the pilot compiles,
tests pass, or some users like it. Each proposed promotion must name:

- the human evidence supporting it;
- the CAM surface it would affect;
- new permissions or data uses;
- rollback behavior;
- failure and pressure risks;
- accessibility and privacy proof;
- a separate explicit approval.

Possible later promotions include default practical utility, optional
conversation context, earned Living Language, or carefully bounded meaning
windows. Notifications, automatic reflective inference, and broader ambient
influence remain separate higher-risk decisions.

