# ADD2CAM-10 Core Practical Handoff

## Identity

- Prerequisite commit: `f30e9402e2a06d6f40cfe6213909667344fa87e0`
- Branch: `agent/add2cam-10-core-practical`
- Worktree: `/private/tmp/cam-add2cam-20260731/core-practical`
- Implementation commit: `4edba3a` (`Add practical Meaning Preview coordinator`)
- Recommended integration order: first; Goals 20, 21, and 30 remain blocked until this handoff is accepted.

## Changed Files

- `Sources/CAMAssistantCore/Meaning/MeaningPreviewModels.swift`
- `Sources/CAMAssistantCore/Meaning/CAMMeaningContextAdapter.swift`
- `Sources/CAMAssistantCore/Meaning/MeaningPreviewStore.swift`
- `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`
- `Tests/CAMAssistantCoreTests/MeaningPreviewCoordinatorTests.swift`
- `Tests/Fixtures/MeaningPreview/v1/practical-scenarios.json`
- `docs/handoffs/add2cam/20260731/10_CORE_PRACTICAL.md`

No file outside the Goal 10 allowlist changed.

## Observed Red Proof

Command:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewCoordinatorTests
```

Initial result: exit `1`. Compilation failed because `MeaningPreviewStateStoring`, `MeaningPreviewAccess`, `MeaningContextItemKind`, `MeaningPreviewCoordinator`, and `MeaningPreviewCoordinatorError` did not exist and the typed commitment arguments were unavailable. This was observed before production implementation.

## Green Proof

Final focused command:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewCoordinatorTests
```

Result: exit `0`; 14 Swift Testing cases passed. They cover denied lazy reads, silence, deterministic one-item selection, both sides of the depleted-capacity 24-hour commitment boundary, typed actions, no implicit helpfulness, restart, rejection, expiry, two-generation correction, stale writes, save rollback, actor serialization, invalid commitments, within-request and cross-request identifier collisions, explicit-selection isolation, backward snapshot decoding, and semantic fixture replay.

Regression commands:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
swift test --disable-sandbox --scratch-path .swift-build-storage \
  --filter StorageTests
git diff --check
```

Results: exit `0`; 3 existing Meaning Preview tests passed, 8 storage tests passed, and the diff check was clean.

## Decisions And Assumptions

- The coordinator is an actor and owns one synchronous `MeaningPreviewStateStoring` instance. The concrete SQLite store is `@unchecked Sendable` only at this documented single-owner actor boundary.
- Authorization precedes invocation of the lazy selection closure, so disabled or ungranted requests do not read context.
- Snapshot revision defaults to zero when decoding the pre-revision schema and increments only after a successful save. Mutations require the exact expected revision.
- Fresh selected items reconcile into retained isolated state, while presentation filters to the current explicit selection.
- Corrections receive a persisted root lineage. Only a coordinator-recorded correction chain whose root is currently selected may surface.
- Stable identifier ownership persists across requests. A different CAM item resolving to an existing UUID fails before reconciliation or save.
- A typed commitment without `dueAt` fails closed. The exact 24-hour deadline is eligible under MeaningCore; 24 hours plus one second is suppressed at depleted capacity.

## Review Classification

- Spec review: `PASS` after adding the negative side of the exact 24-hour boundary.
- Code-quality/boundary review: `APPROVED` after fixing explicit-selection conflict leakage, cross-request identifier collisions, and multi-generation correction lineage.
- Accepted recommendations: all three concrete findings above.
- Rejected recommendations: none.
- Needs investigation: none for Goal 10.

## Protected-Boundary Confirmation

- MeaningCore remained read-only at the pinned dependency revision.
- No donor repository, personal vault, live CAM corpus, repository truth file, app/UI file, script, network path, model path, notification path, or external-action path changed or ran.
- Tests use in-memory stores, temporary SQLite roots from existing tests, and synthetic fixture content only.
- No action records a helpful utility outcome.

## Limitations And Failed Experiments

- This completes only the deterministic practical coordinator contract. Native UX, feedback/audit adapters, the frozen reflective evaluation, model admission, packaged proof, and human evidence remain later goals.
- Stable identifiers intentionally remain deterministic and collision-prone; persisted ownership makes collisions fail closed rather than treating the hash as globally unique.
- Generic MeaningCore Inspect text is exposed as generic evidence only; it is not claimed to be the actual ranking rationale.
- Two delegated implementation attempts and one initial quality-review attempt stalled without filesystem output; the integrator recovered locally and preserved the review gates. No stalled attempt changed repository files.

## Final State

- Implementation status: `verified_success`
- Implementation commit worktree status before this handoff: clean
- Handoff commit: the commit containing this file
- Terminal status: `verified_success`
