# Barebones User-First Reset Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a three-destination, general-user CAM Assistant that proves the capture -> find -> cited local answer -> Keep -> recover loop one independently verified feature at a time.

**Architecture:** Preserve the tested vault, ingest, retrieval, privacy, audit, and recovery substrate. Add a primary/developer experience boundary and small user-facing presentation types, then simplify one vertical journey without deleting specialist code or expanding `AppModel` into new domains.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing, SQLite3, Foundation/FSEvents, native macOS accessibility, repository-owned shell verification and packaging scripts.

---

### Task 1: Establish the Barebones Product Contract

**Files:**
- Create: `GOAL_BAREBONES.md`
- Create: `Tests/ReleaseProofTests/barebones-goal-contract-tests.sh`
- Modify: `GOAL.md`
- Modify: `DECISIONS.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`
- Modify: `scripts/verify.sh`

**Step 1: Write the failing contract test**

Create a shell test that requires the new goal to contain the product promise,
the three destinations, the seven ordered proof gates, the general-iPhone-user
target, progressive disclosure, local/no-model utility, parked specialist
features, and the stop rule.

```zsh
required=(
  "general iPhone user"
  "Home"
  "Library"
  "Settings"
  "Capture"
  "Find"
  "Ask"
  "Keep"
  "Recover"
  "Human"
  "progressive disclosure"
  "no model"
)
for phrase in $required; do
  rg -Fq "$phrase" GOAL_BAREBONES.md || exit 1
done
```

**Step 2: Run the test to verify it fails**

Run: `/bin/zsh Tests/ReleaseProofTests/barebones-goal-contract-tests.sh`
Expected: FAIL because `GOAL_BAREBONES.md` does not exist.

**Step 3: Write the minimal controlling contract**

Create `GOAL_BAREBONES.md` from the approved design. Change `GOAL.md` so this
goal controls the active product reset and `GOAL_FINISH_WIKI.md` becomes
historical/specialist scope rather than an automatic implementation queue.
Add `barebones-goal` to `scripts/verify.sh`.

**Step 4: Run focused verification**

Run: `/bin/zsh Tests/ReleaseProofTests/barebones-goal-contract-tests.sh`
Expected: PASS with `CAM_ASSISTANT_BAREBONES_GOAL status=pass`.

Run: `/bin/zsh scripts/verify.sh portability`
Expected: PASS.

**Step 5: Commit**

```bash
git add GOAL.md GOAL_BAREBONES.md DECISIONS.md PROGRESS.md TASK_QUEUE.md scripts/verify.sh Tests/ReleaseProofTests/barebones-goal-contract-tests.sh
git commit -m "docs: make the user-first barebones goal controlling"
```

### Task 2: Add a Primary Experience Boundary

**Files:**
- Create: `Sources/CAMAssistantApp/Experience/AppExperience.swift`
- Create: `Tests/CAMAssistantAppTests/BarebonesNavigationTests.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Modify: `Sources/CAMAssistantApp/Views/Sidebar.swift`

**Step 1: Write the failing tests**

```swift
import Testing
@testable import CAMAssistantApp

@Test("primary experience exposes only the ordinary three destinations")
func primarySectionsAreSmall() {
    #expect(AppExperience.primary.visibleSections == [.home, .library, .settings])
}

@Test("production defaults to the primary experience")
func productionDefaultIsPrimary() {
    #expect(AppExperience.productionDefault == .primary)
}

@Test("specialist destinations require explicit developer injection")
func specialistSectionsStayHidden() {
    #expect(!AppExperience.primary.visibleSections.contains(.cam))
    #expect(AppExperience.developer.visibleSections.contains(.cam))
}
```

**Step 2: Run the test to verify it fails**

Run: `/bin/zsh scripts/verify.sh app`
Expected: FAIL because `AppExperience` and `.home` do not exist.

**Step 3: Implement the minimal boundary**

```swift
enum AppExperience: Sendable, Equatable {
    case primary
    case developer

