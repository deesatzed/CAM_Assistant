# GOAL_ADD2CAM: Isolated MeaningCore Human Pilot

**Status:** Approved product boundary and implementation contract.
**Implementation state:** In progress. Tasks 1-5 and deterministic practical Gate 5 are implemented; native UX, feedback/audit, frozen reflective evaluation, packaged proof, and human evidence remain.
**Date:** 2026-07-29.

## Purpose

Add MeaningCore to CAM Assistant through a non-destructive, explicitly enabled
human pilot. The pilot must let people experience practical utility and,
only after a separate model-quality gate, one bounded reflective opening.

The pilot exists to answer a real product question:

> Can CAM help a person encounter useful, proportionate participation,
> enoughness, connection, creation, appreciation, service, repair, or release
> without becoming another self-help app, score, ritual, or task backlog?

Passing software tests proves only that the pilot is safe and coherent enough
to try. It does not prove that MeaningCore solves the human need, that
inference is SOTA, or that any capability should become part of default CAM.

## Authority And Relationship To Existing Goals

Authority order:

1. `GOAL_FINISH_WIKI.md` remains CAM Assistant's controlling product and
   completion contract.
2. `GOAL_ADD2CAM.md` controls only the MeaningCore pilot.
3. `GOAL.md`, `STANDARDS.md`, `IMPLEMENT.md`, `DECISIONS.md`,
   `PROGRESS.md`, and `TASK_QUEUE.md` remain repository truth.
4. `docs/plans/2026-07-29-meaningcore-human-pilot-design.md` is the approved
   design.
5. `docs/plans/2026-07-29-meaningcore-human-pilot.md` is the implementation
   sequence.

If these documents conflict, the narrower privacy, permission, reversibility,
and no-overclaim rule wins. This goal cannot weaken a
`GOAL_FINISH_WIKI.md` gate.

## Planning Baseline

- CAM Assistant path: `/Volumes/WS4TB/waswiki/CAM_Assistant`
- CAM branch: `agent/portable-canonical-repo`
- CAM planning commit: `26c9d59`
- MeaningCore path: `/Volumes/WS4TB/me-ning/MeaningCore`
- MeaningCore branch: `main`
- MeaningCore commit:
  `23db68044ebdc410edf3b7f436e433ffba6e94b8`
- MeaningCore upstream:
  `https://github.com/deesatzed/meaningcore.git`

Both identities must be refreshed before implementation. MeaningCore remains
separately owned and must not be modified under this goal.

## Outcome

CAM Assistant contains a native, opt-in **Meaning Preview** that:

- links a pinned, provenance-recorded MeaningCore library;
- remains absent from default CAM behavior until explicitly enabled;
- reads only context the person explicitly selects and CAM permits;
- stores pilot state in a separate CAM-owned SQLite namespace;
- initially provides deterministic practical utility;
- enables reflective candidate generation only through an explicit user
  request and only after a frozen selected-local-model gate passes;
- normally returns silence or one practical/reflective opening;
- exposes concise Inspect evidence, provenance, uncertainty, and why surfaced;
- supports `Now`, `Later`, `Release`, `Helpful`, and `Not helpful`;
- never treats an action as proof that the result helped;
- can be disabled without changing or deleting existing CAM memory;
- produces local, user-owned pilot evidence for a later promote/revise/stop
  decision.

## Permanent Pilot Covenants

1. **Opt-in only.** Discovery or package linkage does not enable Meaning
   Preview.
2. **No authority from enablement.** Enablement grants no data, model, network,
   notification, mutation, execution, or spend permission.
3. **Existing CAM data remains authoritative and unchanged.** The pilot does
   not rewrite vault objects, derived documents, tasks, knowledge claims,
   conversations, model profiles, or repository evidence.
4. **Isolated state.** Pilot state has its own CAM-owned database, version,
   backup boundary, recovery path, and disable behavior.
