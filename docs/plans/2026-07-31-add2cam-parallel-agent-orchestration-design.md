# ADD2CAM Parallel-Agent Orchestration Design

## Status

Approved on 2026-07-31 for implementation. This design governs autonomous
software completion of the isolated Meaning Preview pilot through a packaged,
verified `READY_FOR_HUMAN_PILOT` state. It does not replace
`GOAL_ADD2CAM.md`, authorize default CAM behavior, or substitute synthetic
agents for required human-pilot evidence.

## Objective

Complete the remaining software work in `GOAL_ADD2CAM.md` without routine
human steering by using one integration owner and bounded parallel workers.
Every worker operates from an exact accepted commit, owns an explicit file
surface, proves its behavior test-first, and returns a durable handoff. The
integrator alone accepts commits, updates repository truth, and advances the
dependency graph.

## Chosen Approach

Use a phased Git-worktree dependency graph:

1. one orchestrator/integrator owns the accepted branch;
2. each writing worker receives a separate branch, worktree, and goal file;
3. workers run concurrently only when dependencies and file ownership are
   disjoint;
4. integration is serialized and evidence-gated;
5. aggregate, packaging, fresh-clone, FSEvents, hotkey, and GUI verification
   run with no concurrent writers or builds;
6. the autonomous terminal state is `READY_FOR_HUMAN_PILOT`.

This was selected over shared-checkout parallel writing, which creates source,
test, Swift build-cache, package-artifact, and Git-index collisions. Fully
independent clones remain a recovery option if Git worktrees cannot be created
safely on the current volume.

## Authority

Authority remains:

1. `GOAL_FINISH_WIKI.md` for CAM Assistant completion;
2. `GOAL_ADD2CAM.md` for the Meaning Preview pilot;
3. repository truth files;
4. the approved MeaningCore pilot design and implementation plan;
5. this orchestration design and its generated worker goals.

Narrower privacy, permission, reversibility, provenance, and no-overclaim
requirements always win.

## Baseline

- CAM repository: `/Volumes/WS4TB/waswiki/CAM_Assistant`
- Accepted starting commit: `decb0c77d79c6507b972a8230f0e3dba096a184c`
- Accepted source branch: `agent/portable-canonical-repo`
- Integration branch: `agent/add2cam-integration-20260731`
- MeaningCore revision:
  `23db68044ebdc410edf3b7f436e433ffba6e94b8`
- MeaningCore and donor repositories remain read-only.

The integrator must refresh these identities before dispatch and before final
containment verification.

## Goal Family

The implementation will use these contracts under `goals/add2cam/`:

| Goal | Responsibility | Dependency |
|---|---|---|
| `00_ORCHESTRATOR.md` | Dispatch, worktrees, acceptance, retries, integration, truth and aggregate proof | Baseline |
| `10_CORE_PRACTICAL.md` | Finish persistence/adapter gaps and implement the deterministic actor coordinator | Baseline |
| `20_NATIVE_UX.md` | Opt-in Preview, Inspect, Settings, accessibility, disable and recovery | Goal 10 integrated |
| `21_FEEDBACK_AUDIT.md` | Feedback semantics, corrections, bounded audit, proposal-only actions | Goal 10 integrated |
| `30_REFLECTIVE_EVALUATION.md` | Create and freeze the offline evaluation before model observation | Goal 10 integrated |
| `40_REFLECTIVE_LANE.md` | Admit one explicit loopback-only local model only if the frozen gate passes | Goals 20, 21 and 30 integrated |
| `50_PACKAGED_PILOT.md` | Package, isolated journey, aggregate/fresh-clone proof, and pilot-ready packet | Goal 40 terminal and prior goals integrated |
| `60_HUMAN_EVIDENCE.md` | Protocol approval, actual participants, limitations-first verdict | `READY_FOR_HUMAN_PILOT` plus humans |

The orchestrator may mark Goal 40 `verified_partial` when a named model fails
the frozen gate. The failure is preserved, reflection remains unavailable, and
the practical pilot may continue to a clearly limited packaged state. Frozen
labels must not be tuned after model observation.

## Execution Waves

```text
Wave 0: Orchestrator preflight and ownership hardening
Wave 1: Goal 10 Core Practical
Wave 2: Goal 20 Native UX || Goal 21 Feedback/Audit || Goal 30 Evaluation
Wave 3: Integrate Wave 2, then Goal 40 Reflective Lane
Wave 4: Goal 50 Packaged Pilot and final integration verification
Wave 5: READY_FOR_HUMAN_PILOT
Wave 6: Goal 60 Human Evidence when humans are available
```

One of four concurrency slots remains assigned to the orchestrator. At most
three writing workers run simultaneously. On the external volume, no more than
two Swift compilations run concurrently; a third worker may write or perform
read-only analysis while it waits.

## Ownership Hardening

The existing implementation plan routes multiple goals through
`MeaningPreviewTests.swift`. Before Wave 2, Goal 10 must establish dedicated
test ownership:

- `MeaningPreviewCoordinatorTests.swift` for Goal 10;
- `MeaningPreviewAppModelTests.swift` for Goal 20;
- `MeaningPreviewBoundaryTests.swift` for Goal 21;
- `MeaningPreviewEvaluationTests.swift` for Goal 30;
- `MeaningPreviewReflectionTests.swift` for Goal 40.

Goal 10 freezes the app-facing request, result, action, and state-store
protocols before Wave 2. Later workers must not independently change those
protocols. A required interface change becomes an integrator-owned amendment
with focused regression proof.

## Worker Contract

Every worker goal contains:

