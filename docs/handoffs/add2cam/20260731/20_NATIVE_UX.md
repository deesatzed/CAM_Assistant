# ADD2CAM-20 Native UX Handoff

## Identity

- Effective prerequisite commit: `5631bec` (accepted Goal 21 on top of Goal 10)
- Branch: `agent/add2cam-20-native-ux`
- Worktree: `/private/tmp/cam-add2cam-20260731/native-ux`
- Runtime commit: `7b3c0c4` (`feat: add native Meaning Preview runtime`)
- Native UI commit: `c3a482d` (`feat: add Meaning Preview native workspace`)
- Review remediation commit: `393baae` (`fix: harden Meaning Preview recovery boundaries`)

## Changed Files

- `Sources/CAMAssistantApp/AppModel.swift`
- `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- `Sources/CAMAssistantApp/Views/Sidebar.swift`
- `Sources/CAMAssistantApp/Views/MeaningPreviewView.swift`
- `Sources/CAMAssistantApp/Views/MeaningInspectView.swift`
- `Sources/CAMAssistantApp/Views/MeaningPreviewSettingsView.swift`
- `Tests/CAMAssistantAppTests/MeaningPreviewAppModelTests.swift`
- `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`
- `docs/handoffs/add2cam/20260731/20_NATIVE_UX.md`

All implementation paths are inside the Goal 20 allowlist. MeaningCore, donor
repositories, core coordinator/store APIs, scripts, and repository truth were
not changed.

## Delivered Behavior

- Meaning Preview is absent from the sidebar while disabled. Its settings sheet
  remains reachable from ordinary Settings so enablement is an explicit opt-in.
- Enablement grants no source or state access. Read-local and isolated-write
  permissions are a separate explicit grant, both are required, and any
  manifest permission drift makes the feature unavailable.
- The AppModel retains only an opaque selected source ID. After authorization,
  the live resolver performs an exact active-document lookup, classifies the
  full derived document, and supplies at most 4,096 derived characters to the
  coordinator.
- The workspace returns zero or one practical card and exposes truthful Inspect,
  Now/Later/Release, Helpful/Not Helpful, silence, unavailable, recovery, and
  Disable states.
- Confirmed malformed or unsupported isolated stores receive distinct
  corrupted/incompatible states. Only those fully granted states expose an
  explicit archive-and-reinitialize action. Disabled, enable-only, healthy, and
  transient-I/O states cannot archive or recreate pilot storage.
- Feedback familiarity is scoped to the exact selected source even when source
  metadata supplies the same broad domain label.
- Disable invalidates in-flight request/action/feedback completions and the
  app-owned authorization lease. Selecting a different source invalidates an
  older request. A disable that linearizes before Preview save prevents both
  snapshot and audit-event persistence.
- Native controls have stable accessibility identifiers. The feature adds no
  authored animation or motion-dependent meaning.

## Observed Red Proof

- The first UI contract run failed because the three native Meaning Preview view
  files did not exist and `AssistantSection.meaningPreview` made the detail
  switch non-exhaustive.
- A full app-target regression run later failed only because a fifth settings
  pane broke the existing four-pane contract. Settings access was moved to a
  stable sheet button without changing the existing pane enumeration.
- A clean-scratch app run then exposed a missing
  `meaning-preview-sidebar` accessibility identifier. The identifier was added
  to the feature's conditional sidebar row.
- Adversarial runtime review initially blocked on partial-permission proof,
  provider identity, metadata exclusions, raw-source proof, disabled-init side
  effects, selection/disable races, and pre-save authorization. Each finding was
  accepted and covered by focused tests before the runtime commit.
- Final spec and quality reviews then blocked stale/misleading recovery,
  fail-open manifest drift, source-scope leakage, inaccessible silence Inspect,
  disabled in-flight Disable controls, untruthful evidence labels, unowned
  accessibility proof, and transient-I/O misclassification. All findings were
  accepted, remediated in `393baae`, and independently re-reviewed.

## Green Proof

```zsh
/bin/zsh scripts/verify.sh app
/bin/zsh scripts/verify.sh privacy
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewCoordinatorTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter CAMAssistantAppTests
swift test --disable-sandbox --scratch-path .swift-build \
  --filter MeaningPreviewBoundaryTests
git diff --check
```

Final results:

- 59 app tests passed, including 29 focused Goal 20 model/runtime tests.
- All 13 tests in the goal-owned accessibility contract file passed, including
  the 2 Meaning Preview native/source-contract cases.
- 8 privacy tests and 3 audit privacy tests passed.
- All 14 Goal 10 coordinator regressions passed.
- All 12 Goal 21 feedback/audit boundary regressions passed.
- Clean-scratch compilation of the app, CLI, core, and all test targets passed.
- Diff check passed.

SwiftPM emitted only user-cache permission warnings and used repo-local scratch
and module-cache paths. No unsafe permission bypass was used.

## Review Classification

- Initial runtime adversarial review: `BLOCKED`; all seven proof/implementation
  findings were accepted and remediated.
- First final Goal 20 spec review: `BLOCKED`; recovery, ownership, and missing
  handoff findings were accepted and remediated.
- First final code-quality/security review: `BLOCKED`; permission drift,
  recovery, source scope, navigation, Inspect, Disable, labeling, source
  selection, error mapping, and mutation-race findings were accepted.
- Final code-quality/security re-review: `APPROVED`; 29 focused tests and clean
  diff independently confirmed no remaining blocker.
- Terminal spec re-review: pending only this handoff commit at draft time.

## Protected Boundaries

- Disabled or partially granted state refuses before source resolution.
- Disabled, enable-only, healthy, unavailable-I/O, and malformed module states
  refuse before recovery filesystem mutation.
- Restricted, secret-like, stale, hidden, inactive, unsupported, missing, and
  non-permitted contexts produce silence and status-only audit facts.
- A resolver-held raw immutable source marker is absent from the decoded Preview
  snapshot; bounded derived records may persist in the isolated Preview store.
- No model, network, notification, web, cloud, CAM execution, approval
  consumption, or external action path was added.
- The authorization gate serializes the app-owned lifecycle writer with Preview
  saves. The module-state JSON is not an inter-process revocation protocol and
  must not be mutated concurrently by an external writer while the app owns the
  pilot.

## Limitations

- Goal 20 proves deterministic practical UX only. Goal 40 still owns reflective
  local-model admission and runtime gating.
- Package resources, app-bundle execution, Accessibility/TCC journey proof, and
  restart/no-socket packaged evidence remain Goal 50.
- No human-use claim follows from synthetic and automated proof; Goal 60 remains
  the human evidence gate.
- The live source resolver uses CAM's existing `IngestQueue` reader, which opens
  the local SQLite store with its normal migration-capable implementation. This
  occurs only after both manifest permissions are granted.

## Final State

- Implementation commits: `7b3c0c4`, `c3a482d`
- Review remediation commit: `393baae`
- Handoff commit: the commit containing this file
- Worktree status before handoff commit: handoff-only change
- Terminal status: `verified_success` pending integration-branch replay
