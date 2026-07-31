# ADD2CAM Core Practical Coordinator

## GOAL ID

`ADD2CAM-10`

## ROLE

Implement the deterministic, persistence-backed practical Meaning Preview coordinator and freeze the interfaces required by later goals.

## PREREQUISITE COMMIT

`7e4bc1de9378206a102f3334bb292aa21ff2b9a6`

## BRANCH / WORKTREE

Branch `agent/add2cam-10-core-practical`; worktree `/private/tmp/cam-add2cam-20260731/core-practical`.

## DEPENDENCIES

Pinned MeaningCore `23db68044ebdc410edf3b7f436e433ffba6e94b8`; accepted dependency, grant, module, adapter, and isolated-store slices.

## OUTCOME

One actor-serialized, local-only coordinator refuses reads without opt-in and grant, returns silence or one deterministic practical card, persists typed lifecycle/feedback changes, and survives restart without implicit helpfulness.

## PROOF OF DONE

- Red then green focused coordinator tests cover denied lazy reads, silence, ordering, depleted-capacity rules and the imminent commitment boundary.
- `Now`, `Later`, `Release`, rejection, correction, expiry, restart, stale-version refusal, rollback on save failure, and deterministic semantic replay pass.
- Existing Meaning Preview and storage tests pass.
- No model, CAM, web, cloud, notification, or external action is invoked.

## OWNED FILES

`Sources/CAMAssistantCore/Meaning/MeaningPreviewModels.swift`; `Sources/CAMAssistantCore/Meaning/CAMMeaningContextAdapter.swift`; `Sources/CAMAssistantCore/Meaning/MeaningPreviewStore.swift`; `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`; `Tests/CAMAssistantCoreTests/MeaningPreviewCoordinatorTests.swift`; `Tests/Fixtures/MeaningPreview/v1/practical-scenarios.json`; `docs/handoffs/add2cam/20260731/10_CORE_PRACTICAL.md`.

## PROTECTED FILES

All repository truth files, other goal files and handoffs, app/UI sources, scripts, MeaningCore, donor repos, personal data, live CAM data.

## SAFETY / PROVENANCE

Use MeaningCore only through the pinned Swift dependency. Use synthetic fixtures. Fail closed on malformed commitments and identifier collisions. Persist bounded state only in the isolated preview store.

## AUTONOMOUS DECISION POLICY

Choose the smallest API that satisfies tests and later frozen boundaries. Document safe assumptions in the handoff. Stop rather than broaden authority or change donor code.

## CONSTRAINTS

Use TDD. Preserve saved Later/Release/rejection lifecycle while reconciling fresh selections. Do not overclaim generic inspect evidence as actual ranking rationale. Avoid unchecked concurrency unless a documented single-owner boundary makes it necessary.

## ITERATION

Run focused tests red, implement minimally, run coordinator tests green, then existing Meaning Preview and storage regressions and `git diff --check`.

## HANDOFF

Write the required durable handoff with base/branch/worktree, commits, file list, red/green receipts, decisions, boundaries, limitations, and `verified_success`, `verified_partial`, `blocked`, `unsafe`, or `invalidated`.

## RETRY / RECOVERY

Diagnose failures before patching. Retry implementation twice at most. If persistence or concurrency cannot fail closed, stop with exact evidence and leave the worktree recoverable.

## STOP

Stop on any request for donor edits, personal/live data, hidden outbound/model access, weaker tests, destructive recovery, or a material interface expansion not authorized here.

## COMPLETE

Complete only with an owned-files-only commit, durable handoff, clean worktree, and all focused/regression commands green.