- goal ID and role;
- exact prerequisite commit;
- branch and worktree path;
- dependencies;
- measurable outcome and proof of done;
- exhaustive owned-file allowlist;
- protected-file list;
- safety and provenance rules;
- autonomous decision policy;
- test-first iteration and retry rules;
- required handoff artifact;
- stop and completion states.

Workers may edit only their allowlist. They must not update `GOAL*.md`,
`DECISIONS.md`, `PROGRESS.md`, `TASK_QUEUE.md`, final verification reports, or
the goal map. Those files belong only to the integrator.

## Durable Worker Handoff

Each worker returns a unique Markdown handoff under
`docs/handoffs/add2cam/20260731/` containing:

- prerequisite commit, branch, and worktree;
- implementation commit SHA or SHAs;
- exact changed-file list;
- observed red command and failure;
- green commands and results;
- evidence paths;
- assumptions and decisions;
- protected-boundary confirmation;
- limitations and failed experiments;
- recommended integration order;
- final Git status;
- one terminal status: `verified_success`, `verified_partial`, `blocked`,
  `unsafe`, or `invalidated`.

A chat response alone is not an acceptable handoff.

## Integration Protocol

For every worker branch, the orchestrator must:

1. confirm the worker started from the required commit;
2. confirm `git diff --name-only BASE...HEAD` is a subset of owned files;
3. read the patch and durable handoff;
4. run the worker's focused verification;
5. obtain an adversarial boundary, privacy, and test-gap review;
6. classify the result `Accepted`, `Rejected`, or `Needs Investigation`;
7. cherry-pick accepted commits in dependency order;
8. run affected regressions after each integration;
9. update truth files only from accepted command receipts;
10. spawn newly unblocked goals automatically.

If a cherry-pick conflicts, the integration attempt is rejected. The worker is
rebased or regenerated from the new accepted integration commit; workers do
not resolve cross-goal conflicts independently.

## Permissions And Build Isolation

Each worktree owns its own `.swift-build`, module cache, and `artifacts`
directory. Focused Swift commands use:

```zsh
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.swift-build/module-cache" \
CLANG_MODULE_CACHE_PATH="$PWD/.swift-build/module-cache" \
swift test --disable-sandbox --scratch-path "$PWD/.swift-build" \
  --filter <FocusedTests>
```

`--disable-sandbox` disables SwiftPM's nested sandbox; it does not disable the
outer Codex permission boundary. Narrow escalation may be used only when the
managed environment rejects required Git worktree metadata, dependency
resolution, repository verification, FSEvents, or packaged GUI execution.

The automation must never use `sudo`, broad `chmod`, disabled operating-system
security, `danger-full-access`, unsafe permission-bypass flags, or credentials
inside worker prompts.

Aggregate verification, packaging, reproducibility, privacy scanning,
fresh-clone verification, and packaged GUI journeys are serialized. Only one
packaged CAM app instance runs at a time to avoid bundle-ID, hotkey, state, and
FSEvents collisions.

## Autonomous Decision Policy

Routine implementation decisions require no human response. A worker must:

1. choose the smallest reversible option consistent with existing types,
   tests, decisions, and covenants;
2. record the assumption in its handoff;
3. work test-first in small commits;
4. classify failures as implementation, integration, environment, evidence,
   or stop-condition failures;
5. attempt at most three distinct documented mitigations;
6. block only the affected lane and continue independent ready work.

Immediate stops remain those in `AGENTS.md` and `GOAL_ADD2CAM.md`, including
donor mutation, primary-vault migration, restricted-data exposure, dependency
or licensing drift, overlapping unowned edits, weakened tests, cloud or hidden
fallback reflection, production deployment, and unresolved destructive action.

## Verification Strategy

Workers run the nearest focused tests. The integrator runs:

1. all focused Meaning Preview core, app, privacy, audit, accessibility, and
   storage suites;
2. `git diff --check`;
3. `/bin/zsh scripts/verify.sh meaning-preview`;
4. the packaged Meaning Preview journey;
5. `/bin/zsh scripts/verify.sh all` with no other build active;
6. disposable fresh-clone verification;
7. only the native GUI, FSEvents, hotkey, and VoiceOver checks that cannot be
   proven inside the managed sandbox;
8. final CAM and MeaningCore identity and dirty-state checks.

Synthetic, focused, packaged, model, and human evidence remain separately
labeled. No lower evidence class may be relabeled into a higher one.

## Recovery

Every worker commits bounded green batches. Worker branches remain until final
aggregate verification passes. If a temporary worktree disappears, the
orchestrator recreates it from the last worker commit and durable handoff.
Uncommitted work is never treated as durable completion.

The orchestrator maintains one machine-readable queue with goal ID,
prerequisite SHA, branch, worktree, status, attempts, terminal commit, evidence,
and blockers. A reboot or process crash must be recoverable from Git, this
queue, and worker handoffs without relying on chat history.

## Human-Free Ceiling

Autonomous agents may reach `READY_FOR_HUMAN_PILOT`, which means:

- deterministic practical behavior is complete;
- any reflective lane is either validly admitted or honestly unavailable;
- native UX, feedback, audit, disable, recovery, and isolation pass;
- packaged and fresh-clone journeys pass;
- aggregate containment evidence is current;
- a draft protocol exists.

`GOAL_ADD2CAM.md` cannot be marked complete until actual people provide
consent, use the packaged pilot, and produce valid human evidence followed by a
limitations-first `promote-candidate`, `revise-and-retest`, or `stop` verdict.
Automated agents and synthetic sessions cannot substitute for that proof.

## Design Decision

Proceed with the phased worktree DAG. The implementation plan and worker goals
must preserve the boundaries above. Any material change to concurrency,
ownership, human evidence, permissions, data access, or promotion requires a
new recorded decision before execution.