    static let productionDefault: Self = .primary

    var visibleSections: [AssistantSection] {
        switch self {
        case .primary: [.home, .library, .settings]
        case .developer: AssistantSection.allCases
        }
    }
}
```

Rename the primary Assistant case to Home in user-facing copy. Inject
`AppExperience` into `AppModel`; do not read a user preference for developer
mode. Make Sidebar render the injected list. Keep specialist switch cases so
their code compiles and remains testable.

**Step 4: Run verification**

Run: `/bin/zsh scripts/verify.sh app`
Expected: all app tests pass, including the three new navigation tests.

Run: `/bin/zsh scripts/verify.sh smoke`
Expected: offline smoke passes.

**Step 5: Commit**

```bash
git add Sources/CAMAssistantApp/Experience/AppExperience.swift Sources/CAMAssistantApp/AppModel.swift Sources/CAMAssistantApp/Views/AssistantWindow.swift Sources/CAMAssistantApp/Views/Sidebar.swift Tests/CAMAssistantAppTests/BarebonesNavigationTests.swift
git commit -m "feat: default to the three-place CAM experience"
```

### Task 3: Replace the Console-Like Assistant With Home

**Files:**
- Create: `Sources/CAMAssistantApp/Presentation/HomePresentation.swift`
- Create: `Sources/CAMAssistantApp/Views/HomeView.swift`
- Create: `Tests/CAMAssistantAppTests/HomePresentationTests.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Retain for developer mode: `Sources/CAMAssistantApp/Views/ConversationView.swift`

**Step 1: Write the failing presentation tests**

```swift
@Test("empty Home offers one primary capture action without technical language")
func emptyHomeCopy() {
    let value = HomePresentation.empty
    #expect(value.title == "Your private Library is empty")
    #expect(value.primaryActionTitle == "Save Clipboard")
    #expect(value.privacyNote == "Your saved content stays on this Mac.")
    #expect(!value.visibleText.contains("index"))
    #expect(!value.visibleText.contains("endpoint"))
}

@Test("model absence preserves a useful local result")
func noModelFallbackCopy() {
    let value = LocalAssistantAvailability.unavailable
    #expect(value.explanation == "Local AI is not running, so CAM will show matching passages from your Library.")
}
```

Add a source-contract test that rejects these primary Home strings:
`OpenRouter`, `loopback`, `route`, `provider`, `CAM`, `schema`, `passage ID`,
and `ingest`.

**Step 2: Run tests to verify failure**

Run: `/bin/zsh scripts/verify.sh app`
Expected: FAIL because the Home presentation and view do not exist.

**Step 3: Implement minimal Home**

Home contains:

- friendly empty or recent-save state;
- one Save Clipboard button;
- one question field labelled “What are you looking for?”;
- one Ask button;
- answer/matching passage card;
- citations labelled with source names;
- Keep and Discard;
- Details disclosure for technical route/model information.

Do not display OpenRouter or multiple local answer buttons. Do not delete their
developer-mode code.

**Step 4: Run verification**

Run: `/bin/zsh scripts/verify.sh app`
Expected: all app tests pass.

Run: `/bin/zsh scripts/verify.sh conversation`
Expected: all existing conversation contracts pass.

**Step 5: Commit**

```bash
git add Sources/CAMAssistantApp/Presentation/HomePresentation.swift Sources/CAMAssistantApp/Views/HomeView.swift Sources/CAMAssistantApp/AppModel.swift Sources/CAMAssistantApp/Views/AssistantWindow.swift Tests/CAMAssistantAppTests/HomePresentationTests.swift
git commit -m "feat: add a plain-language memory Home"
```

### Task 4: Prove Friendly Capture Status and Recovery

