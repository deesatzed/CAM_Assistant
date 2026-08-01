# ADD2CAM Packaged Pilot

## GOAL ID

`ADD2CAM-50`

## ROLE

Prove the isolated Meaning Preview journey in the packaged native app, run aggregate/fresh-clone verification, and prepare a draft human-pilot packet.

## PREREQUISITE COMMIT

Assigned by the orchestrator to the exact integration commit containing terminal Goal 40 and all accepted prior goals.

## BRANCH / WORKTREE

Branch `agent/add2cam-50-packaged-pilot`; worktree `/private/tmp/cam-add2cam-20260731/packaged-pilot`.

## DEPENDENCIES

Accepted Goals 10, 20, 21, 30 and terminal Goal 40.

## OUTCOME

A clean-source package passes a disposable synthetic opt-in/grant/use/action/disable/restart journey, focused verification, aggregate verification, and fresh-clone proof; a draft human protocol and containment report are ready.

## PROOF OF DONE

The packaged journey, `scripts/verify.sh meaning-preview`, `scripts/verify.sh all`, release identity/secret scans, and `git diff --check` pass serially; protocol is labeled draft; containment identities and limitations are recorded.

## OWNED FILES

`Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh`; `scripts/package-app.sh`; `scripts/verify.sh`; `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`; `docs/evidence/add2cam-10-packaged-pilot.md`; `docs/pilots/meaning-preview-v1-protocol.md`; `docs/evidence/add2cam-11-final-containment.md`; `docs/handoffs/add2cam/20260731/50_PACKAGED_PILOT.md`.

## PROTECTED FILES

Repository truth until integrator acceptance; frozen evaluation/model evidence; production Application Support; personal/live data; MeaningCore and donors.

## SAFETY / PROVENANCE

All packaged proof uses an explicit disposable application-support root and synthetic context. No production bypass, live data, fabricated participant, or synthetic-to-human evidence substitution.

## AUTONOMOUS DECISION POLICY

Repair packaging/test harness defects within owned files. Preserve genuine failures and limitations. Do not approve the human protocol or recruit/impersonate participants.

## CONSTRAINTS

Run aggregate/package/GUI-sensitive proof serially with no concurrent Swift builds. Native permission escalation must be narrow and disposable. Protocol status remains `Draft - approval and participants required`. The package must embed the Meaning Preview manifest and the SwiftPM core resource bundle; neither runtime nor proof may fall back to compile-time source/build paths. AX automation uses stable accessibility identifiers and the existing `open -n APP --env CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT=...` launch boundary only.

## ITERATION

Observe packaged journey failure, implement the smallest harness/product correction authorized by dispatch, run focused then packaged then aggregate/fresh-clone proof, and confirm clean diffs.

## HANDOFF

Record package path and identity, exact commands/results, disposable roots, evidence paths, limitations, draft protocol, and terminal status in `50_PACKAGED_PILOT.md`.

## RETRY / RECOVERY

Classify sandbox-only failures separately and retry narrowly in an approved native environment. Retry product failures twice after diagnosis; never bypass a failed gate.

## STOP

Stop for production deployment, signing/notarization decisions, destructive state handling, live/personal data, human participation, or repeated failure.

## COMPLETE

Complete when automated software proof is green, artifacts are durable, boundaries are clean, and the orchestrator can truthfully declare `READY_FOR_HUMAN_PILOT`.
