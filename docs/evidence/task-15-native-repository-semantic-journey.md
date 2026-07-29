# Native Repository Semantic Journey Evidence

**Date:** 2026-07-29
**Status:** Partial. Native controls and isolated state transitions pass; a
packaged journey with a named V3-passing model is not yet available.

## Implemented journey

From the native Repositories workspace, the user can now:

1. inspect an explicitly selected local Git repository;
2. request bounded local-model evidence analysis;
3. cancel the operation;
4. see accepted, abstained, stale, insufficient-evidence, unavailable-model,
   and failed outcomes without fallback;
5. review exact model/runtime/commit identity, closed claim IDs, confidence,
   support citations, and counterevidence citations;
6. enter one idea title, rejected alternative, and smallest validation
   experiment;
7. create an evidence-complete proposal; and
8. separately Keep, Reject, save a local task, create a retained local research
   plan, or save a Codex-plan handoff.

Creating the candidate or proposal does not retain it. Every durable action is
an explicit separate user control.

## Repository and authority boundary

- Runtime evidence is accepted only for a clean snapshot whose canonical path
  and commit still match a new read-only intake.
- Excerpts come from `git show` at the recorded commit, never uncommitted
  working-tree bytes.
- The builder selects no more than eight deterministic representative items
  and requires both support and counterevidence.
- Cancellation is checked during intake, selection, and evidence construction.
- The selected model is health-checked at an explicit loopback endpoint before
  generation.
- Deterministic ID/role/snapshot validation, not model prose, decides whether a
  result can be shown as accepted.
- There is no cloud/provider substitution, web call, CAM call, repository
  write, code copy, or automatic retention.

## Automated evidence

| Command | Result |
|---|---|
| `/bin/zsh scripts/verify.sh repositories` | 64 repository tests pass, including exact/stable/read-only runtime bundles, eight-item large-repository selection, cancellation, commit drift, health-before-generation, strict validation, and evidence-complete V3 card conversion |
| `/bin/zsh scripts/verify.sh app` | 16 AppModel/accessibility tests pass, including accepted, abstained, stale, unavailable, insufficient, cancelled, proposal creation, model/runtime identity, both evidence roles, and explicit retention controls |
| `/bin/zsh scripts/verify.sh models` | Profile, loopback endpoint, health, identity, redirect-refusal, and local-model failure boundaries pass |
| `/bin/zsh scripts/verify.sh privacy` | Restricted-fixture zero-egress and status-only audit boundaries pass |
| `/bin/zsh scripts/verify.sh fresh-clone` | Exact clean implementation checkpoint `4193820165d12d057f512bce17350bf02f4b6dd6` passes all 260 tests, release builds, reproducible packaging, `dirty=false` identity, 53-file zero-finding scan, and offline smoke from a temporary non-local clone |

All repository tests use disposable temporary Git repositories and compare
exact working-tree status and committed file bytes before and after analysis.
App tests use injected sendable operations and do not start a model, read a
personal repository, or write a personal vault.

## Named-model boundary

The frozen V3 Gemma 12B run remains failed at claim recall `0.5`,
counterevidence recall `0.5`, claim/support precision `1.0`, and abstention
accuracy `1.0`. Its unchanged failed receipt is
`task-15-repository-semantic-v3-gemma-failed-report.json`.

Therefore this evidence does not claim useful packaged live-model completion.

## Remaining packaged proof

1. Run the unchanged V3 corpus against a named model that passes.
2. Build a clean exact-commit unsigned package.
3. Launch it only with an isolated application-support root.
4. Select a disposable clean repository and the passing model.
5. Exercise accepted or abstained analysis and one explicit disposition or
   promotion.
6. Save repository byte hashes and Git status before and after.
7. Relaunch and verify only the explicitly retained state persists.