5. **Explicit context.** Only active, explicitly selected, permitted derived
   context may enter MeaningCore.
6. **No raw-source copying.** Immutable source bytes, credentials, secrets,
   private keys, and restricted content do not enter pilot state.
7. **User-pull only.** The pilot schedules no notification, daily ritual,
   background reflection, or unsolicited nudge.
8. **Utility before reflection.** The practical lane works without a model.
9. **Reflection is separately gated.** A selected local model may supply a
   candidate only after explicit request, current-context assembly, frozen
   evaluation, and MeaningCore validation. No cloud, web, CAM, or fallback.
10. **One opening or silence.** No feed, queue, dashboard, or accumulation.
11. **No human score.** No stress, usefulness, happiness, contentment, service,
    meaning, virtue, personality, or worth score.
12. **No engagement mechanics.** No streak, badge, rank, leaderboard,
    broken-chain guilt, or retention optimization.
13. **Actions are not outcomes.** `Now`, `Later`, `Release`, selection, and
    Keep do not become helpful-outcome evidence.
14. **Corrections are cheap.** Rejecting or correcting a result retires or
    revises pilot state without a review queue.
15. **No external action.** A possible external or mutating act becomes a CAM
    proposal or ActionCard only; the pilot never executes it.
16. **No clinical authority.** Anxiety-specific behavior remains narrow and
    typed; serious context routes only to CAM-owned host escalation.
17. **Disable is real.** Disabled Meaning Preview has no effect on ordinary
    CAM behavior and does not delete CAM or pilot evidence.
18. **No promotion by implementation.** Ingrained behavior requires human
    evidence and a separate explicit decision.
19. **No product claim exceeds evidence.** Compiling, tests, scenarios, or
    pilot enthusiasm do not prove the larger human answer.

## Architecture Boundary

MeaningCore owns deterministic meaning-domain types and policies.

CAM owns:

- `CAMMeaningContextAdapter`;
- `MeaningPreviewCoordinator`;
- `MeaningPreviewStore`;
- `MeaningPreviewAuditSink`;
- `MeaningPreviewCandidateSupplier`;
- `MeaningActionProposalAdapter`;
- `MeaningPreviewWorkspace`;
- module enablement, permission, health, and lifecycle;
- human-pilot protocol and evidence.

The adapter direction is one way at the selection boundary:

```text
explicit CAM selection
  -> CAM permission and lifecycle checks
  -> typed MeaningCore context
  -> MeaningCore decision
  -> CAM projection
  -> isolated pilot state/receipt
```

MeaningCore does not import CAM. CAM must not copy MeaningCore logic into a
parallel implementation.

## Proof Of Done

### Gate 1: Dependency, Provenance, And Portability

- CAM pins the exact approved MeaningCore revision through SwiftPM.
- `Package.resolved` and saved evidence identify repository, revision,
  license status, Swift tools compatibility, and product.
- CAM imports the MeaningCore library, not `MeaningCoreCLI`.
- A clean dependency-resolution and release-build receipt exists.
- Packaged runtime behavior requires no network after build dependencies are
  resolved.
- MeaningCore remains independently buildable and its aggregate verifier
  passes at the pinned revision.

### Gate 2: Opt-In Module And No Default Effect

- A native non-core `cam.meaning-preview` manifest validates.
- Discovery grants no permissions.
- Enabling alone grants no permissions and does not expose context.
- Meaning Preview is absent from normal workspace navigation while disabled.
- Disabled-state tests prove no change to chat, Library, tasks, capture,
  retrieval, notifications, routing, or model selection.
- Health failure removes only Meaning Preview capability.

### Gate 3: Isolated Persistence And Recovery

- CAM owns a separate `MeaningPreview.sqlite` store and schema version.
- Existing CAM database migrations and records are unchanged.
- Atomic migration, restart, malformed-state refusal, backup boundary,
  archive/reinitialize recovery, and disabled-state behavior pass.
