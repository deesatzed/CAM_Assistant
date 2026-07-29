# MeaningCore Human Pilot Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a reversible, opt-in Meaning Preview to CAM Assistant, validate deterministic practical utility first, then admit bounded local-model reflection only after a frozen evaluation passes, and gather human-use evidence without changing default CAM behavior.

**Architecture:** CAM pins MeaningCore as a library and owns all adapters, persistence, permissions, UI, and audit. The pilot uses a separate SQLite store and an actor coordinator; CAM projects explicitly selected permitted context into MeaningCore and receives zero-or-one Ambient/Glance/Inspect output. Reflection is a later, explicit, loopback-only lane behind a named-model evaluation gate.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing, SQLite3, Swift Package Manager, MeaningCore at `23db68044ebdc410edf3b7f436e433ffba6e94b8`, CAM module registry, existing local-model and privacy boundaries.

---

## Execution Rules

- Run every task test-first and observe the expected failure.
- Refresh Git status before every edit; preserve concurrent work.
- Commit only files owned by the current task.
- Do not edit `/Volumes/WS4TB/me-ning/MeaningCore`.
- Do not run against a live personal vault or CAM corpus.
- Do not enable reflection, notifications, or default-chat influence early.
- Update `PROGRESS.md`, `DECISIONS.md`, `TASK_QUEUE.md`, and evidence only after
  the corresponding behavior is verified.

### Task 1: Refresh Baselines And Pin MeaningCore

**Files:**

- Modify: `Package.swift`
- Create: `Package.resolved`
- Create: `Tests/CAMAssistantCoreTests/MeaningCoreDependencyTests.swift`
- Create: `docs/evidence/add2cam-01-dependency.md`

**Step 1: Verify clean ownership boundaries**

Run:

```bash
git status --short --branch
git rev-parse HEAD
git -C /Volumes/WS4TB/me-ning/MeaningCore status --short --branch
git -C /Volumes/WS4TB/me-ning/MeaningCore rev-parse HEAD
git ls-remote https://github.com/deesatzed/meaningcore.git refs/heads/main
```

Expected: CAM state is recorded; MeaningCore is clean at the approved revision;
remote `main` resolves to the same revision. Stop on an overlapping dirty CAM
change or MeaningCore drift.

**Step 2: Write the failing dependency test**

Add a test that imports MeaningCore and proves the expected revision surface:

```swift
import MeaningCore
import Testing

@Test("pinned MeaningCore exposes the verified pilot contracts")
func pinnedMeaningCoreContractsAreAvailable() {
    #expect(ScenarioSuite.verify())
    #expect(FamiliarityTracker().stage(for: "pilot") == .usefulStranger)
    #expect(GlanceProjection(item: nil).actions.isEmpty)
}
```

**Step 3: Run the test to verify it fails**

Run:

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningCoreDependencyTests
```

Expected: compile failure because CAM has no MeaningCore dependency.

**Step 4: Pin the package**

Add the exact MeaningCore Git dependency to `Package.swift`, add MeaningCore to
`CAMAssistantCore` and its tests, and resolve `Package.resolved`. Depend on the
library product only.

**Step 5: Verify compatibility**

Run:

```bash
swift package resolve
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningCoreDependencyTests
swift build --disable-sandbox --scratch-path .swift-build -c release
```

Expected: dependency test and release build pass.

**Step 6: Save evidence and commit**

Record exact repositories, revisions, license status, commands, results,
offline-runtime limitation, and rollback.

```bash
git add Package.swift Package.resolved \
  Tests/CAMAssistantCoreTests/MeaningCoreDependencyTests.swift \
  docs/evidence/add2cam-01-dependency.md