**Files:**
- Create: `Sources/CAMAssistantApp/Presentation/UserFacingIssue.swift`
- Create: `Tests/CAMAssistantAppTests/CaptureUserExperienceTests.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/HomeView.swift`
- Modify: `Sources/CAMAssistantApp/Capture/WatchedSourceCaptureRefresh.swift`
- Test: `Tests/CAMAssistantAppTests/WatchedSourceRefreshTests.swift`
- Test: `Tests/CAMAssistantCoreTests/IngestTests.swift`

**Step 1: Write the failing tests**

Cover exact primary states:

```swift
#expect(CaptureNotice.saved("Meeting Notes.txt").message ==
    "Saved Meeting Notes.txt to your Library.")
#expect(CaptureNotice.alreadySaved("Meeting Notes.txt").message ==
    "Meeting Notes.txt is already in your Library.")
#expect(CaptureNotice.failed.canRetry)
#expect(CaptureNotice.failed.contentSafetyMessage ==
    "Your original content was not changed.")
```

Verify watched-source failure never disappears into an empty catch and that a
late completion cannot overwrite a newer user-visible state.

**Step 2: Run tests to verify failure**

Run: `/bin/zsh scripts/verify.sh app`
Expected: FAIL for missing `CaptureNotice`/`UserFacingIssue`.

**Step 3: Implement the minimal user-facing mapping**

Map stable internal outcomes to friendly copy. Keep technical codes under a
Details disclosure. Preserve existing status-only audit and never interpolate
raw error descriptions into primary text.

**Step 4: Run focused verification**

Run: `/bin/zsh scripts/verify.sh app`
Expected: PASS.

Run: `/bin/zsh scripts/verify.sh ingest`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CAMAssistantApp/Presentation/UserFacingIssue.swift Sources/CAMAssistantApp/AppModel.swift Sources/CAMAssistantApp/Views/HomeView.swift Sources/CAMAssistantApp/Capture/WatchedSourceCaptureRefresh.swift Tests/CAMAssistantAppTests/CaptureUserExperienceTests.swift Tests/CAMAssistantAppTests/WatchedSourceRefreshTests.swift
git commit -m "feat: explain capture outcomes in ordinary language"
```

### Task 5: Make Library Rows Recognizable and Searchable

**Files:**
- Create: `Sources/CAMAssistantApp/Presentation/LibraryItemPresentation.swift`
- Create: `Tests/CAMAssistantAppTests/LibraryUserExperienceTests.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/LibraryView.swift`
- Modify only if required for source data: `Sources/CAMAssistantCore/Ingest/IngestQueue.swift`

**Step 1: Write failing presentation tests**

```swift
@Test("Library prefers a recognizable source name over immutable identity")
func friendlyTitle() {
    let row = LibraryItemPresentation.fixture(
        sourceName: "Meeting Notes.txt",
        immutableID: String(repeating: "a", count: 64)
    )
    #expect(row.title == "Meeting Notes")
    #expect(row.primaryText != row.immutableID)
}

@Test("Library search matches title and preview without exposing hidden items")
func friendlySearch() {
    let results = LibraryFilter(query: "database").apply(to: .fixtures)
    #expect(results.map(\.title) == ["Architecture Decision"])
    #expect(results.allSatisfy(\.isVisible))
}
```

Add cases for Clipboard, missing filename, code, image, audio, and repeated
captures. Require stable date formatting and VoiceOver labels.

**Step 2: Run tests to verify failure**

Run: `/bin/zsh scripts/verify.sh app`
Expected: FAIL because friendly presentation and filtering are absent.

**Step 3: Implement friendly rows and progressive disclosure**

Primary row:

```text
Meeting Notes
Text · Saved today
We decided to keep the local database because...
```

Details contains immutable source ID, citation passage, extractor, SHA-256,
capture origin, and exact timestamp. Add a native searchable field and simple
type filter. Preserve Hide/Restore and raw-source verification.

**Step 4: Run verification**

Run: `/bin/zsh scripts/verify.sh app`
Expected: PASS.

Run: `/bin/zsh scripts/verify.sh storage`
Expected: PASS.

Run: `/bin/zsh scripts/verify.sh retrieval`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CAMAssistantApp/Presentation/LibraryItemPresentation.swift Sources/CAMAssistantApp/AppModel.swift Sources/CAMAssistantApp/Views/LibraryView.swift Sources/CAMAssistantCore/Ingest/IngestQueue.swift Tests/CAMAssistantAppTests/LibraryUserExperienceTests.swift
git commit -m "feat: make the Library recognizable and searchable"
```