- Pilot state stores typed identifiers and derived meaning records, not raw
  immutable source bytes.
- Removing or disabling the module cannot delete CAM vault or database data.

### Gate 4: Explicit Context Adapter

- The adapter accepts only explicit source or conversation selections.
- Hidden, inactive, restricted, secret-like, unsupported, stale, or missing
  material is excluded before MeaningCore invocation.
- Every included item retains source, age, uncertainty, permitted use, and
  provenance.
- Unmappable CAM data fails closed without inventing MeaningCore memory.
- Context assembly is bounded, deterministic, and independently inspectable.

### Gate 5: Deterministic Practical Pilot

- The first pilot works with no local model or network.
- A person can explicitly request practical utility from selected context.
- MeaningCore returns zero or one practical item.
- Depleted capacity suppresses ordinary resurfacing while preserving the
  approved imminent-commitment exception.
- `Now`, `Later`, and `Release` produce typed isolated state changes.
- Restart, correction, expiry, rejection, and correct-silence cases pass.

### Gate 6: Separately Gated Reflective Pilot

- Reflection is unavailable until explicitly enabled after Gate 5.
- A frozen Meaning Preview corpus records expected decisions, forbidden
  behavior, evidence, counterevidence, abstention, and pressure risks.
- A named selected local model must pass the frozen gate before human use.
- Candidate generation is explicit, loopback-only, current-context-only,
  structured, bounded, ephemeral, and no-fallback.
- MeaningCore independently rejects unsupported, moral, diagnostic, destiny,
  ideal-self, or missing-distinction candidates.
- Failure or abstention returns silence or a direct local error, not automatic
  escalation.

### Gate 7: Native Human Experience

- Meaning Preview is clearly labeled Preview and explicitly enabled.
- The workspace is keyboard-first, VoiceOver-labeled, reduced-motion aware,
  and understandable without onboarding.
- It shows zero or one practical/reflective card and a concise Inspect view.
- It supports `Now`, `Later`, `Release`, `Helpful`, `Not helpful`, and Disable.
- Generated possibilities remain ephemeral unless explicitly kept.
- No routine confirmation, journal, questionnaire, review queue, daily ritual,
  score, task backlog, or notification is introduced.
- Empty, loading, silence, unavailable, incompatible, corrupted-store,
  restricted-context, abstention, and recovery states are covered.

### Gate 8: Feedback, Audit, And Graceful Wrongness

- Helpful and non-helpful feedback is explicit and domain-scoped.
- `Now`, `Later`, `Release`, selection, and Keep do not imply helpfulness.
- Corrections propagate inside isolated pilot state.
- Wrong suggestions retire or lower confidence without blame or repeated
  exposure.
- Audit receipts contain decision identifiers, policy reasons, exclusions,
  versions, and status without raw sensitive content.
- External or mutating possibilities produce non-executing CAM proposals only.

### Gate 9: Human Pilot

- A human-pilot protocol is approved before observing results.
- The protocol defines participant consent, minimum evidence sufficiency,
  duration, tasks, qualitative questions, local data handling, withdrawal,
  stopping rules, and report format.
- Participants use a packaged build against synthetic or explicitly approved
  personal context.
- Evidence evaluates the system, not the person's worth, contentment, meaning,
  service, or productivity.
- The report covers first-use comprehension, useful resurfacing, correct
  silence, nuisance, pressure, correction burden, Inspect comprehension,
  delight, distinctiveness, disable/recovery, and failures.
- Invalid, contaminated, withdrawn, or incomplete sessions remain separate
  and cannot be relabeled as support.

### Gate 10: Promotion Decision

- A limitations-first pilot report ends with one verdict:
  `promote-candidate`, `revise-and-retest`, or `stop`.
- `promote-candidate` identifies each proposed ingrained behavior separately.
- No default CAM behavior changes under this goal.
- Any promotion requires a new approved goal naming affected surfaces,
  permissions, migrations, rollback, evidence, and proof gates.

