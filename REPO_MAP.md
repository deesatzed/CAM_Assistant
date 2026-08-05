# REPO_MAP.md

## Project Type

Native, local-first macOS personal assistant and memory application with a CLI,
multiple experimental specialist modules, and extensive verification artifacts.

## Tech Stack

- Swift 6.2 package targeting macOS 15
- SwiftUI application and menu-bar extra
- Swift Testing
- SQLite and content-addressed local object storage
- Native Foundation, FSEvents, Keychain, process, and accessibility integration
- Pinned Swift package dependency on MeaningCore

## Package Manager

Swift Package Manager. The package builds `CAMAssistantCore`, the
`CAMAssistant` app executable, and the `cam-assistant` CLI.

## Commands

| Purpose | Command | Verified |
|---|---|---|
| Focused or aggregate tests | `/bin/zsh scripts/verify.sh all` | Yes on 2026-08-05 with fresh-clone intentionally skipped; 448 tests passed |
| Build unsigned app package | `/bin/zsh scripts/verify.sh package` | Yes as part of aggregate verification |
| Validate 48-gate map | `/bin/zsh scripts/verify.sh goal-map` | Yes; 17 passed, 28 partial, 3 missing |
| Offline smoke | `/bin/zsh scripts/verify.sh smoke` | Covered by repository verification history; not rerun separately in this inventory |
| Diff/portability check | `/bin/zsh scripts/verify.sh portability` | Yes on 2026-08-05 |

No separate lint tool is configured. Swift compilation, tests, repository
scripts, and `git diff --check` are the present static/verification surfaces.

## Entry Points

- `Sources/CAMAssistantApp/CAMAssistantApp.swift` — native app and menu-bar extra
- `Sources/CAMAssistantApp/Views/AssistantWindow.swift` — twelve-destination UI
- `Sources/CAMAssistantApp/AppModel.swift` — 4,005-line application coordinator
- `Sources/CAMAssistantCLI/main.swift` — CLI dispatch
- `scripts/verify.sh` — verification router
- `scripts/package-app.sh` — unsigned app packaging

## Major Folders

- `Sources/CAMAssistantCore/Storage`, `Capture`, `Ingest`, `Retrieval` — core
  local memory path
- `Sources/CAMAssistantCore/Conversation`, `Models`, `Routing` — answer/model
  path
- `Sources/CAMAssistantCore/Privacy`, `Authority`, `Audit` — safety substrate
- `Sources/CAMAssistantCore/Research`, `Repositories`, `CAM`, `MacCare`,
  `Meaning`, `Modules`, `Coordination` — specialist or experimental systems
- `Sources/CAMAssistantApp/Views` — SwiftUI workspaces
- `Tests/CAMAssistantCoreTests`, `Tests/CAMAssistantAppTests` — 448 tests
- `Tests/ReleaseProofTests` — package/privacy/goal/pilot scripts
- `docs/plans`, `docs/evidence`, `docs/handoffs`, `docs/build-reports` — planning
  and proof history
- `artifacts` — generated app/package evidence
- `pendoleum` — untracked nested repository; not part of verified product scope

## Existing Patterns To Preserve

- Local-first behavior and explicit no-fallback routing
- Immutable content IDs and atomic/reversible storage
- Typed errors, permission classes, exact approvals, and status-only audit
- Ephemeral model output until explicit Keep
- Separate deterministic, synthetic, packaged, named-model, and human evidence
- Tests that fail closed on drift, stale state, or missing authority

## Tests and Verification

The current checkout passes all 448 Swift tests plus release build, package
reproducibility, package identity, and a bounded credential-signature scan.
The 48-gate product map remains incomplete, so component correctness must not be
reported as whole-product readiness.

## Likely Files For Current Task

- `RESET_INVENTORY_2026-08-05.md`
- `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- `Sources/CAMAssistantApp/Views/Sidebar.swift`
- `Sources/CAMAssistantApp/AppModel.swift`
- `Sources/CAMAssistantApp/Views/ConversationView.swift`
- `Sources/CAMAssistantApp/Views/LibraryView.swift`
- `GOAL.md`, `GOAL_FINISH_WIKI.md`, `TASK_QUEUE.md`, `PROGRESS.md`

## Unknowns

- Which real daily tasks the user values enough to retain after Capture,
  Library, and local Ask.
- Whether routing suffixes remain desirable in a simplified UI.
- Whether Meaning Preview produces authentic human value.
- Which local model meets acceptable quality and latency on the user's Mac.
- Whether foreign untracked root materials should move to another repository,
  an archive, or remain untouched.
