# ADD2CAM Parallel-Agent Orchestration Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Autonomously complete the remaining `GOAL_ADD2CAM.md` software through a packaged, verified `READY_FOR_HUMAN_PILOT` state using isolated workers and one evidence-gated integrator.

**Architecture:** The integration branch owns repository truth and accepted commits. Bounded workers run from exact accepted SHAs in separate worktrees, edit disjoint allowlists, and return committed handoffs. The integrator validates ownership, reviews, cherry-picks, runs regressions, and dispatches only newly unblocked goals.

**Tech Stack:** Swift 6.2/6.3, SwiftUI, Swift Testing, SQLite3, Swift Package Manager, MeaningCore at `23db68044ebdc410edf3b7f436e433ffba6e94b8`, Git worktrees, Codex subagents, repository verification scripts.

---

## Execution Rules

- Governing design:
  `docs/plans/2026-07-31-add2cam-parallel-agent-orchestration-design.md`.
- Feature-level TDD steps:
  `docs/plans/2026-07-29-meaningcore-human-pilot.md`.
- Start from integration commit `74ff926` and record every later accepted SHA.
- Use one integrator and no more than three concurrent workers.
- Run no more than two Swift compilations concurrently.
- Workers never update repository truth, controlling goals, the final gate map,
  or another worker's handoff.
- MeaningCore, donors, personal vaults, and live CAM corpora remain read-only.
- No worker may claim overall `GOAL_ADD2CAM.md` completion.
- The autonomous terminal state is `READY_FOR_HUMAN_PILOT`; Task 11 remains a
  real human evidence gate.

### Task 1: Create The Durable Goal Family And Queue

**Files:**

- Create: `goals/add2cam/00_ORCHESTRATOR.md`
- Create: `goals/add2cam/10_CORE_PRACTICAL.md`
- Create: `goals/add2cam/20_NATIVE_UX.md`
- Create: `goals/add2cam/21_FEEDBACK_AUDIT.md`
- Create: `goals/add2cam/30_REFLECTIVE_EVALUATION.md`
- Create: `goals/add2cam/40_REFLECTIVE_LANE.md`
- Create: `goals/add2cam/50_PACKAGED_PILOT.md`
- Create: `goals/add2cam/60_HUMAN_EVIDENCE.md`
- Create: `goals/add2cam/run-state.json`
- Create: `docs/handoffs/add2cam/20260731/README.md`
- Modify: `TASK_QUEUE.md`
- Modify: `PROGRESS.md`

**Step 1: Write structural expectations**

Create the goal files with these required headings:

```text
GOAL ID
ROLE
PREREQUISITE COMMIT
BRANCH / WORKTREE
DEPENDENCIES
OUTCOME
PROOF OF DONE
OWNED FILES
PROTECTED FILES
SAFETY / PROVENANCE
AUTONOMOUS DECISION POLICY
CONSTRAINTS
ITERATION
HANDOFF
RETRY / RECOVERY
STOP
COMPLETE
```

The queue must contain one entry per goal with `id`, `status`, `dependencies`,
`prerequisiteCommit`, `branch`, `worktree`, `attempts`, `terminalCommit`,
`handoff`, `evidence`, and `blockers`.

**Step 2: Validate the contracts**

Run:

```zsh
for goal in goals/add2cam/*.md; do
  for heading in "GOAL ID" ROLE "PREREQUISITE COMMIT" DEPENDENCIES OUTCOME \
    "PROOF OF DONE" "OWNED FILES" "PROTECTED FILES" \
    "AUTONOMOUS DECISION POLICY" ITERATION HANDOFF STOP COMPLETE; do
    rg -q "^## ${heading}$" "$goal" || exit 1
  done
done
jq -e '.schemaVersion == 1 and (.goals | length == 8)' \
  goals/add2cam/run-state.json
git diff --check
```

Expected: every command exits `0`.

**Step 3: Record truthful bootstrap status**

Update `TASK_QUEUE.md` and `PROGRESS.md` to distinguish implemented Tasks 1–4,
the partial Gate 2–4 proof, and pending Goal 10. Do not mark any new feature
gate complete.