### Gate 11: Aggregate Verification And Containment

- Focused Meaning Preview suites pass.
- `/bin/zsh scripts/verify.sh all` passes.
- Package, reproducibility, privacy, fresh-clone, goal-map, and
  `git diff --check` pass.
- A packaged opt-in/disable/restart journey passes.
- MeaningCore verification passes at the pinned revision.
- Current branches, commits, dirty states, commands, results, limitations, and
  deferred work are saved.
- MeaningCore and donor repositories remain unchanged.
- Existing CAM proof gates do not regress.

## Human Evidence Rules

The pilot may record local system receipts and voluntary qualitative feedback.
It must not create covert telemetry, engagement goals, or a psychological
profile.

Measures may describe:

- whether a surface was understood;
- whether a result was useful, mistimed, confusing, or pressuring;
- whether silence was preferable;
- how much correction was required;
- whether Inspect made the result understandable;
- whether disable and recovery worked;
- whether the experience felt upbeat, adult, confident without false
  certainty, and distinct from self-help/task apps.

Measures must not rank participants or infer their meaning, usefulness,
contentment, stress, virtue, personality, diagnosis, or future trajectory.

## Scope

### May Modify During Future Implementation

- `Package.swift` and `Package.resolved`;
- CAM source, tests, fixtures, module manifests, schemas, scripts, and UI;
- repository truth and evidence documents;
- disposable test stores and packaged test artifacts.

### Read Only

- `/Volumes/WS4TB/me-ning/MeaningCore`;
- all donor repositories;
- live personal vaults unless a person explicitly approves a bounded pilot
  context;
- live CAM/CAM_Codx corpora and configurations except through separately
  approved disposable-copy proof.

### Must Not Modify Under This Goal

- MeaningCore source or history;
- donor repositories;
- existing CAM vault objects merely to populate the pilot;
- cloud/provider accounts, credentials, or routing defaults;
- signed/notarized/distributed production releases;
- default CAM behavior.

## Iteration Order

1. Refresh identities and prove dependency compatibility.
2. Add the opt-in module contract with no permissions.
3. Add adapter types and isolated persistence.
4. Prove deterministic practical utility with no UI.
5. Add the Preview workspace and disable/recovery behavior.
6. Add explicit feedback and bounded audit.
7. Create and freeze the reflective evaluation corpus.
8. Admit one named selected local model only after it passes.
9. Run the packaged human pilot.
10. Publish a limitations-first promote/revise/stop report.

## Stop Conditions

Stop and preserve evidence if:

- implementation would modify MeaningCore or a donor without separate scope;
- existing CAM memory must be rewritten or destructively migrated;
- a clean isolated persistence boundary cannot be maintained;
- default CAM behavior changes before human evidence and approval;
- reflection requires cloud, web, CAM, hidden fallback, or unapproved data;
- raw secrets or restricted content could enter pilot state or evidence;
- a selected local model fails the frozen reflective gate;
- a human reports material pressure, coercion, clinical framing, or inability
  to disable/recover;
- legal or licensing uncertainty blocks the intended pilot distribution;
- verification requires weakening an existing CAM or MeaningCore gate;
- the live checkout changes in an overlapping area during implementation;
- production deployment, signing, notarization, or external distribution is
  required.

Failed experiments remain evidence. Do not tune frozen labels after observing
results or relabel a failed model/session as support.

## Complete

This goal is complete only when:

- all eleven gates have current direct evidence;
- humans have used a packaged opt-in pilot under an approved protocol;
- a limitations-first promote/revise/stop report exists;
- ordinary CAM remains unchanged while the pilot is disabled;
- MeaningCore and donor repositories remain unchanged;
- no default or ingrained integration is claimed or performed.

Completion means the isolated human pilot answered whether the direction
warrants another experiment. It does not mean the larger human problem is
solved.