git commit -m "Pin MeaningCore pilot dependency"
```

### Task 2: Add An Opt-In Native Module Contract

**Files:**

- Create: `Modules/Core/meaning-preview.json`
- Modify: `Tests/CAMAssistantCoreTests/ModuleRegistryTests.swift`
- Create: `docs/evidence/add2cam-02-module-boundary.md`

**Step 1: Write failing manifest expectations**

Extend the manifest set expectation with `cam.meaning-preview`, then assert:

```swift
let preview = try #require(
    manifests.first { $0.id == "cam.meaning-preview" }
)
#expect(!preview.isCore)
#expect(preview.transport == .native)
#expect(preview.requirements.web == false)
#expect(preview.requirements.cloud == false)
```

Add a registry test proving discovery and enablement expose no capabilities
before explicit permission grant.

**Step 2: Run the focused test**

Run:

```bash
/bin/zsh scripts/verify.sh modules
```

Expected: failure because the manifest is absent.

**Step 3: Add the minimal manifest**

Create a non-core, local-only native manifest with separately declared
`readLocal` and `writeLocal` permissions, no model role, no spend, exact
provenance, isolated rollback text, and one
`meaning.preview.request` capability.

**Step 4: Verify enable/disable behavior**

Run:

```bash
/bin/zsh scripts/verify.sh modules
```

Expected: manifest and registry tests pass; discovery/enablement grant no
permission.

**Step 5: Commit**

```bash
git add Modules/Core/meaning-preview.json \
  Tests/CAMAssistantCoreTests/ModuleRegistryTests.swift \
  docs/evidence/add2cam-02-module-boundary.md
git commit -m "Add opt-in Meaning Preview module"
```

### Task 3: Define CAM-Owned Adapter Types

**Files:**

- Create: `Sources/CAMAssistantCore/Meaning/MeaningPreviewModels.swift`
- Create: `Sources/CAMAssistantCore/Meaning/CAMMeaningContextAdapter.swift`
- Create: `Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift`

**Step 1: Write failing mapping tests**

Cover:

- active selected derived text maps to typed MeaningCore memory;
- source ID, observation date, sensitivity, permitted use, and citation
  provenance remain available;
- hidden, missing, restricted, secret-like, stale, and unsupported selections
  are excluded;
- an empty or wholly excluded selection produces no invented memory;
- ordering is deterministic.

Use an input contract shaped like:

```swift
public struct MeaningContextSelection: Sendable, Equatable {
    public let purpose: String
    public let domain: String
    public let capacity: MeaningCore.Capacity
    public let selectedItems: [MeaningContextItem]
}
```

**Step 2: Run the focused test**

Run:

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
```

Expected: compile failure because the adapter types do not exist.

**Step 3: Implement the minimal adapter**

Create pure value types and a stateless mapper. Do not read SQLite, invoke a
model, save state, or construct a CAM `ContextBundle` in the mapper.

The mapper returns:

```swift
public struct MeaningContextProjection: Sendable, Equatable {
    public let context: MeaningCore.WorkingContext
    public let memory: [MeaningCore.MemoryItem]
    public let exclusions: [String: MeaningContextExclusion]
}
```

**Step 4: Verify and commit**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
git diff --check
git add Sources/CAMAssistantCore/Meaning/MeaningPreviewModels.swift \
  Sources/CAMAssistantCore/Meaning/CAMMeaningContextAdapter.swift \
  Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift
git commit -m "Add MeaningCore context adapter contracts"
```

### Task 4: Build The Isolated Pilot Store

**Files:**

- Create: `Sources/CAMAssistantCore/Meaning/MeaningPreviewStore.swift`
- Modify: `Sources/CAMAssistantCore/Storage/LocalVaultPaths.swift`
- Modify: `Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift`
- Create: `docs/evidence/add2cam-04-isolated-store.md`

**Step 1: Write failing storage tests**

Use temporary application-support roots and prove:

- the pilot URL is not CAM's primary SQLite URL;
- creating pilot state does not change primary database bytes;
- save/reload preserves `CoreState`, selected-source provenance, and feedback;
- unsupported schema, malformed bytes, and duplicate IDs fail closed;
- archive/reinitialize moves only the pilot file;
- disable/restart preserves CAM data and does not load pilot decisions;
- no raw source text or synthetic credential fixture appears in stored bytes.

**Step 2: Run the focused tests**

Run:

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
```