**Step 4: Commit**

```zsh
git add goals/add2cam docs/handoffs/add2cam/20260731/README.md \
  TASK_QUEUE.md PROGRESS.md
git commit -m "Add autonomous ADD2CAM worker goals"
```

### Task 2: Execute Goal 10 Core Practical

**Files:**

- Modify: `Sources/CAMAssistantCore/Meaning/MeaningPreviewModels.swift`
- Modify: `Sources/CAMAssistantCore/Meaning/CAMMeaningContextAdapter.swift`
- Modify: `Sources/CAMAssistantCore/Meaning/MeaningPreviewStore.swift`
- Create: `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`
- Create: `Tests/CAMAssistantCoreTests/MeaningPreviewCoordinatorTests.swift`
- Create: `Tests/Fixtures/MeaningPreview/v1/practical-scenarios.json`
- Create: `docs/handoffs/add2cam/20260731/10_CORE_PRACTICAL.md`

**Step 1: Dispatch from the accepted Task 1 commit**

Create branch/worktree `agent/add2cam-10-core-practical` from the exact
integration SHA. Give the worker only `10_CORE_PRACTICAL.md` and relevant
repository truth.

**Step 2: Observe the required red proof**

Implement the failing cases from the existing plan, Task 5:

- disabled/ungranted refusal before context reads;
- empty projection silence;
- zero-or-one practical result;
- depleted-capacity suppression with imminent-commitment exception;
- typed `Now`, `Later`, and `Release` isolated changes;
- no implicit helpful outcome;
- correction, expiry, rejection, restart, deterministic replay;
- stale-version refusal and actor serialization.

Run:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewCoordinatorTests
```

Expected: compile or assertion failure before implementation.

**Step 3: Implement minimally and verify**

The coordinator must invoke MeaningCore deterministic policies only. It must
not invoke models, CAM, web, cloud, notifications, or actions.

Run:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewCoordinatorTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter StorageTests
git diff --check
```

Expected: all pass.

**Step 4: Integrator acceptance**

Verify owned files, review the patch, run focused tests, run a boundary/test-gap
review, classify recommendations, and cherry-pick only accepted commits.
Update queue/truth only after the accepted integration SHA is green.

### Task 3: Dispatch Wave 2 In Parallel

**Workers:**

- Goal 20: native UX;
- Goal 21: feedback/audit;
- Goal 30: frozen reflective evaluation.

**Step 1: Create all three branches from the same Goal 10 integration SHA**

Each worker receives a distinct worktree, branch, Swift cache, goal file, and
owned test file.

**Step 2: Goal 20 red/green proof**

Follow the existing plan Task 6. Prove disabled absence, explicit reveal,
permission refusal, zero/one card, Inspect evidence, independent actions,
accessibility, reduced motion, recovery states, and disable return to ordinary
CAM.

