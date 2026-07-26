# REVIEW.md

## Review Scope

Commit-cited repository observation review, proposal-only idea-card flow,
explicit Keep/Reject retention, local retained-idea history, and cited
local-task promotion added to the native Repositories screen on 2026-07-26.

## Summary Judgment

Proceed

## Findings

| Severity | Category | Finding | Why It Matters | Required Fix |
|---|---|---|---|---|
| Accepted boundary | Correctness | Observation scans use the existing committed-snapshot extractor, which rejects dirty snapshots. | The UI does not mislabel working-tree text as reproducible commit evidence. | None. |
| Accepted boundary | Safety | The draft requires title, counterevidence, and validation experiment; confidence remains fixed at `0.5`. | The app does not fabricate certainty or counterevidence from source text. | None. |
| Accepted boundary | Lifecycle | Explicit Keep and Reject both persist card evidence and decision after validating the clean recorded snapshot; Reject disables task promotion. | Negative evidence is retained rather than lost or converted into an action. | None. |
| Accepted boundary | Authority | A displayed proposal is required before `Save as Local Task`; the resulting `TaskProposal` is fixed to `localRead` and persists only its cited task record. | It cannot execute code, invoke CAM, contact a network, or alter the donor repository. | None. |
| Optional | UX | A failed observation scan reports a generic reproducibility error. | It is safe but does not distinguish dirty state from a disappeared commit/file. | Add typed user-facing failure details only after preserving the current no-content error boundary. |

## Correctness

The exact commit/file/line/symbol/statement projection is immutable. The task
mapper rejects dirty snapshots, reuses idea-card stale-evidence validation, and
emits deterministic citations for every reviewed observation.

## Security and Privacy

The feature reads selected local repository Git data only. It sends no bytes,
persists no repository text, invokes no CAM tool, and adds no code-copy or
repository-write path. The new persistence is local only: a task record or a
kept/rejected idea-card record holding citations and user-authored criteria or
counterevidence.

## Tests

The local-task mapper and idea-retention store tests were observed red before
their respective implementations. Focused repository verification passed 18
tests, including restart persistence of tasks and Keep/Reject cards. Aggregate
verification passed 144 tests with release app/CLI builds; `git diff --check`
also passed.

## Maintainability

The SwiftUI view consumes immutable Core projections; committed-Git extraction
remains outside the app layer and runs off the SwiftUI actor.

## Performance

Observation extraction runs in a detached task. Existing inspection behavior is
outside the reviewed change.

## UI/UX Impact

The Repositories view now lets the user scan, inspect, select, and draft from
cited evidence with explicit proposal-only language and accessibility labels.
Only after a proposal appears can the user choose `Save as Local Task`. They
can instead choose Keep or Reject; rejection visibly disables task save.
Retained decisions remain available in a local history section after restart.

## Regression Risk

Low for the local read-only evidence/proposal/card/task flow after focused and
aggregate verification. Live use against a real selected repository remains
unproven.

## Scope Creep Check

No semantic architecture inference, automatic idea generation, Codex-plan
creation, CAM mining, network call, task execution, or repository modification
was added. Explicit user-initiated persistence of local cards and a local-read
task was added.

## Required Fixes Before Done

None for this bounded local evidence/proposal slice.

## Optional Improvements

- Add typed scan-failure presentation without exposing repository source text.
- Add research-packet/Codex-plan promotion only after defining their lifecycle
  and ownership.
