# Watched Source Onboarding Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add explicit, locally persisted, independently controllable watched
folders that feed the existing local capture and ingestion pipeline.

**Architecture:** A typed core configuration store persists canonical selected
paths and enabled state atomically. A session-only manager owns one existing
`FolderWatcher` per enabled source and forwards envelopes to an injected local
capture closure. `AppModel` bridges this manager to local vault dependencies
and a native SwiftUI source-management view.

**Tech Stack:** Swift 6.3, Foundation, FSEvents through `FolderWatcher`,
SQLite-backed `IngestQueue`, SwiftUI, Swift Testing.

---

### Task 1: Persisted watched-source configuration

**Files:**

- Create: `Sources/CAMAssistantCore/Capture/WatchedSourceConfiguration.swift`
- Modify: `Tests/CAMAssistantCoreTests/IngestTests.swift`

**Step 1: Write the failing test**

Add temporary-directory tests for: an empty store, atomic save/reopen of two
canonical paths, duplicate-path rejection, and independent enabled/paused
state. The test must assert that removing one source leaves the other one.

```swift
let store = WatchedSourceConfigurationStore(url: root.appending(path: "watched-sources.json"))
let source = try WatchedSource(path: "/tmp/a", isEnabled: false)
try store.save([source])
#expect(try WatchedSourceConfigurationStore(url: store.url).load() == [source])
```

**Step 2: Run test to verify it fails**

Run: `/bin/zsh scripts/verify.sh ingest`

Expected: compilation failure because `WatchedSource` and its store do not
exist. Add the `ingest` suite alias first if necessary; it must filter only
`IngestTests`.

**Step 3: Write minimal implementation**

Create `WatchedSource` with stable UUID, canonical path, enabled state, and
optional local status/error fact. Reject blank and duplicate canonical paths.
Save the complete ordered record list using JSON atomic write beneath the
supplied local URL. The store must not inspect or read source-folder contents.

**Step 4: Run test to verify it passes**

Run: `/bin/zsh scripts/verify.sh ingest`

Expected: new configuration tests pass with the existing ingestion tests.

**Step 5: Commit**

Do not commit in the current dirty recovery worktree. When a clean, scoped
publication surface is authorized: `git add Sources/CAMAssistantCore/Capture/WatchedSourceConfiguration.swift Tests/CAMAssistantCoreTests/IngestTests.swift scripts/verify.sh`.

### Task 2: Independent local watcher lifecycle

**Files:**

- Create: `Sources/CAMAssistantCore/Capture/WatchedSourceManager.swift`
- Modify: `Tests/CAMAssistantCoreTests/IngestTests.swift`

**Step 1: Write the failing test**

Inject a watcher factory and a capture closure. Prove an enabled source starts
once, a paused source does not start, pausing/removing stops only the target,
and an individual start failure becomes a source-specific error without
stopping another source.

```swift
let manager = WatchedSourceManager(makeWatcher: factory, capture: capture)
try manager.reconcile([enabledA, pausedB])
#expect(factory.startedPaths == [enabledA.canonicalPath])
```

**Step 2: Run test to verify it fails**

Run: `/bin/zsh scripts/verify.sh ingest`

Expected: compilation failure because `WatchedSourceManager` does not exist.

**Step 3: Write minimal implementation**

Use `FolderWatcher` only behind a small internal watcher protocol/factory.
Maintain a map keyed by source ID. `reconcile` starts only enabled sources,
stops removed/paused sources, and reports per-source lifecycle facts. Its
capture callback must receive a `CaptureEnvelope` only and never perform
network, cloud, or file mutation.

**Step 4: Run test to verify it passes**

Run: `/bin/zsh scripts/verify.sh ingest`

Expected: lifecycle tests and existing FSEvents proof pass.

**Step 5: Commit**

Defer publication in this dirty worktree; retain exact files for later scoped
staging.

### Task 3: App-model local capture bridge

**Files:**

- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Tests/CAMAssistantCoreTests/IngestTests.swift` only if a core
  presentation type is needed

**Step 1: Write the failing test**

Add a core presentation test for enabled/paused/error text if presentation is
kept in the core. Do not add an app test that invokes a real user folder.

**Step 2: Run test to verify it fails**

Run: `/bin/zsh scripts/verify.sh ingest`

Expected: failure for the missing presentation/bridge contract.

**Step 3: Write minimal implementation**

Load configuration from `LocalVaultPaths.rootURL()/watched-sources.json`.
On the main actor, expose presentation records and explicit add/enable/pause/
remove methods. Perform watcher reconciliation and `CaptureService` work away
from the main actor. A captured envelope enters the existing `IngestQueue`,
processes locally, refreshes Library state, and reports a status-only receipt.
No source bytes may be copied into UI state or logs.

**Step 4: Run test to verify it passes**

Run: `/bin/zsh scripts/verify.sh ingest`

Expected: focused core suite passes; App target compiles.

**Step 5: Commit**

Defer publication in this dirty worktree.

### Task 4: Native source controls

**Files:**

- Create: `Sources/CAMAssistantApp/Views/CaptureSourcesView.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`

**Step 1: Write the failing test**

Add a core `WatchedSourcePresentation` test that verifies the empty, enabled,
paused, and failure labels. This avoids pretending a SwiftUI render is the
same as an FSEvents proof.

**Step 2: Run test to verify it fails**

Run: `/bin/zsh scripts/verify.sh ingest`

Expected: failure because the presentation label contract is absent.

**Step 3: Write minimal implementation**

Expose the view under Settings or a dedicated Capture Sources section. Use a
native `NSOpenPanel` directory picker only from an explicit `Add Folder…`
button. Render canonical path, enabled/paused state, local error/status,
enable/pause, and remove controls. Give every control an accessible label.
The picker does not automatically start a watcher; the user must enable it.

**Step 4: Run test to verify it passes**

Run: `/bin/zsh scripts/verify.sh ingest && /bin/zsh scripts/verify.sh all`

Expected: focused and aggregate tests pass with release build.

**Step 5: Commit**

Defer publication in this dirty worktree.

### Task 5: Evidence and audit update

**Files:**

- Modify: `PROGRESS.md`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `TASK_QUEUE.md`
- Modify: `DECISIONS.md` if the persisted multi-source ownership choice is not
  already captured by the design record

**Step 1: Record only reproduced evidence**

Add the exact focused/aggregate command output and the specific local-only
boundaries. Do not claim background launch, OS global event dispatch, external
processing, or unattended capture.

**Step 2: Verify documentation integrity**

Run: `git diff --check`

Expected: no whitespace errors.

**Step 3: Final verification**

Run: `/bin/zsh scripts/verify.sh all && /bin/zsh scripts/verify.sh package && /bin/zsh scripts/verify.sh smoke`

Expected: all local verification succeeds. If the package or smoke check does
not cover a new user-visible control, record that limitation rather than
promoting it to release proof.

**Step 4: Commit**

Do not commit or publish without a clean scoped surface and user authorization.