Run:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewAppModelTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter AccessibilityViewContractTests
```

**Step 3: Goal 21 red/green proof**

Follow the existing plan Task 7. Prove explicit helpfulness, non-inference from
actions, correction propagation, retirement, status-only audit, no raw
sensitive content, proposal-only external possibilities, and zero outbound
restricted payload.

Run:

```zsh
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewBoundaryTests
/bin/zsh scripts/verify.sh privacy
```

**Step 4: Goal 30 red/green proof and freeze**

Follow the existing plan Task 8. Create the fixture before any named-model run,
validate every case and prohibited behavior offline, add the CLI evaluator, and
record the exact SHA-256.

Run:

```zsh
/bin/zsh scripts/verify.sh meaning-preview
shasum -a 256 Tests/Fixtures/MeaningPreview/v1/manifest.json
```

**Step 5: Integrate serially**

Accept Goal 21, then Goal 30, then Goal 20 unless review evidence requires a
different conflict-free order. Run affected focused suites after each
cherry-pick and the full Wave 2 focused surface afterward.

### Task 4: Execute Goal 40 Reflective Lane

**Files:**

- Create: `Sources/CAMAssistantCore/Meaning/MeaningPreviewCandidateSupplier.swift`
- Modify: `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`
- Modify: `Sources/CAMAssistantApp/Views/MeaningPreviewView.swift`
- Create: `Tests/CAMAssistantCoreTests/MeaningPreviewReflectionTests.swift`
- Modify: `Tests/CAMAssistantAppTests/MeaningPreviewAppModelTests.swift`
- Create: `docs/evidence/add2cam-09-named-model-report.json`
- Create: `docs/handoffs/add2cam/20260731/40_REFLECTIVE_LANE.md`

**Step 1: Dispatch only from the integrated Wave 2 SHA**

No other writing worker may touch the coordinator or Preview view concurrently.

**Step 2: Observe red and implement the explicit lane**

Follow existing plan Task 9. Require explicit request, selected loopback model,
current bounded context, structured output, MeaningCore validation, abstention,
no fallback, and ephemeral generation.

**Step 3: Run the frozen named-model gate**

```zsh
/bin/zsh scripts/verify.sh meaning-preview
swift run --disable-sandbox --scratch-path .swift-build cam-assistant \
  evaluate-meaning-preview Tests/Fixtures/MeaningPreview/v1/manifest.json \
  docs/evidence/add2cam-09-named-model-report.json
```

If thresholds fail, preserve the report, keep reflection disabled, return
`verified_partial`, and continue only practical pilot work permitted by the
controlling goal.

**Step 4: Integrate and verify**

Run core, app, privacy, and evaluation suites before accepting the result.

### Task 5: Execute Goal 50 Packaged Pilot

**Files:**

- Create: `Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh`
- Modify: `scripts/verify.sh`
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- Create: `docs/evidence/add2cam-10-packaged-pilot.md`
- Create: `docs/pilots/meaning-preview-v1-protocol.md`
- Create: `docs/evidence/add2cam-11-final-containment.md`
- Create: `docs/handoffs/add2cam/20260731/50_PACKAGED_PILOT.md`

**Step 1: Write and observe the failing packaged journey**

Follow existing plan Task 10 against an isolated application-support root and
synthetic context. Do not add production bypasses.

**Step 2: Verify focused, packaged, aggregate, and fresh-clone proof**

Run serially with no other worker builds active:

```zsh
/bin/zsh Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh
/bin/zsh scripts/verify.sh meaning-preview
/bin/zsh scripts/verify.sh all
git diff --check
```

Repeat only sandbox-limited native GUI/FSEvents/hotkey checks from an approved
native environment against disposable state.

**Step 3: Draft but do not approve human protocol**

Write consent, sufficiency, duration, context, withdrawal, receipt handling,
questions, stopping, invalid-session, and report contracts before any human
observation. Label the protocol `Draft - approval and participants required`.

**Step 4: Integrate and record `READY_FOR_HUMAN_PILOT`**

The integrator refreshes CAM and MeaningCore identities, verification receipts,
limitations, queue state, and repository truth. It must leave Gates 9–10 and
overall `GOAL_ADD2CAM.md` completion pending.

### Task 6: Preserve The Human Evidence Boundary

**Files:**

- Read: `goals/add2cam/60_HUMAN_EVIDENCE.md`
- Future modify: `docs/pilots/meaning-preview-v1-protocol.md`
- Future create: `docs/pilots/meaning-preview-v1-report.md`
- Future modify: `DECISIONS.md`, `PROGRESS.md`, `TASK_QUEUE.md`

**Step 1: Stop autonomous execution at the correct boundary**

Return one consolidated status containing the packaged build path, exact
commit, commands, limitations, protocol draft, and minimum human action needed.

**Step 2: Do not fabricate completion**

No synthetic agent, model judge, automated UI test, or developer self-report
may be relabeled as participant consent, lived-use evidence, or a promotion
decision.

## Final Handoff

Plan execution is complete only when the integration branch is clean, every
accepted software goal has a durable handoff, aggregate/fresh-clone/package
proof passes, MeaningCore is unchanged, and repository truth reports
`READY_FOR_HUMAN_PILOT` rather than complete.

