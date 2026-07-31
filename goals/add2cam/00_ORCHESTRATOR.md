# ADD2CAM Orchestrator

## GOAL ID

`ADD2CAM-00`

## ROLE

Own the accepted integration branch, dispatch bounded workers, review and integrate their commits, serialize aggregate verification, and maintain repository truth.

## PREREQUISITE COMMIT

`7e4bc1de9378206a102f3334bb292aa21ff2b9a6`

## BRANCH / WORKTREE

Branch `agent/add2cam-integration-20260731`; canonical worktree `/Volumes/WS4TB/waswiki/CAM_Assistant`.

## DEPENDENCIES

The approved design and execution plan under `docs/plans/`; the pinned MeaningCore revision; the repository source-of-truth files.

## OUTCOME

Advance Goals 10 through 50 to verified terminal states and stop at `READY_FOR_HUMAN_PILOT`. Goal 60 remains a human gate.

## PROOF OF DONE

- Every accepted worker starts from the recorded prerequisite commit and edits only owned files.
- Every accepted commit has a durable handoff, focused green tests, review classification, and post-integration regression proof.
- Packaged, aggregate, and fresh-clone proof are serialized and recorded.
- CAM and MeaningCore identities and clean states are refreshed at the terminal boundary.
- Repository truth says `READY_FOR_HUMAN_PILOT`, not complete.

## OWNED FILES

`GOAL*.md`, `STANDARDS.md`, `IMPLEMENT.md`, `DECISIONS.md`, `PROGRESS.md`, `TASK_QUEUE.md`, `goals/add2cam/run-state.json`, integration-only evidence summaries, and the final gate map.

## PROTECTED FILES

MeaningCore and all donor repositories; personal vaults; live CAM corpora; worker-owned implementation files while their worker is active.

## SAFETY / PROVENANCE

No secrets, PHI, credentials, raw personal context, or private keys enter prompts, logs, fixtures, commits, or handoffs. MeaningCore remains pinned and read-only. Synthetic fixtures are never described as lived-use evidence.

## AUTONOMOUS DECISION POLICY

Make the smallest reversible choice consistent with the controlling goals and document it. Reject out-of-allowlist changes. Retry a failed worker at most twice after a bounded diagnosis. Escalate only the stop conditions below.

## CONSTRAINTS

One integrator, at most three writing workers, at most two concurrent Swift compilations, separate worktrees and caches, test-driven changes, serialized cherry-picks and aggregate verification.

## ITERATION

Dispatch only ready goals; require red proof, minimal green implementation, focused tests, spec review, quality/boundary review, then integration. Re-run affected tests after every accepted commit.

## HANDOFF

Maintain `docs/handoffs/add2cam/20260731/README.md` and one immutable worker handoff per goal with commits, changed files, red/green commands, evidence, assumptions, boundaries, limitations, and terminal status.

## RETRY / RECOVERY

On worker stall, interrupt once, retry with a smaller prompt or a fresh worktree, then recover locally or mark blocked. On conflict, reject the integration attempt and regenerate from the latest accepted SHA. Never weaken a test or safety gate to recover.

## STOP

Stop for destructive actions, missing credentials/accounts, production deployment, sensitive-data risk, legal uncertainty, material scope change, or repeated failure after bounded mitigation. Always stop at `READY_FOR_HUMAN_PILOT` pending Goal 60.

## COMPLETE

Complete when Goals 10-50 are accepted or truthfully terminal, all required automated proof passes, the branch is clean, and the human boundary is preserved.