Expected: compile failure because the store is absent.

**Step 3: Implement schema v1**

Create a separate `MeaningPreview.sqlite` database under the redirected/local
application-support root. Store:

- encoded MeaningCore state;
- adapter schema and MeaningCore revision;
- selected CAM source identifiers and bounded provenance;
- local feedback and decision receipts;
- no immutable source bytes.

Serialize all store access and use atomic SQLite transactions.

**Step 4: Verify storage and primary-database containment**

Run:

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter StorageTests
```

Expected: Meaning Preview and existing storage tests pass.

**Step 5: Commit**

```bash
git add Sources/CAMAssistantCore/Meaning/MeaningPreviewStore.swift \
  Sources/CAMAssistantCore/Storage/LocalVaultPaths.swift \
  Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift \
  docs/evidence/add2cam-04-isolated-store.md
git commit -m "Add isolated Meaning Preview storage"
```

### Task 5: Add The Actor Coordinator And Practical Lane

**Files:**

- Create: `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`
- Modify: `Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift`
- Create: `Tests/Fixtures/MeaningPreview/v1/practical-scenarios.json`

**Step 1: Write failing coordinator tests**

Prove:

- disabled coordinator refuses requests without reading context;
- enabled but ungranted coordinator refuses selected data;
- an empty projection returns silence;
- selected relevant memory returns at most one practical item;
- depleted capacity suppresses ordinary items and preserves only the
  MeaningCore imminent-commitment exception;
- `Now`, `Later`, and `Release` update only isolated pilot state;
- `Now` does not record a helpful utility outcome;
- correction, expiry, restart, and deterministic replay pass;
- coordinator serialization prevents stale-version writes.

**Step 2: Run the focused test and observe failure**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
```

Expected: compile failure because the coordinator is absent.

**Step 3: Implement practical-only coordination**

Use an actor with injected:

```swift
public protocol MeaningPreviewStateStoring: Sendable {
    func load() throws -> MeaningPreviewSnapshot
    func save(_ snapshot: MeaningPreviewSnapshot) throws
}
```

The actor invokes `UtilitySpine` and `HostProjections`; it does not invoke
local inference, CAM, web, cloud, notifications, or actions.

**Step 4: Verify and commit**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
git diff --check
git add Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift \
  Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift \
  Tests/Fixtures/MeaningPreview/v1/practical-scenarios.json
git commit -m "Add practical Meaning Preview coordinator"
```

### Task 6: Add The Opt-In Native Workspace

**Files:**

- Create: `Sources/CAMAssistantApp/Views/MeaningPreviewView.swift`
- Create: `Sources/CAMAssistantApp/Views/MeaningInspectView.swift`
- Create: `Sources/CAMAssistantApp/Views/MeaningPreviewSettingsView.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Modify: `Sources/CAMAssistantApp/Views/Sidebar.swift`
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- Create: `Tests/CAMAssistantAppTests/MeaningPreviewAppModelTests.swift`

**Step 1: Write failing app and accessibility tests**

Prove:

- Meaning Preview is absent while disabled;
- explicit enablement reveals a clearly labeled Preview workspace;
- enablement grants no permission;
- request remains unavailable until local-read permission and explicit source
  selection exist;
- zero and one-card states render;
- Inspect exposes evidence/provenance/uncertainty/why-surfaced, not raw
  reasoning;
- `Now`, `Later`, `Release`, `Helpful`, `Not helpful`, and Disable have
  independent accessibility actions;
- initial focus, keyboard order, VoiceOver labels, empty/error states, and no
  app-authored motion pass;
- disabling returns selection to ordinary Assistant and stops pilot calls.