### Task 6: Provide One Local Ask Path

**Files:**
- Create: `Sources/CAMAssistantCore/Conversation/LocalAnswerCoordinator.swift`
- Create: `Tests/CAMAssistantCoreTests/LocalAnswerCoordinatorTests.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/HomeView.swift`
- Test: `Tests/CAMAssistantCoreTests/ConversationTests.swift`
- Test: `Tests/CAMAssistantCoreTests/LocalModelInferenceTests.swift`

**Step 1: Write failing orchestration tests**

```swift
@Test("healthy selected model produces one cited local answer")
func healthyModelPath() async throws {
    let result = try await fixtureCoordinator(model: .healthy).answer("Why local?")
    #expect(result.mode == .localAI)
    #expect(!result.citations.isEmpty)
}

@Test("missing model returns local matches and never contacts another route")
func modelFreePath() async throws {
    let spy = OutboundTransportSpy()
    let result = try await fixtureCoordinator(model: .unavailable, outbound: spy)
        .answer("Why local?")
    #expect(result.mode == .matchingPassages)
    #expect(spy.requestCount == 0)
}

@Test("unsupported local evidence abstains")
func unsupportedQuestion() async throws {
    let result = try await fixtureCoordinator(model: .healthy).answer("Unknown")
    #expect(result.mode == .notEnoughInformation)
}
```

**Step 2: Run tests to verify failure**

Run: `swift test --disable-sandbox --scratch-path .swift-build --filter LocalAnswerCoordinatorTests`
Expected: FAIL because the coordinator does not exist.

**Step 3: Implement the minimal coordinator**

Order:

1. deterministic local retrieval;
2. no-evidence abstention;
3. selected loopback model only when healthy;
4. deterministic citation validation;
5. matching-passage result when model is unavailable;
6. no web/cloud/CAM fallback.

Return a user-facing mode plus a separate Details payload. Keep current routing
and privacy types underneath; do not expose them as Home controls.

**Step 4: Run verification**

Run: `/bin/zsh scripts/verify.sh conversation`
Expected: PASS.

Run: `/bin/zsh scripts/verify.sh models`
Expected: PASS.

Run: `/bin/zsh scripts/verify.sh privacy`
Expected: PASS with zero outbound bytes for restricted fixtures.

**Step 5: Commit**

```bash
git add Sources/CAMAssistantCore/Conversation/LocalAnswerCoordinator.swift Sources/CAMAssistantApp/AppModel.swift Sources/CAMAssistantApp/Views/HomeView.swift Tests/CAMAssistantCoreTests/LocalAnswerCoordinatorTests.swift Tests/CAMAssistantCoreTests/ConversationTests.swift Tests/CAMAssistantCoreTests/LocalModelInferenceTests.swift
git commit -m "feat: provide one trustworthy local Ask path"
```

### Task 7: Reduce Keep to a Reversible Memory Action

**Files:**
- Create: `Sources/CAMAssistantCore/Knowledge/KeptMemory.swift`
- Create: `Sources/CAMAssistantCore/Knowledge/KeptMemoryStore.swift`
- Create: `Tests/CAMAssistantCoreTests/KeptMemoryTests.swift`
- Modify: `Sources/CAMAssistantApp/AppModel.swift`
- Modify: `Sources/CAMAssistantApp/Views/HomeView.swift`
- Modify: `Sources/CAMAssistantCore/Storage/FullVaultBackup.swift`

**Step 1: Write failing memory tests**

