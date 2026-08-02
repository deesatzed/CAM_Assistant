# CAM Assistant ADD2CAM Status Checkpoint

**Date:** 2026-08-02  
**Purpose:** durable recovery note after a system-memory interruption during the
Goal 50 packaged Meaning Preview proof.

## Current decision

`ADD2CAM-50` is still **in progress / not accepted**. The autonomous ceiling
remains `READY_FOR_HUMAN_PILOT`; `ADD2CAM-60` is still human-only and must not
be started by an agent.

The packaged native journey is red. Do not mark Goal 50 complete, integrate its
commits, or claim a human-pilot-ready build until the explicit Enable -> zero
permissions -> Grant transition and the remaining release proof are green.

## Repository identities

- Canonical checkout: `/Volumes/WS4TB/waswiki/CAM_Assistant`
- Canonical branch: `agent/add2cam-integration-20260731`
- Canonical HEAD: `0bc2b91` (`docs: dispatch Goal 50 packaged pilot`)
- Goal 40 accepted prerequisite: `5409c3b`
- Goal 50 worktree: `/private/tmp/cam-add2cam-20260731/packaged-pilot`
- Goal 50 branch: `agent/add2cam-50-packaged-pilot`
- Goal 50 worktree HEAD: `b69a3d5` (`test: separate packaged enable and grant phases`)
- Goal 50 worktree is clean as of this checkpoint.

The canonical checkout still has only the previously observed user-owned
untracked ReAgent/pendoleum files. They were not edited, staged, or included in
this checkpoint.

## Completed implementation before this checkpoint

- Goals 10, 20, 21, and 30 are integrated and accepted.
- Goal 40 is integrated as `verified_partial`: deterministic practical Preview
  is eligible; the named local model was unavailable, so reflection remains
  disabled with no fallback.
- Goal 50 packaging embeds the Meaning Preview manifest, the SwiftPM core
  resource bundle, and the committed named-model report when present.
- The packaged harness uses a disposable clone, disposable Application Support,
  stable native AX identifiers, no clipboard mutation, no process killing, and
  status-only audit checks.
- The product now rejects duplicate lifecycle activation while an operation is
  in flight (`afe27c0`) and clears the operation-working flag before publishing
  the new lifecycle (`9df1bde`).
- The harness has status-only AX diagnostics and separate Enable, sheet-close,
  workspace-select, and Grant phases (`a8c0fc4`, `004c201`, `b69a3d5`).

## Verified actions in this session

Focused tests passed on the Goal 50 worktree:

```text
swift test --disable-sandbox --scratch-path .swift-build-goal50-test \
  --filter meaningPreviewAppModelOptInIsSeparateFromGrant
  "AppModel hides disabled Preview and enablement grants no local access" passed

swift test --disable-sandbox --scratch-path .swift-build-goal50-test \
  --filter meaningPreviewAppModelIgnoresDuplicateLifecycleActivation
  "Meaning Preview ignores duplicate lifecycle activation while one is in flight" passed
```

`zsh -n`, `git diff --check`, and the focused static/AX contract checks passed
for the committed Goal 50 slices before the latest GUI attempt.

The interrupted GUI run left a disposable `CAMAssistant` process. It was
terminated by PID, and the exact disposable root was permission-restored and
removed. A follow-up process check found no live CAMAssistant, Swift build, or
AX-driver process.

## Packaged proof evidence so far

The following results are failures or incomplete observations, not acceptance:

1. At `6866ffe`, the run reached `capture=pass` and then reported
   `ax-exercise-missing-meaning-preview-grant`, with status-only diagnostic
   `enabled=true permission_count=2`.
2. After the consent-boundary split at `2641b23`, the run reached
   `capture=pass`, `enable=pressed`, and reported a disabled workspace Grant
   control while the module state correctly showed `enabled=true
   permission_count=0`.
3. `5f7754d` confirmed the same disabled Grant result even when the AX lookup
   was scoped to `meaning-preview-workspace` / `meaning-preview-permission-state`.
4. `9df1bde` reordered lifecycle publication and the focused regression passed,
   but the clean GUI run still reported the disabled Grant control.
5. `a8c0fc4` temporarily exposed a diagnostic Swift syntax error; `004c201`
   corrected it and passed shell syntax checks.
6. At `004c201`, the run reported
   `ax-exercise-disabled-meaning-preview-grant-anchors-0-buttons-0-enabled-none`
   while the module state showed `enabled=true permission_count=2`.
7. The opt-in trace at `38902cb` held at `permission_count=0` for the post-Enable
   trace, then later failed with `ax-exercise-action-ax-index-incomplete` and
   `permission_count=2`. This indicates a delayed dynamic AX transition, not a
   simple package-resource omission.
8. The phase-separated run at `b69a3d5` emitted only `capture=pass` and
   `enable=pressed` before exiting nonzero; its close/select phase result still
   needs to be captured directly.

No green packaged journey, aggregate proof, fresh-clone proof, release proof,
or Goal 50 evidence packet exists yet.

## Remaining actions

1. Resume only from the Goal 50 worktree, with no concurrent Swift build or GUI
   process:

   ```zsh
   cd /private/tmp/cam-add2cam-20260731/packaged-pilot
   git status --short --branch
   /bin/zsh Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh
   ```

2. Capture the phase-separated result exactly. The required state sequence is:
   `disabled/no state` -> `enabled/permission_count=0` -> sheet closed with
   `permission_count=0` -> workspace selected with `permission_count=0` -> one
   explicit Grant -> `permission_count=2`.

3. If a delayed AX event still grants access before the explicit Grant phase,
   fix the native lifecycle-control identity/action boundary with a failing
   regression first. Do not solve it by deleting the zero-permission assertion,
   broadening permissions, using a compile-time fallback, or relabeling the
   delayed action as user intent. A relaunch between phases may be used only as
   a diagnostic comparison, not as the final proof of a broken transition.

4. After the packaged journey is green, run serially on the exact terminal
   commit: focused app/core tests, `scripts/verify.sh meaning-preview`, the
   packaged journey, release/privacy and identity scans, package reproducibility,
   `scripts/verify.sh all`, fresh-clone verification, and `git diff --check`.

5. Create and verify the required Goal 50 artifacts:

   - `docs/evidence/add2cam-10-packaged-pilot.md`
   - `docs/pilots/meaning-preview-v1-protocol.md` labeled
     `Draft - approval and participants required`
   - `docs/evidence/add2cam-11-final-containment.md`
   - `docs/handoffs/add2cam/20260731/50_PACKAGED_PILOT.md`

6. Cherry-pick only the accepted Goal 50 commits into the canonical integration
   branch. Then update `PROGRESS.md`, `DECISIONS.md`, `TASK_QUEUE.md`,
   `goals/add2cam/run-state.json`, and the handoff README with exact terminal
   hashes and evidence paths. Preserve `ADD2CAM-60` as pending human evidence.

## Safety boundaries

- No production Application Support state, personal data, donor repository, or
  MeaningCore checkout was modified.
- The harness's `chmod 000` containment applies only to disposable clone
  `.swift-build` and `Modules/Core` paths; the canonical checkout remained
  untouched and was left at normal directory permissions.
- The packaged socket check is point-in-time evidence only; final documentation
  must not claim continuous zero-egress monitoring from it.
- Synthetic packaged evidence is not participant consent, lived-use evidence,
  model-quality proof, or a promotion decision.

## Recovery stop rule

If the same transition failure remains after the next bounded implementation
attempt and one clean rerun, preserve the red output and stop for a design
decision. Do not weaken the explicit permission boundary or advance to the
human-pilot gate.
