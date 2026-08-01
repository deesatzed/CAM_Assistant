# ADD2CAM-21 Feedback and Audit Handoff

## Identity

- Prerequisite commit: `e5c4b21`
- Branch: `agent/add2cam-21-feedback-audit`
- Worktree: `/private/tmp/cam-add2cam-20260731/feedback-audit`
- Implementation commit: `37885d2` (`Bound Meaning Preview feedback and audit`)
- Recommended integration order: before Goals 30 and 20, matching the approved Wave 2 order.

## Changed Files

- `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`
- `Sources/CAMAssistantCore/Meaning/MeaningPreviewAuditSink.swift`
- `Sources/CAMAssistantCore/Meaning/MeaningActionProposalAdapter.swift`
- `Tests/CAMAssistantCoreTests/MeaningPreviewBoundaryTests.swift`
- `docs/handoffs/add2cam/20260731/21_FEEDBACK_AUDIT.md`

All paths are within the Goal 21 allowlist.

## Red Proof

The first focused command exited `1` because `MeaningPreviewMutation.utilityOutcome` and `MeaningActionProposalAdapter` did not exist:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewBoundaryTests
```

A subsequent spec review exposed runtime integration and binding gaps. New tests then failed until feedback was bound to a surfaced memory/domain/version, coordinator audit/proposal paths existed, and audit secret screening was exercised non-vacuously.

## Green Proof

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewBoundaryTests
/bin/zsh scripts/verify.sh privacy
swift test --disable-sandbox --scratch-path .swift-build-goal10-regression \
  --filter MeaningPreviewCoordinatorTests
git diff --check
```

Final results:

- 12 Goal 21 boundary tests passed.
- Privacy verification passed 8 privacy tests plus 3 audit tests.
- All 14 Goal 10 coordinator regressions passed.
- Diff check passed.

## Decisions

- Helpful/not-helpful feedback is bound to the exact currently surfaced memory, domain, and presentation revision. It is one-shot and retired after any mutation.
- Feedback authority is intentionally ephemeral. Restart fails closed and requires a fresh explicit request; interaction authority is not persisted merely to make an old card actionable.
- Corrections are bounded and classified with CAM's existing `DataClassifier`; only generic/public correction text may enter pilot persistence.
- Audit delivery is serialized inside the sink and nonthrowing after state commit. Delivery failure degrades an actor-visible health flag instead of falsely reporting that an already-committed operation failed.
- External and mutating possibilities become inert proposal values only. No executor or approval consumption is present. Restricted input produces a blocked, zero-byte result.

## Review Classification

- Spec review: `PASS` after coordinator integration, one-result feedback binding, complete operational-action coverage, and non-vacuous audit redaction.
- Quality/privacy review: `APPROVED` after audit serialization/error semantics, one-shot version binding, fail-closed restart, and classifier-backed correction screening were added.
- Accepted: all concrete spec and quality findings.
- Rejected: persisting feedback interaction authority across restart; the safer reviewed policy requires a fresh request.
- Needs investigation: none for Goal 21.

## Protected Boundaries

- No raw context, secret, model output, or proposal description is persisted in Meaning Preview audit receipts.
- Frozen restricted privacy fixtures, including `sk-`, bearer, credential, PII, PHI, traversal, and prompt-injection cases, are rejected before correction persistence.
- No proposal executes, sends bytes, invokes a model, invokes CAM, consumes approval, or mutates outside isolated preview state.
- MeaningCore, donors, personal vaults, live CAM data, repository truth, UI files, and evaluation files remained unchanged.

## Limitations

- Audit delivery health is status only; durable retry of an unavailable audit store remains future recovery work and does not rewrite a completed operation as failed.
- Native presentation of feedback/proposal/audit recovery belongs to Goal 20/50.
- No human-use claim follows from synthetic boundary proof.

## Final State

- Worktree after implementation commit: handoff-only change pending
- Handoff commit: the commit containing this file
- Terminal status: `verified_success`