**Step 2: Run the tests to observe failure**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewAppModelTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter AccessibilityViewContractTests
```

Expected: compile or expectation failure because the UI is absent.

**Step 3: Implement the minimal user-pull workspace**

Add an optional section derived from module state rather than unconditionally
adding it to `AssistantSection.allCases`. The preview must not start work on
launch and must expose no notification or background timer.

**Step 4: Verify and commit**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewAppModelTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter AccessibilityViewContractTests
git diff --check
git add Sources/CAMAssistantApp/Views/MeaningPreviewView.swift \
  Sources/CAMAssistantApp/Views/MeaningInspectView.swift \
  Sources/CAMAssistantApp/Views/MeaningPreviewSettingsView.swift \
  Sources/CAMAssistantApp/AppModel.swift \
  Sources/CAMAssistantApp/Views/AssistantWindow.swift \
  Sources/CAMAssistantApp/Views/Sidebar.swift \
  Tests/CAMAssistantAppTests/MeaningPreviewAppModelTests.swift \
  Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift
git commit -m "Add opt-in Meaning Preview workspace"
```

### Task 7: Add Explicit Feedback, Audit, And Proposal Boundaries

**Files:**

- Create: `Sources/CAMAssistantCore/Meaning/MeaningPreviewAuditSink.swift`
- Create: `Sources/CAMAssistantCore/Meaning/MeaningActionProposalAdapter.swift`
- Modify: `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`
- Modify: `Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift`
- Modify: `Tests/CAMAssistantCoreTests/AuditTests.swift`
- Modify: `Tests/CAMAssistantCoreTests/PrivacyTests.swift`

**Step 1: Write failing boundary tests**

Prove:

- only explicit `.helpful` advances domain familiarity;
- non-helpful, selection, Keep, `Now`, `Later`, and `Release` do not;
- rejected suggestions retire or lower pilot confidence;
- audit receipts omit source text, secret fixtures, and raw model output;
- corrections invalidate downstream pilot projections;
- an external or mutating possibility returns a proposal with no executor;
- restricted context produces zero outbound bytes and no proposal payload.

**Step 2: Run focused tests**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
/bin/zsh scripts/verify.sh privacy
```

Expected: failure because audit and proposal adapters are absent.

**Step 3: Implement minimal adapters**

Map MeaningCore use provenance to bounded CAM audit status fields. Convert host
action requests into proposal values; do not use `ApprovalStore` to execute
anything.

**Step 4: Verify and commit**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
/bin/zsh scripts/verify.sh privacy
git add Sources/CAMAssistantCore/Meaning/MeaningPreviewAuditSink.swift \
  Sources/CAMAssistantCore/Meaning/MeaningActionProposalAdapter.swift \
  Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift \
  Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift \
  Tests/CAMAssistantCoreTests/AuditTests.swift \
  Tests/CAMAssistantCoreTests/PrivacyTests.swift
git commit -m "Bound Meaning Preview feedback and audit"
```

### Task 8: Create And Freeze The Reflective Evaluation

**Files:**

- Create: `Tests/Fixtures/MeaningPreview/v1/manifest.json`
- Create: `Tests/Fixtures/MeaningPreview/v1/README.md`
- Create: `Sources/CAMAssistantCore/Meaning/MeaningPreviewEvaluation.swift`
- Modify: `Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift`
- Modify: `Sources/CAMAssistantCLI/main.swift`
- Modify: `scripts/verify.sh`
- Create: `docs/evidence/add2cam-08-reflective-evaluation.md`

**Step 1: Define the frozen corpus before model observation**

Include at minimum:

- appreciation without homework;
- service without performance or moral score;
- receiving without debt;
- capacity tending without productivity optimization;
- release without abandonment;
- contentment without forced happiness;
- sharing with consent;
- procrastination versus depletion, ambiguity, danger, duty, and misalignment;
- unsupported moral, diagnostic, ideal-self, destiny, and motive claims;
- silence, abstention, correction, and wrong timing;
- pressure and faux-self-help adversarial cases.

Every case records evidence, counterevidence, expected decision, forbidden
behavior, and why silence/intervention is correct.

