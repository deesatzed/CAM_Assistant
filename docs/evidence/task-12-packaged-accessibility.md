# Task 12 Packaged Accessibility, Keyboard, and Motion Evidence

**Date:** 2026-07-28
**Source checkpoint:** `df6f21aafdad0e3dc30f50fc688a938e75aa8e10`
plus the accessibility changes under verification
**Application:** `artifacts/CAM Assistant.app`
**Disposable application-support root:**
`/private/tmp/cam-accessibility-proof.nCmJbB`

## Scope

This receipt covers a native accessibility-tree and keyboard inspection of the
unsigned packaged app. It uses only a disposable application-support root. It
does not use the normal CAM vault, a cloud route, CAM, a model server, or
personal source content.

The inspection ran on macOS 27.0 build 26A5388g through the Computer Use native
accessibility API. Each action was followed by a fresh `get_app_state` query
against the full packaged-app path. The relevant before/after tree excerpts are
recorded below; the complete transient tool stream was not added to Git.

## Initial packaged journey

- The fresh app opened on Assistant with the local question field focused.
- The system status was exposed as
  `Offline. Capture and local search remain ready.`
- The question field was exposed as `Local assistant question`.
- `Ask locally` explicitly said it uses local retrieval only.
- `Ask Selected Local Model` was disabled because no profile was configured and
  its help text said it never falls back to cloud, web, or CAM.
- Pressing Return on the blank focused field exposed
  `Question error: Enter a question to search local sources.` and retained
  focus in the question field.
- Pressing Tab moved keyboard selection to the Assistant sidebar row. Pressing
  Down moved the selected workspace to Library. Repeated Down presses selected,
  in order, Activity, Tasks, CAM, Research, Repositories, Mac Care, and Settings.

## Accessibility-tree findings

The packaged inspection confirmed usable labels, values, state, and safety
boundaries for:

- Activity, including its meaningful no-jobs state. Prior native cancellation
  evidence separately proves independent accessible Cancel and Resume actions.
- CAM unavailable status and disabled execution boundary.
- Research question, local-plan actions, disabled Keep state, and explicit
  web/cloud/CAM/automatic-retention prohibition.
- Repository path, read-only inspection, explicit local indexing and
  observation controls, proposal-only ideas, and disabled CAM mining.
- Settings Models, Hotkeys, and Capture Sources as distinct radio controls with
  selected values.
- Capture Sources' no-folders state and explicit paused-by-default wording.
- Hotkey fields and Save action. A disposable C/C duplicate configuration
  produced the accessible error
  `Hotkey configuration could not be saved.` while focus remained in the
  Capture key field.

## Reproduced defect and test-first correction

Before correction, the packaged accessibility tree collapsed Library, Tasks,
and Mac Care into repeated summary labels. Their child controls and meaningful
empty/read-only descriptions were not exposed. For example, Library exposed
only `Library. 0 active and 0 hidden indexed local sources.` rather than
`Your local library is empty` and its recovery guidance.

Root cause: those three root SwiftUI containers applied a summary
`accessibilityLabel` without declaring that their descendants must remain
contained.

The initial focused regression test
`workspaceAccessibilityContainersPreserveChildren` failed against all three
views before production changes. The minimal correction adds
`.accessibilityElement(children: .contain)` before each root summary label.
The strengthened contract binds that exact root modifier chain to each
workspace's required state/action strings, and a negative test proves unrelated
child containment is rejected. Both focused tests pass.

After rebuilding and relaunching the package, the native accessibility tree
exposed:

- Library summary, `0 active indexed local sources`, Refresh, and
  `Your local library is empty` with its capture/index guidance.
- Tasks summary, `0 open local tasks`, Refresh, and `No saved tasks` with its
  cited-answer promotion guidance.
- Mac Care summary, `Mac Care is read-only`, Assess Standard Locations, and the
  exact explanation that maintenance needs approval and cannot apply or undo
  changes in this milestone.

## Motion inspection

This source scan returned no matches:

```text
rg -n '\.animation\(|withAnimation\(|\.transition\(|matchedGeometryEffect|symbolEffect|contentTransition' Sources/CAMAssistantApp
```

The current app defines no explicit SwiftUI animation, transition, matched
geometry, symbol-effect, or content-transition behavior. Therefore this build
does not expose app-authored motion that needs an alternate reduced-motion
path.

## Automated verification

- The focused regression passed after the expected red; the strengthened
  source contract and its negative case also pass.
- `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all` passed
  portability, all 191 tests, and the release build.
- `/bin/zsh scripts/verify.sh package` rebuilt the unsigned app and validated
  its `Info.plist`.
- `/bin/zsh scripts/verify.sh smoke` reported
  `mode=offline capture=true local_search=true cloud_auto=false`.
- `git diff --check` passed.

## Verification boundary

This proves a packaged keyboard-navigation slice, initial and retained focus,
native accessibility labels/values for the primary workspaces, meaningful
empty/offline/error/read-only states, the repaired child-content exposure, and
absence of app-authored motion APIs.

It does **not** claim an end-to-end VoiceOver spoken-audio session, every
possible tab stop or focus cycle, accessibility across populated large-data
states, contrast/dynamic-type conformance, signing/notarization, or completion
of the full release gate. CAM-012 and CAM-018 remain in progress.
