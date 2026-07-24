# CAM Assistant Implementation

## Recommended Agent Workflow

- **Orchestrator:** Codex controls scope, decisions, sequencing, and evidence.
- **Implementer:** writes one bounded test-driven change.
- **Reviewer:** checks behavior, boundaries, security, licensing, and drift.
- **Tester:** runs the nearest focused test and aggregate verification.

Codex decides. Contributors advise. Tests arbitrate. Markdown remembers.

## Upfront Repository Reconnaissance

Before each integration:

1. confirm exact repo and path;
2. inspect truth files and Git status;
3. identify the runtime/data owner;
4. inspect licenses and verification commands;
5. record the narrow adapter or extraction boundary.

## Architecture Decisions Needed

Settled decisions live in `DECISIONS.md`. New decisions must identify:

- alternatives considered;
- data and runtime ownership;
- permission impact;
- migration and rollback;
- licensing/provenance;
- proof required.

## Implementation Phases

Follow
[`../docs/plans/2026-07-24-cam-personal-assistant.md`](../docs/plans/2026-07-24-cam-personal-assistant.md):

1. repository and native shell;
2. storage and audit;
3. modules and ingestion;
4. retrieval and model routing;
5. privacy and CAM integration;
6. research and operational modules;
7. UX, packaging, and aggregate proof.

## Atomic Task Format

Each task contains:

- behavior and acceptance criterion;
- files owned;
- failing test and expected failure;
- minimal implementation;
- focused and regression verification;
- documentation/progress update;
- one coherent commit.

## Risks and Mitigations

- **Scope sprawl:** keep optional specialists outside the core.
- **Cross-repo drift:** conformance-test contracts and live tool schemas.
- **Sensitive egress:** deterministic policy and zero-outbound restricted tests.
- **Index corruption:** fingerprinted generations and rollback.
- **GPL contamination:** concepts only unless the product license is explicit.
- **Approval fatigue:** safe local read-only defaults and concise action cards.
- **Model churn:** versioned role profiles and live fact-only catalog data.

## Open Decisions

- Final product license before any GPL code reuse.
- Distribution, signing, and notarization in a later approved goal.
- Direct MLX Swift integration versus local OpenAI-compatible service after
  baseline performance evidence exists.