**Step 2: Write failing evaluator tests**

Require exact manifest hash, schema validation, complete case fields,
deterministic policy replay, candidate support/counterevidence, abstention, and
zero prohibited-language findings.

**Step 3: Run tests to observe failure**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
```

Expected: failure because evaluator and fixture are absent.

**Step 4: Implement evaluator and CLI**

Add `cam-assistant evaluate-meaning-preview` and a
`scripts/verify.sh meaning-preview` suite. Keep model execution injected and
optional; deterministic fixture validation must run offline.

**Step 5: Freeze and commit before any named-model run**

```bash
/bin/zsh scripts/verify.sh meaning-preview
shasum -a 256 Tests/Fixtures/MeaningPreview/v1/manifest.json
git add Tests/Fixtures/MeaningPreview/v1 \
  Sources/CAMAssistantCore/Meaning/MeaningPreviewEvaluation.swift \
  Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift \
  Sources/CAMAssistantCLI/main.swift scripts/verify.sh \
  docs/evidence/add2cam-08-reflective-evaluation.md
git commit -m "Freeze Meaning Preview evaluation"
```

### Task 9: Add The Explicit Local Reflective Lane

**Files:**

- Create: `Sources/CAMAssistantCore/Meaning/MeaningPreviewCandidateSupplier.swift`
- Modify: `Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift`
- Modify: `Sources/CAMAssistantApp/Views/MeaningPreviewView.swift`
- Modify: `Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift`
- Modify: `Tests/CAMAssistantAppTests/MeaningPreviewAppModelTests.swift`
- Create: `docs/evidence/add2cam-09-named-model-report.json`

**Step 1: Write failing supplier tests**

Prove:

- reflection requires a separate explicit action;
- only the selected loopback model is called;
- current selected context is the complete model context;
- structured output distinguishes observation and interpretation and includes
  support, counterevidence, uncertainty, and domain;
- unsupported or prohibited candidates fail MeaningCore validation;
- abstention and endpoint failure produce silence/direct error;
- no cloud, web, CAM, alternate model, retry, or fallback occurs;
- generated output remains ephemeral unless explicitly kept.

**Step 2: Run focused tests**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
```

Expected: compile failure because the supplier is absent.

**Step 3: Implement against existing local-model contracts**

Inject the existing selected local endpoint and require a named-model report
whose fixture hash, model identity, thresholds, and environment are current.
Do not make the model a MeaningCore dependency.

**Step 4: Run the named model without changing frozen labels**

```bash
/bin/zsh scripts/verify.sh meaning-preview
swift run --disable-sandbox --scratch-path .swift-build cam-assistant \
  evaluate-meaning-preview \
  Tests/Fixtures/MeaningPreview/v1/manifest.json \
  docs/evidence/add2cam-09-named-model-report.json
```

Expected: all frozen thresholds pass. If any threshold fails, preserve the
report, keep reflection unavailable, and stop this task.

**Step 5: Verify and commit only a valid result**

```bash
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewTests
git add Sources/CAMAssistantCore/Meaning/MeaningPreviewCandidateSupplier.swift \
  Sources/CAMAssistantCore/Meaning/MeaningPreviewCoordinator.swift \
  Sources/CAMAssistantApp/Views/MeaningPreviewView.swift \
  Tests/CAMAssistantCoreTests/MeaningPreviewTests.swift \
  Tests/CAMAssistantAppTests/MeaningPreviewAppModelTests.swift \
  docs/evidence/add2cam-09-named-model-report.json
git commit -m "Gate local Meaning Preview reflection"
```

### Task 10: Package The Isolated Pilot Journey

**Files:**