```swift
@Test("Keep stores a concise cited memory rather than a transcript")
func keepMemory() throws {
    let memory = try fixtureStore.keep(answer: .supportedFixture)
    #expect(memory.text == .supportedFixture.text)
    #expect(memory.citations == .supportedFixture.citations)
    #expect(memory.conversationTranscript == nil)
}

@Test("discard leaves no durable answer")
func discardIsEphemeral() throws {
    let store = fixtureStore()
    store.discard(answerID: .fixture)
    #expect(try store.all().isEmpty)
}

@Test("undo removes only the just-kept derived memory")
func undoKeep() throws {
    let receipt = try fixtureStore.keep(answer: .supportedFixture)
    try fixtureStore.undo(receipt: receipt.undoReceipt)
    #expect(try fixtureStore.all().isEmpty)
}
```

Add restart, duplicate candidate, update-existing, citation drift, stale Undo,
and backup/restore coverage.

**Step 2: Run tests to verify failure**

Run: `swift test --disable-sandbox --scratch-path .swift-build --filter KeptMemoryTests`
Expected: FAIL because the memory types do not exist.

**Step 3: Implement minimal Keep**

Keep persists a concise answer plus citations, source/version identity, created
time, and an undo receipt. A deterministic similarity candidate may offer
Update existing or Save separately; it must not silently merge. Hide Task,
Fact, and Assumption classifications under More Options until later evidence
earns them.

**Step 4: Run verification**

Run: `/bin/zsh scripts/verify.sh knowledge`
Expected: PASS.

Run: `/bin/zsh scripts/verify.sh backup`
Expected: PASS including kept-memory restore.

