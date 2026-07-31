# ADD2CAM 2026-07-31 Handoffs

This directory is the durable handoff surface for the isolated Meaning Preview build. The integration owner accepts worker output only when the handoff and commit satisfy the owning goal contract.

Required worker handoffs:

- `10_CORE_PRACTICAL.md`
- `20_NATIVE_UX.md`
- `21_FEEDBACK_AUDIT.md`
- `30_REFLECTIVE_EVALUATION.md`
- `40_REFLECTIVE_LANE.md`
- `50_PACKAGED_PILOT.md`

Each handoff records prerequisite commit, branch/worktree, implementation commits, exact changed files, observed red proof, green commands/results, evidence paths, assumptions/decisions, protected-boundary confirmation, limitations/failed experiments, integration order, final Git status, and exactly one terminal status: `verified_success`, `verified_partial`, `blocked`, `unsafe`, or `invalidated`.

The accepted integration branch is `agent/add2cam-integration-20260731`. Chat-only completion claims are not accepted. Goal 60 requires real human evidence and has no autonomous worker handoff.
