# ADD2CAM Native UX

## GOAL ID

`ADD2CAM-20`

## ROLE

Add the explicit opt-in native Meaning Preview, Inspect, Settings, accessibility, disable, and recovery experience.

## PREREQUISITE COMMIT

Assigned by the orchestrator to the exact accepted Goal 10 integration commit before dispatch.

## BRANCH / WORKTREE

Branch `agent/add2cam-20-native-ux`; worktree `/private/tmp/cam-add2cam-20260731/native-ux`.

## DEPENDENCIES

`ADD2CAM-10` integrated with frozen app-facing request, result, action, and state-store protocols.

## OUTCOME

A disabled-by-default native surface reveals at most one practical card only after explicit enablement and local-data grant, exposes truthful Inspect/actions/recovery, and returns completely to ordinary CAM when disabled.

## PROOF OF DONE

Disabled absence, explicit reveal, permission refusal, zero/one card, Inspect evidence, independent actions, accessibility, reduced motion, recovery states, and disable restoration pass focused app tests.

## OWNED FILES

`Sources/CAMAssistantApp/Views/MeaningPreviewView.swift`; `Sources/CAMAssistantApp/Views/MeaningInspectView.swift`; `Sources/CAMAssistantApp/Views/MeaningPreviewSettingsView.swift`; `Sources/CAMAssistantApp/AppModel.swift`; `Sources/CAMAssistantApp/Views/AssistantWindow.swift`; `Sources/CAMAssistantApp/Views/Sidebar.swift`; `Tests/CAMAssistantAppTests/AccessibilityViewContractTests.swift`; `Tests/CAMAssistantAppTests/MeaningPreviewAppModelTests.swift`; `docs/handoffs/add2cam/20260731/20_NATIVE_UX.md`.

## PROTECTED FILES

Repository truth; core coordinator/store APIs; Goal 21/30 test files; scripts; MeaningCore; donors; personal/live data.

## SAFETY / PROVENANCE

No preview when disabled or ungranted. No hidden reads, network, model calls, notifications, or execution. UI labels must distinguish source evidence, inference, proposal, unavailable, and error states.

## AUTONOMOUS DECISION POLICY

Follow existing CAM visual and accessibility patterns. Make reversible presentation choices; do not alter frozen core interfaces without an integrator amendment.

## CONSTRAINTS

Use TDD; preserve ordinary CAM behavior; support keyboard and VoiceOver contracts; avoid motion-dependent meaning; do not add production verification bypasses.

## ITERATION

Observe focused app-test failure, implement minimal UI/model behavior, run app and accessibility tests, then `git diff --check`.

## HANDOFF

Record commits, owned changes, red/green proof, screenshots only if synthetic/disposable, accessibility limitations, boundary confirmation, and a terminal status in `20_NATIVE_UX.md`.

## RETRY / RECOVERY

Retry focused failures twice after diagnosis. If a core interface change is essential, stop and return a narrow amendment request to the integrator.

## STOP

Stop for hidden access, live personal context, donor edits, scope-changing UX policy, unsafe permissions, or repeated failure.

## COMPLETE

Complete with an owned-files-only commit, green focused tests, durable handoff, and clean worktree.