Run: `/bin/zsh scripts/verify.sh app`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CAMAssistantCore/Knowledge/KeptMemory.swift Sources/CAMAssistantCore/Knowledge/KeptMemoryStore.swift Sources/CAMAssistantCore/Storage/FullVaultBackup.swift Sources/CAMAssistantApp/AppModel.swift Sources/CAMAssistantApp/Views/HomeView.swift Tests/CAMAssistantCoreTests/KeptMemoryTests.swift
git commit -m "feat: make Keep a reversible cited memory action"
```

### Task 8: Simplify Settings With Progressive Disclosure

**Files:**
- Create: `Sources/CAMAssistantApp/Views/BarebonesSettingsView.swift`
- Create: `Tests/CAMAssistantAppTests/BarebonesSettingsTests.swift`
- Modify: `Sources/CAMAssistantApp/Views/AssistantWindow.swift`
- Modify: `Sources/CAMAssistantApp/Views/ModelProfilesView.swift`
- Modify: `Sources/CAMAssistantApp/Views/CaptureSourcesView.swift`
- Modify: `Sources/CAMAssistantApp/Views/BackupRecoveryView.swift`

**Step 1: Write failing settings contracts**

Require four groups: Capture, Local AI, Backup & Restore, Advanced. Verify the
collapsed primary presentation contains no endpoint editor, API key,
OpenRouter, route role, manifest, or raw identifier. Verify Advanced preserves
needed local diagnostics without enabling experimental authority.

```swift
@Test("ordinary Settings has four friendly groups")
func friendlySettingsGroups() {
    #expect(BarebonesSettingsSection.allCases ==
        [.capture, .localAI, .backupRestore, .advanced])
}
```

**Step 2: Run tests to verify failure**

Run: `/bin/zsh scripts/verify.sh app`
Expected: FAIL because `BarebonesSettingsView` does not exist.

**Step 3: Implement minimal Settings**

- Capture shows shortcut and watched folders.
- Local AI shows Detected / Not running / Ready, one model picker, and one
  “Check Again” action.
- Backup & Restore reuses the proven bounded controls with plain explanations.
- Advanced contains endpoint editing and technical diagnostics.
- OpenRouter is absent from primary mode.

**Step 4: Run verification**

Run: `/bin/zsh scripts/verify.sh app`
Expected: PASS.

Run: `/bin/zsh scripts/verify.sh models`
Expected: PASS.

Run: `/bin/zsh scripts/verify.sh backup`
Expected: PASS.

**Step 5: Commit**

```bash
git add Sources/CAMAssistantApp/Views/BarebonesSettingsView.swift Sources/CAMAssistantApp/Views/AssistantWindow.swift Sources/CAMAssistantApp/Views/ModelProfilesView.swift Sources/CAMAssistantApp/Views/CaptureSourcesView.swift Sources/CAMAssistantApp/Views/BackupRecoveryView.swift Tests/CAMAssistantAppTests/BarebonesSettingsTests.swift
git commit -m "feat: make Settings friendly by default"
```

### Task 9: Prove the Complete Barebones Journey

**Files:**
- Create: `Tests/ReleaseProofTests/barebones-packaged-journey-tests.sh`
- Create: `docs/evidence/barebones-packaged-journey.md`
- Create: `docs/pilots/barebones-general-user-protocol.md`
- Modify: `scripts/verify.sh`
- Modify: `docs/VERIFICATION_REPORT.md`
- Modify: `PROGRESS.md`
- Modify: `TASK_QUEUE.md`

**Step 1: Write the failing packaged journey**

Use an isolated application-support root and assert:

1. fresh launch exposes Home, Library, Settings only;
2. Home contains no banned technical terms;
3. Save Clipboard creates one recognizable Library item;
4. second save reports Already in your Library;
5. quit/relaunch preserves it;
6. Ask opens a cited source or shows model-free matching passages;
7. Keep survives restart and Undo is exact;
8. backup validates and restores into a fresh root;
9. restored watched folders are paused;
10. no network request occurs in the model-free journey.

**Step 2: Run the journey to verify it fails**

Run: `/bin/zsh Tests/ReleaseProofTests/barebones-packaged-journey-tests.sh`
Expected: FAIL at the first unmet shell or journey assertion.

**Step 3: Fix only observed journey failures**

Do not add unrelated features. Record every changed behavior in the evidence
receipt. A GUI automation limitation remains an honest red/partial result; do
not replace it with a source-only claim.

**Step 4: Run complete verification**

Run: `/bin/zsh scripts/verify.sh barebones-packaged`
Expected: PASS.

Run: `CAM_ASSISTANT_SKIP_FRESH_CLONE=1 /bin/zsh scripts/verify.sh all`
Expected: PASS with zero test failures, release build, package reproducibility,
package identity, and privacy scan green.

Run: `/bin/zsh scripts/verify.sh fresh-clone`
Expected: PASS from an exact clean commit.

Run: `git diff --check`
Expected: no output and exit 0.

**Step 5: Prepare human validation without claiming it**

Write a short protocol for a general non-developer:

- save one clipboard item;
- add one watched folder;
- find one item;
- ask one supported and one unsupported question;
- inspect a source;
- Keep and Undo;
- create and explain a backup;
- answer “Did anything go online?” and “Where is my content?”

Agent evidence cannot satisfy the human gate.

**Step 6: Commit**

```bash
git add Tests/ReleaseProofTests/barebones-packaged-journey-tests.sh docs/evidence/barebones-packaged-journey.md docs/pilots/barebones-general-user-protocol.md scripts/verify.sh docs/VERIFICATION_REPORT.md PROGRESS.md TASK_QUEUE.md
git commit -m "test: prove the packaged barebones memory journey"
```

## Stop Rules

- Stop after each task until its focused tests pass.
- Do not weaken an existing privacy, storage, recovery, or authority test.
- Do not delete specialist code during this plan.
- Do not expose a specialist workspace to solve a primary UX problem.
- Do not add cloud, web, CAM, Mac Care, repository semantics, modules, or
  Meaning Preview to primary navigation.
- Do not proceed past Task 5 if a fresh user still sees technical identifiers
  as primary Library labels.
- Do not proceed past Task 6 without explicit no-network model-free proof.
- Do not claim completion without the packaged journey and human gate.