- Create: `Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh`
- Modify: `scripts/verify.sh`
- Modify: `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- Create: `docs/evidence/add2cam-10-packaged-pilot.md`

**Step 1: Write the failing packaged journey**

The isolated application-support journey must prove:

1. ordinary CAM launch has no Meaning Preview workspace or pilot store;
2. explicit enablement grants no permission;
3. explicit permission plus selected synthetic context permits a request;
4. practical utility returns zero or one card;
5. Inspect, `Now`, `Later`, `Release`, and feedback are accessible;
6. disable removes pilot behavior and returns to ordinary CAM;
7. restart keeps ordinary CAM and CAM database unchanged;
8. pilot state remains isolated and reviewable;
9. no notification, network, cloud, CAM, web, or action execution occurs.

**Step 2: Run to observe failure**

```bash
/bin/zsh Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh
```

Expected: failure because packaging has no Meaning Preview journey.

**Step 3: Add only the required test hooks**

Use the existing absolute application-support override and synthetic fixture
paths. Do not add production bypasses or credential-bearing configuration.

**Step 4: Verify packaged and aggregate behavior**

```bash
/bin/zsh Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh
/bin/zsh scripts/verify.sh meaning-preview
/bin/zsh scripts/verify.sh all
```

Expected: journey, focused suite, existing 48-bullet goal map, package,
privacy, reproducibility, fresh-clone, and aggregate verification pass.

**Step 5: Commit**

```bash
git add Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh \
  Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift \
  scripts/verify.sh docs/evidence/add2cam-10-packaged-pilot.md
git commit -m "Verify packaged Meaning Preview pilot"
```

### Task 11: Run The Human Pilot And Decide

**Files:**

- Create: `docs/pilots/meaning-preview-v1-protocol.md`
- Create: `docs/pilots/meaning-preview-v1-report.md`
- Create: `docs/evidence/add2cam-11-final-containment.md`
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `docs/evidence/goal-finish-wiki-gate-map.json`

**Step 1: Approve the protocol before sessions**

Define consent, minimum evidence sufficiency, duration, synthetic/personal
context rules, withdrawal, local receipt handling, interview questions,
stopping rules, invalid-session handling, and report schema. Do not choose
thresholds after observing results.

**Step 2: Run human sessions**

Use the packaged isolated pilot. Do not commit personal content or raw
interview transcripts. Preserve withdrawn, invalid, failed, and completed
sessions as separate local receipts.

**Step 3: Write the limitations-first report**

Report system-level evidence for:

- first-use comprehension;
- useful result and correct silence;
- nuisance, pressure, and confusion;
- correction burden;
- Inspect comprehension;
- upbeat/confident/adult tone;
- distinction from self-help/task apps;
- disable, restart, and recovery;
- practical versus reflective lane differences;
- safety and privacy failures.

End with exactly one verdict:

```text
promote-candidate
revise-and-retest
stop
```

**Step 4: Refresh containment and aggregate proof**

Run:

```bash
git status --short --branch
git rev-parse HEAD
git -C /Volumes/WS4TB/me-ning/MeaningCore status --short --branch
git -C /Volumes/WS4TB/me-ning/MeaningCore rev-parse HEAD
/bin/zsh scripts/verify.sh meaning-preview
/bin/zsh scripts/verify.sh all
git diff --check
```

Expected: all proof passes, MeaningCore remains unchanged, and the report does
not claim default integration or resolution of the larger human problem.

**Step 5: Update truth and commit**

Update truth files only with verified facts and retain every remaining
`GOAL_FINISH_WIKI.md` limitation.

```bash
git add docs/pilots/meaning-preview-v1-protocol.md \
  docs/pilots/meaning-preview-v1-report.md \
  docs/evidence/add2cam-11-final-containment.md \
  DECISIONS.md PROGRESS.md TASK_QUEUE.md docs/VERIFICATION_REPORT.md \
  docs/evidence/goal-finish-wiki-gate-map.json
git commit -m "Report Meaning Preview human pilot"
```

## Completion Handoff

Do not implement any ingrained behavior under this plan. If the verdict is
`promote-candidate`, create a new design and goal for each proposed promotion.
If it is `revise-and-retest`, version the fixtures and protocol without
rewriting v1 evidence. If it is `stop`, disable the pilot and preserve the
evidence and isolated state for review.
