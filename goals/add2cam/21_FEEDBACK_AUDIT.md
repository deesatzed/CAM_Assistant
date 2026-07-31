# ADD2CAM Feedback and Audit

## GOAL ID

`ADD2CAM-21`

## ROLE

Prove explicit feedback semantics, correction/retirement behavior, status-only audit, and proposal-only external possibilities.

## PREREQUISITE COMMIT

Assigned by the orchestrator to the exact accepted Goal 10 integration commit before dispatch.

## BRANCH / WORKTREE

Branch `agent/add2cam-21-feedback-audit`; worktree `/private/tmp/cam-add2cam-20260731/feedback-audit`.

## DEPENDENCIES

`ADD2CAM-10` integrated.

## OUTCOME

Helpfulness is recorded only by explicit user action; operational actions never imply it. Corrections and retirement propagate, audit remains status-only, and external possibilities remain non-executing proposals with zero restricted outbound payload.

## PROOF OF DONE

Focused boundary tests prove explicit helpfulness, non-inference, correction, retirement, restart, redacted audit, proposal-only behavior, and zero outbound restricted bytes; privacy verification passes.

## OWNED FILES

`Sources/CAMAssistantCore/Meaning/MeaningPreviewAuditSink.swift`; `Sources/CAMAssistantCore/Meaning/MeaningActionProposalAdapter.swift`; `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`; `Tests/CAMAssistantCoreTests/MeaningPreviewBoundaryTests.swift`; `Tests/CAMAssistantCoreTests/AuditTests.swift`; `Tests/CAMAssistantCoreTests/PrivacyTests.swift`; `docs/handoffs/add2cam/20260731/21_FEEDBACK_AUDIT.md`.

## PROTECTED FILES

Repository truth; frozen coordinator API except integrator-approved amendment; Goal 20/30 sources and tests; MeaningCore; donors; personal/live data.

## SAFETY / PROVENANCE

Audit stores status, identifiers, timestamps, and bounded reason codes only. Never persist or emit raw sensitive context. Never execute a proposal or send a restricted payload.

## AUTONOMOUS DECISION POLICY

Prefer existing privacy/audit primitives. Fail closed on unknown classifications. Escalate any needed authority expansion.

## CONSTRAINTS

Use TDD; preserve action/helpfulness separation; do not weaken privacy fixtures or scanners; no network/model/CAM execution.

## ITERATION

Run boundary tests red, implement minimally, run them green, run `/bin/zsh scripts/verify.sh privacy`, then `git diff --check`.

## HANDOFF

Record commits, changed files, privacy receipts, redaction proof, assumptions, limitations, and terminal status in `21_FEEDBACK_AUDIT.md`.

## RETRY / RECOVERY

Retry twice after root-cause analysis. If redaction cannot be demonstrated, mark unsafe and stop.

## STOP

Stop for any raw-content audit, outbound restricted payload, execution authority, donor/live-data access, or repeated failure.

## COMPLETE

Complete with owned-files-only commit, focused and privacy proof green, durable handoff, and clean worktree.
