# ADD2CAM Reflective Lane

## GOAL ID

`ADD2CAM-40`

## ROLE

Implement one explicit, loopback-only reflective candidate lane and adjudicate it against the frozen evaluation.

## PREREQUISITE COMMIT

Assigned by the orchestrator to the exact integration commit containing accepted Goals 20, 21, and 30.

## BRANCH / WORKTREE

Branch `agent/add2cam-40-reflective-lane`; worktree `/private/tmp/cam-add2cam-20260731/reflective-lane`.

## DEPENDENCIES

Accepted `ADD2CAM-20`, `ADD2CAM-21`, and frozen `ADD2CAM-30`.

## OUTCOME

An explicitly requested selected loopback model may propose ephemeral structured candidates from bounded current context; deterministic MeaningCore validation accepts or abstains, with no fallback. A failing named model leaves reflection disabled while practical preview remains eligible.

## PROOF OF DONE

Reflection tests prove explicit request, loopback validation, selected model identity, bounded payload, strict structure, validation, abstention, no fallback, ephemeral output, and practical isolation. The frozen named-model report is preserved exactly.

## OWNED FILES

`Sources/CAMAssistantCore/Meaning/MeaningPreviewCandidateSupplier.swift`; `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`; `Sources/CAMAssistantApp/Views/MeaningPreviewView.swift`; `Tests/CAMAssistantCoreTests/MeaningPreviewReflectionTests.swift`; `Tests/CAMAssistantAppTests/MeaningPreviewAppModelTests.swift`; `docs/evidence/add2cam-09-named-model-report.json`; `docs/handoffs/add2cam/20260731/40_REFLECTIVE_LANE.md`.

## PROTECTED FILES

Frozen evaluation fixtures/labels/thresholds; repository truth; MeaningCore; donors; personal/live context; unrelated model routing.

## SAFETY / PROVENANCE

Only a validated OpenAI-compatible loopback endpoint is allowed. No authorization header, redirect, cloud, web, CAM, alternate model, or silent fallback. Generated content remains ephemeral unless a separately authorized explicit action exists.

## AUTONOMOUS DECISION POLICY

Preserve failing named-model evidence. If the frozen gate fails, return `verified_partial`, leave reflection disabled, and permit only the practical pilot path.

## CONSTRAINTS

No post-observation tuning. Use TDD. Context is bounded and current. Deterministic validation, not model prose, controls eligibility.

## ITERATION

Observe reflection tests red, implement minimal lane, run focused/core/app/privacy/evaluation tests, then run the named model only if its local endpoint is available.

## HANDOFF

Record exact model identity, endpoint classification without secrets, frozen digest, report, commands, limitations, and terminal status in `40_REFLECTIVE_LANE.md`.

## RETRY / RECOVERY

Transport/environment failures may be retried twice without changing the frozen contract. Quality failure is evidence, not an implementation retry target.

## STOP

Stop on non-loopback routing, secrets, redirects, model substitution, frozen-contract mutation, sensitive data, or repeated transport failure.

## COMPLETE

Complete as `verified_success` if the named model passes or `verified_partial` if honest failure is preserved and reflection is unavailable; require owned commit, handoff, and clean worktree.
