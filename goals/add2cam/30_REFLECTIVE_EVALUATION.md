# ADD2CAM Reflective Evaluation

## GOAL ID

`ADD2CAM-30`

## ROLE

Create and cryptographically freeze the offline Meaning Preview evaluation before any named-model observation.

## PREREQUISITE COMMIT

Assigned by the orchestrator to the exact accepted Goal 10 integration commit before dispatch.

## BRANCH / WORKTREE

Branch `agent/add2cam-30-reflective-evaluation`; worktree `/private/tmp/cam-add2cam-20260731/reflective-evaluation`.

## DEPENDENCIES

`ADD2CAM-10` integrated; no dependency on a named-model result.

## OUTCOME

A versioned synthetic fixture, manifest, deterministic evaluator, CLI entry point, prohibited-behavior checks, thresholds, and exact SHA-256 are frozen before Goal 40 runs a selected model.

## PROOF OF DONE

Every case and prohibition validates offline; evaluator tests and `scripts/verify.sh meaning-preview` pass; the manifest hash is recorded; labels and thresholds are demonstrably pre-observation.

## OWNED FILES

`Tests/Fixtures/MeaningPreview/v1/manifest.json`; `Tests/Fixtures/MeaningPreview/v1/README.md`; `Sources/CAMAssistantCore/Meaning/MeaningPreviewEvaluation.swift`; `Tests/CAMAssistantCoreTests/MeaningPreviewEvaluationTests.swift`; `Sources/CAMAssistantCLI/main.swift`; `scripts/verify.sh`; `docs/evidence/add2cam-08-reflective-evaluation.md`; `docs/handoffs/add2cam/20260731/30_REFLECTIVE_EVALUATION.md`.

## PROTECTED FILES

Repository truth; coordinator/UI/feedback implementation; named-model evidence; MeaningCore; donors; live/personal data.

## SAFETY / PROVENANCE

Use synthetic data only. The frozen corpus is not lived-use evidence. No model may be queried before the fixture, labels, prohibitions, thresholds, and digest are committed.

## AUTONOMOUS DECISION POLICY

Choose discriminative, bounded, product-contract cases without observing model output. Once frozen, do not tune them in this goal.

## CONSTRAINTS

TDD; offline determinism; strict schema; failures exit nonzero while preserving reports; no provider fallback or network.

## ITERATION

Write fixture and failing evaluator tests, implement minimally, validate the CLI and verifier, compute SHA-256, and run `git diff --check`.

## HANDOFF

Record the pre-observation commit, digest, cases, thresholds, commands, limitations, and terminal status in `30_REFLECTIVE_EVALUATION.md`.

## RETRY / RECOVERY

Fix only contract bugs discovered before observation. After any observation, preserve the frozen version and create a separately versioned future proposal instead of editing it.

## STOP

Stop if model output has already contaminated case design, if synthetic provenance is uncertain, or if the evaluator cannot fail closed.

## COMPLETE

Complete with an owned-files-only pre-observation commit, exact digest, green offline proof, durable handoff, and clean worktree.
