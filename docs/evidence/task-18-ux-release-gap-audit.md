# UX, Accessibility, Recovery, and Release Gap Audit

**Date:** 2026-07-28  
**Status:** Read-only implementation and evidence inventory. Final release proof
is not complete.

## Scope

This audit compares current SwiftUI views, focused accessibility/app tests,
package/smoke/fresh-clone scripts, saved packaged-journey receipts, and the
aggregate verifier with CAM-012, CAM-018, and the final
`GOAL_FINISH_WIKI.md` proof gate. The source baseline is commit
`79551aafcbe49f2486955a01a9386b0aeaec0448`.

No packaged GUI automation, VoiceOver speech recording, visual measurement,
signing, notarization, or distribution occurred during this audit.

## What is currently real

### Native experience

- The default window provides a compact local chat/capture surface and sidebar
  workspaces for Library, Activity, Tasks, CAM, Research, Repositories,
  Mac Care, and Settings.
- Settings separates Models, Hotkeys, and Capture Sources.
- The local question field has explicit focus state and Return behavior.
- Primary controls and status/error rows carry accessibility labels or hints.
- Library, Tasks, and Mac Care root containers preserve descendant controls and
  state descriptions.
- Repository and ingest job actions are exposed as independent bounded
  Cancel/Resume controls.
- Progress, empty, offline, read-only, disabled-execution, error, cancelled,
  and recovery text exists across the implemented slices.
- App source contains no explicit SwiftUI animation, transition,
  matched-geometry, symbol-effect, or content-transition API.

### Current focused verification

- Four `AccessibilityTests` pass for offline explanation, hotkey validation,
  registration-status wording, and hotkey restart persistence.
- Ten `CAMAssistantAppTests` pass for foreground activation order, settings
  panes, collision-safe key codes, automatic capture default, watched-capture
  refresh order, repository job recovery/cancellation, and source-level
  accessibility contracts.
- Existing saved packaged receipts document manually exercised global
  open/capture hotkeys, watched-source lifecycle, ingest cancel/restart/resume,
  selected loopback-model chat and citation navigation, initial/retained
  question focus, sidebar keyboard navigation, and repaired empty/read-only
  accessibility children in disposable roots.

### Build and portability

- `verify-portability.sh` requires repository-local truth files, rejects
  tracked generated/Finder artifacts, and runs `git diff --check`.
- `verify-fresh-clone.sh` creates a non-local temporary clone of the committed
  revision and runs portability, aggregate tests/release build, package
  validation, and offline smoke.
- `package-app.sh` reproducibly creates an unsigned local app bundle with a
  minimal valid `Info.plist`.
- Offline smoke executes a deterministic app mode with no key or network
  requirement and confirms capture/local search without cloud auto-routing.

## Proof-type distinction

| Evidence type | What it proves | What it does not prove |
|---|---|---|
| Pure core tests | Deterministic state/validation behavior | Runtime SwiftUI/VoiceOver behavior |
| AppModel tests | Selected main-actor coordination logic | A packaged GUI journey |
| Source-contract tests | Required labels/text/modifiers remain in specific source chains | Actual accessibility tree, focus order, speech, visibility, clipping, or interaction |
| Package validation | Bundle structure and `Info.plist` syntax | Launch usability, resources, signing, or notarization |
| Offline smoke | Direct debug executable's special offline branch exits successfully | Packaged app launch or a user workflow |
| Manual native accessibility inspection | Observed packaged behavior for the recorded disposable journey | Automatic regression coverage or every state/control |
| Fresh-clone verifier | Committed source reproduces tests/build/package/smoke | Manual GUI journeys, model service availability, or full product completion |

## Missing UX and accessibility proof

| Required behavior | Current state | Missing proof or implementation |
|---|---|---|
| Complete workspace set | No Modules or Approvals workspace; CAM is status-only | Implement missing workspaces and verify navigation/authority |
| Keyboard navigation | Saved sidebar/focus slice exists | Every control, sheets/dialogs, lists, cancel/recovery paths, focus return, and keyboard-only complete journeys |
| VoiceOver | Labels/tree slice manually inspected | Spoken output, reading order, rotor/grouping behavior, value changes, announcements, action naming, and every primary populated/error state |
| Visual accessibility | SwiftUI semantic colors are used in many places | Contrast measurement, high-contrast/increase-contrast, differentiate-without-color, text scaling, clipping, truncation, and window-size matrix |
| Reduced motion | No app-authored motion API found | Runtime check with Reduce Motion enabled and future-animation regression gate |
| Large data | Scrollable views exist | Populated large Library/Activity/Repository/Task/Research sets, performance, stable identity, focus, truncation, and cancellation |
| Loading/offline/error/cancelled | Many status strings exist | Packaged exercise of every required state and recovery action |
| Authority visibility | Many hints state what is disabled/local | Complete proof that every transition to network, mutation, permission, Keep, task, CAM, or module authority is visible |
| Fresh user | Isolated package slices exist | One scripted fresh-root journey covering onboarding through capture/search/chat/retention/backup |
| Restart/recovery | Individual capture, model, source, and repository slices exist | One whole-product restart journey with interrupted work, retained state, and full-vault restore |

## Missing aggregate and release proof

1. `scripts/verify.sh all` runs portability, the Swift test suite, release
   build, and—outside its recursion guard—the fresh-clone verifier. It does not
   run the saved native GUI journeys or a UI automation suite.
2. `smoke-app.sh` runs the debug executable's `--smoke-offline` path rather than
   launching and interacting with `artifacts/CAM Assistant.app`.
3. No XCTest UI target, accessibility-tree assertion harness, deterministic GUI
   journey driver, visual snapshot/contrast tool, or VoiceOver spoken-audio
   receipt is part of the repository.
4. Full-vault backup/restore and one unified fresh-root/restart/recovery journey
   do not exist.
5. The app package does not include dynamic module manifests/resources because
   SwiftPM declares no resources.
6. The bundle version is currently hard-coded in the package script; no
   commit/build receipt is embedded in the app.
7. No automated secret/privacy scan covers the final package/evidence set in
   the aggregate verifier.
8. No final requirement-by-requirement machine-readable release report maps
   every goal gate to a current artifact and verdict.
9. Signing, notarization, and distribution are correctly deferred pending the
   user's policy and credentials.

## Required finish boundary

1. Add a repository-owned deterministic journey harness for every automation-
   safe packaged interaction and keep manual-only VoiceOver/visual evidence
   explicitly separate.
2. Make `verify.sh all` invoke the complete automated unit, integration,
   privacy, retrieval, cancellation, restart, accessibility-contract,
   conformance, package, packaged-smoke, and portable-clone checks.
3. Preserve disposable absolute application-support roots for every packaged
   proof and prove normal user state is unchanged.
4. Exercise a fresh-user journey and a whole-product restart/recovery journey,
   including full-vault backup/restore, after those features exist.
5. Test empty, populated, loading, offline, error, cancelled, stale, recovery,
   and unavailable states for every primary workspace.
6. Record current commit, branch, dirty state, environment, commands, results,
   artifact hashes, performance, limitations, deferrals, privacy review, and
   rollback paths in final human- and machine-readable reports.
7. Do not treat source-text checks, manual one-off observations, package syntax,
   or a passing test count as broader proof than they provide.

## Current proof boundary

The current app is a real native unsigned package with substantial manually
observed and unit-tested accessibility behavior. It is not yet covered by a
complete repeatable packaged GUI suite, full VoiceOver/visual matrix,
full-vault recovery, unified restart journey, final privacy/security scan, or
release audit.

No final-release claim is made.

