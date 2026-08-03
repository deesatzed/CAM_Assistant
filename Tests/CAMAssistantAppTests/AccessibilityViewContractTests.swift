import Foundation
import Testing
@testable import CAMAssistantApp

@Test("workspace accessibility containers preserve child controls and empty states")
func workspaceAccessibilityContainersPreserveChildren() throws {
    let root = accessibilityRepositoryRoot()
    let workspaceContracts = [
        AccessibilitySourceContract(
            fileName: "LibraryView.swift",
            rootLabelPrefix: "Library.",
            requiredStateText: [
                "Your local library is empty",
                "Capture the clipboard or index a selected repository",
                "Button(\"Refresh\"",
            ]
        ),
        AccessibilitySourceContract(
            fileName: "TaskListView.swift",
            rootLabelPrefix: "Tasks.",
            requiredStateText: [
                "No saved tasks",
                "Keep a cited local answer",
                "Button(\"Refresh\"",
            ]
        ),
        AccessibilitySourceContract(
            fileName: "MacCareView.swift",
            rootLabelPrefix: "Mac Care.",
            requiredStateText: [
                "Mac Care is read-only",
                "Assess Standard Locations",
                "Any maintenance plan needs exact approval",
            ]
        ),
    ]

    for contract in workspaceContracts {
        let source = try String(
            contentsOf: root
                .appending(path: "Sources/CAMAssistantApp/Views")
                .appending(path: contract.fileName),
            encoding: .utf8
        )

        #expect(
            contract.isSatisfied(by: source),
            "\(contract.fileName) must preserve its required child controls and state descriptions beneath the labeled root container"
        )
    }
}

@Test("workspace accessibility contract rejects unrelated child containment")
func workspaceAccessibilityContractRejectsUnrelatedContainment() {
    let contract = AccessibilitySourceContract(
        fileName: "ExampleView.swift",
        rootLabelPrefix: "Example.",
        requiredStateText: ["Required empty state"]
    )
    let unrelatedContainment = """
    VStack {
        Text("Required empty state")
            .accessibilityElement(children: .contain)
    }
    .padding()
    .accessibilityLabel("Example. Empty.")
    """

    #expect(!contract.isSatisfied(by: unrelatedContainment))
}

@Test("modules workspace exposes an explicit no-authority lifecycle")
func modulesWorkspaceExposesExplicitLifecycle() throws {
    let root = accessibilityRepositoryRoot()
    let viewURL = root
        .appending(path: "Sources/CAMAssistantApp/Views/ModulesView.swift")
    #expect(
        FileManager.default.fileExists(atPath: viewURL.path),
        "The native app must contain a Modules workspace."
    )
    guard FileManager.default.fileExists(atPath: viewURL.path) else { return }
    let source = try String(contentsOf: viewURL, encoding: .utf8)
    let requiredContracts = [
        "Text(\"Packaged text summary\")",
        "Button(\"Install Packaged Module\"",
        "Button(\"Enable Module\"",
        "Button(\"Grant Local Text Access\"",
        "Button(\"Summarize Locally\"",
        "Button(\"Disable Module\"",
        "Button(\"Remove Module\"",
        "No network, shell command, downloaded code, or vault browsing",
        ".accessibilityElement(children: .contain)",
        "\"Modules. Trusted native module lifecycle",
    ]
    #expect(requiredContracts.allSatisfy(source.contains))
}

@Test("repository view exposes durable local job lifecycle without deletion authority")
func repositoryViewExposesDurableJobLifecycle() throws {
    let source = try String(
        contentsOf: accessibilityRepositoryRoot()
            .appending(path: "Sources/CAMAssistantApp/Views/RepositoryView.swift"),
        encoding: .utf8
    )

    let requiredContracts = [
        "Section(\"Recent repository jobs\")",
        "case .cancel:",
        "case .resume:",
        "model.cancelRepositoryJob(job.id)",
        "model.resumeRepositoryJob(job.id)",
        "preserves vault bytes, provenance, snapshots, jobs, and ideas",
        "Repository job \\(job.statusLabel)",
    ]

    #expect(
        requiredContracts.allSatisfy(source.contains),
        "RepositoryView must expose persistent status-only jobs, bounded actions, and non-destructive source removal"
    )
}

@Test("repository view exposes bounded ephemeral local model analysis and explicit retention")
func repositoryViewExposesBoundedSemanticAnalysis() throws {
    let source = try String(
        contentsOf: accessibilityRepositoryRoot()
            .appending(
                path: "Sources/CAMAssistantApp/Views/RepositoryView.swift"
            ),
        encoding: .utf8
    )

    let requiredContracts = [
        "Button(\"Analyze Repository Evidence Locally\"",
        "Button(\"Cancel Local Analysis\"",
        "Section(\"Ephemeral local-model candidate\")",
        "Section(\"Support evidence\")",
        "Section(\"Counterevidence\")",
        "LabeledContent(\"Model\"",
        "LabeledContent(\"Runtime\"",
        "TextField(\"Rejected alternative\"",
        "Button(\"Create Evidence-Complete Idea\"",
        "Nothing is retained until you explicitly Keep or choose a promotion action.",
        "No fallback, CAM call, repository write, or automatic retention",
    ]

    #expect(
        requiredContracts.allSatisfy(source.contains),
        "RepositoryView must expose model identity, both evidence roles, cancellation, and explicit retention without hidden authority"
    )
}

@Test("backup recovery view exposes bounded actions and no overwrite authority")
func backupRecoveryViewExposesBoundedNonDestructiveActions() throws {
    let source = try String(
        contentsOf: accessibilityRepositoryRoot()
            .appending(
                path: "Sources/CAMAssistantApp/Views/BackupRecoveryView.swift"
            ),
        encoding: .utf8
    )

    let requiredContracts = [
        "Button(\"Create Backup…\"",
        "Button(\"Validate Backup…\"",
        "\"Restore to New Vault…\"",
        "never overwrites or merges",
        "Restored watched folders remain paused",
        ".accessibilityElement(children: .contain)",
        "\"Backup and Recovery. Local integrity-checked packages",
    ]
    let forbiddenContracts = [
        "Overwrite Current Vault",
        "Merge Vault",
    ]

    #expect(requiredContracts.allSatisfy(source.contains))
    #expect(forbiddenContracts.allSatisfy { !source.contains($0) })
}

@Test("research view exposes exact acquisition and ephemeral packet review")
func researchViewExposesExactAcquisitionAndPacketReview() throws {
    let source = try String(
        contentsOf: accessibilityRepositoryRoot()
            .appending(
                path: "Sources/CAMAssistantApp/Views/ResearchView.swift"
            ),
        encoding: .utf8
    )
    let requiredContracts = [
        "TextField(\"Public HTTPS document URL\"",
        "Button(\"Prepare Public Document Acquisition\"",
        "Section(\"Exact public-document proposal\")",
        "LabeledContent(\"Target\"",
        "LabeledContent(\"Maximum response\"",
        "LabeledContent(\"Cost limit\"",
        "Button(\"Approve & Acquire\"",
        "Button(\"Cancel Acquisition\"",
        "Button(\"Review Ephemeral Packet\"",
        "Section(\"Ephemeral research packet\")",
        "LabeledContent(\"Route\"",
        "LabeledContent(\"Tool\"",
        "Source quality",
        "Untrusted content signals",
        "Button(\"Keep Packet\"",
        "Button(\"Discard Packet\"",
        "No provider search, browser automation, cookies, credentials, cloud model, CAM call, or automatic retention",
        ".accessibilityElement(children: .contain)",
        "\"Research. Bounded public document acquisition",
    ]

    let compactSource = source.filter { !$0.isWhitespace }
    #expect(
        requiredContracts.allSatisfy {
            compactSource.contains($0.filter { !$0.isWhitespace })
        },
        "ResearchView must expose one exact bounded acquisition and explicit ephemeral packet retention"
    )
}

@Test("CAM view exposes local runtime pinning and disposable probe without mining authority")
func camViewExposesRuntimePinningAndDisposableProbe() throws {
    let source = try String(
        contentsOf: accessibilityRepositoryRoot()
            .appending(
                path: "Sources/CAMAssistantApp/Views/CAMStatusView.swift"
            ),
        encoding: .utf8
    )
    let requiredContracts = [
        "Section(\"Selected runtime\")",
        "\"Select CAM Executable…\"",
        "\"Select Configuration…\"",
        "\"Select Database…\"",
        "Button(\"Pin Selected Runtime\"",
        "Button(\"Cancel Runtime Pin\"",
        "Button(\"Run Disposable Statistics Probe\"",
        "Button(\"Cancel Disposable Probe\"",
        "pinOperation.accepts(generation)",
        "probeOperation.accepts(generation)",
        "Section(\"Verified disposable receipt\")",
        "CAMRuntimeRestartStateStore.fileName",
        "restoreHistoricalRuntimeState()",
        "runtimePinIsCurrentSession",
        "\"Historical pinned identity\"",
        "\"Historical receipt\"",
        "\"Re-pin this runtime before running another probe.\"",
        "try store.save(pin: pin)",
        "try store.save(receipt: result, for: pin)",
        "The donor database is never passed to CAM",
        "after native inspection",
        "Mining, provider calls, MCP serving, and personal-corpus mutation remain disabled.",
        ".accessibilityElement(children: .contain)",
        "\"CAM. Local runtime pinning and disposable read-only inspection",
    ]

    #expect(
        requiredContracts.allSatisfy(source.contains),
        "CAMStatusView must expose explicit pinning and copied-state inspection without implying mining authority"
    )
}

@Test("CAM view exposes the closed statistics executor with cancellation and no mining control")
func camViewExposesClosedStatisticsExecutor() throws {
    let source = try String(
        contentsOf: accessibilityRepositoryRoot()
            .appending(
                path: "Sources/CAMAssistantApp/Views/CAMStatusView.swift"
            ),
        encoding: .utf8
    )
    let requiredContracts = [
        "Button(\"Run Closed CAM Statistics Tool\"",
        "Button(\"Cancel Closed CAM Statistics Tool\"",
        "CAMClosedToolExecutor().attempt(",
        "liveOperation.accepts(generation)",
        "Section(\"Closed statistics receipt\")",
        "interruptedClosedRuns",
        "loadInterruptedClosedRuns()",
        "CAMClosedToolExecutor.interruptedRuns(",
        "Section(\"Interrupted closed CAM runs\")",
        "This does not resume or clean up the earlier process.",
        "Mining, provider calls, MCP serving, and personal-corpus mutation remain disabled.",
    ]

    #expect(
        requiredContracts.allSatisfy(source.contains),
        "CAMStatusView must expose the one closed disposable tool, its cancellation state, and no mining authority"
    )
}

@Test("CAM operation lifecycle rejects stale completion and resets on disappearance")
func camOperationLifecycleRejectsStaleCompletionAndResets() {
    var lifecycle = CAMOperationLifecycleState()
    let stalePin = lifecycle.begin()
    #expect(lifecycle.isRunning)

    lifecycle.invalidate()
    #expect(!lifecycle.isRunning)
    #expect(!lifecycle.accepts(stalePin))

    let currentPin = lifecycle.begin()
    #expect(lifecycle.accepts(currentPin))
    lifecycle.finish(currentPin)
    #expect(!lifecycle.isRunning)

    let disappearingProbe = lifecycle.begin()
    lifecycle.invalidate()
    #expect(!lifecycle.isRunning)
    #expect(!lifecycle.accepts(disappearingProbe))
}

@Test("CAM runtime selection rows preserve every file picker for accessibility")
func camRuntimeSelectionRowsPreservePickerControls() throws {
    let source = try String(
        contentsOf: accessibilityRepositoryRoot()
            .appending(
                path: "Sources/CAMAssistantApp/Views/CAMStatusView.swift"
            ),
        encoding: .utf8
    )
    guard let rowStart = source.range(of: "private func selectionRow("),
          let rowEnd = source.range(
              of: "@ViewBuilder\n    private func receiptDetails",
              range: rowStart.upperBound..<source.endIndex
          ) else {
        Issue.record("CAM selection-row implementation was not found")
        return
    }
    let selectionRow = String(source[rowStart.lowerBound..<rowEnd.lowerBound])

    #expect(selectionRow.contains(".accessibilityElement(children: .contain)"))
    #expect(
        selectionRow.contains(
            ".accessibilityLabel(\"\\(title) runtime selection\")"
        )
    )
}

@Test("Meaning Preview native surfaces expose the explicit pilot journey")
func meaningPreviewSurfacesExposeExplicitPilotJourney() throws {
    let views = accessibilityRepositoryRoot()
        .appending(path: "Sources/CAMAssistantApp/Views")
    let requiredFiles = [
        "MeaningPreviewView.swift",
        "MeaningInspectView.swift",
        "MeaningPreviewSettingsView.swift",
    ]
    #expect(requiredFiles.allSatisfy {
        FileManager.default.fileExists(atPath: views.appending(path: $0).path)
    })
    guard requiredFiles.allSatisfy({
        FileManager.default.fileExists(atPath: views.appending(path: $0).path)
    }) else { return }

    let workspace = try String(
        contentsOf: views.appending(path: "MeaningPreviewView.swift"),
        encoding: .utf8
    )
    let inspect = try String(
        contentsOf: views.appending(path: "MeaningInspectView.swift"),
        encoding: .utf8
    )
    let settings = try String(
        contentsOf: views.appending(path: "MeaningPreviewSettingsView.swift"),
        encoding: .utf8
    )
    let workspaceContracts = [
        "meaning-preview-workspace", "meaning-preview-source-picker",
        "meaning-preview-request", "meaning-preview-card",
        "meaning-preview-inspect", "meaning-preview-now",
        "meaning-preview-later", "meaning-preview-release",
        "meaning-preview-helpful", "meaning-preview-not-helpful",
        "meaning-preview-disable", "meaning-preview-status",
        "Inspect exclusions", "Nothing practical surfaced", "Preview",
    ]
    #expect(workspaceContracts.allSatisfy(workspace.contains))
    let inspectContracts = [
        "meaning-preview-inspect-sheet", "Evidence record identifiers",
        "Counterevidence record identifiers", "Provenance", "Uncertainty",
        "Why this surfaced", "Excluded context", "No private chain-of-thought",
    ]
    #expect(inspectContracts.allSatisfy(inspect.contains))
    let settingsContracts = [
        "meaning-preview-settings", "meaning-preview-enable",
        "meaning-preview-settings-disable",
        "meaning-preview-enable-control",
        "meaning-preview-settings-needs-workspace-grant",
        "meaning-preview-settings-close",
        "meaning-preview-recover", "Enablement grants no data access",
        "local read and isolated write access",
        "Ordinary Assistant remains unchanged", "corrupted", "incompatible",
        "use Grant in the Meaning Preview workspace",
    ]
    #expect(settingsContracts.allSatisfy(settings.contains))
    #expect(
        !settings.contains("accessibilityIdentifier(\"meaning-preview-grant\")"),
        "Settings must not host Grant; grant is workspace-only to prevent Enable AX double-activation."
    )

    let workspaceDisable = try #require(
        workspace.range(of: "Button(\"Disable\")")
    )
    let workspaceDisableEnd = try #require(
        workspace.range(
            of: "meaning-preview-disable",
            range: workspaceDisable.lowerBound..<workspace.endIndex
        )
    )
    #expect(
        !workspace[workspaceDisable.lowerBound..<workspaceDisableEnd.upperBound]
            .contains(".disabled")
    )
    let settingsDisable = try #require(
        settings.range(of: "Button(\"Disable Meaning Preview\"")
    )
    let settingsDisableEnd = try #require(
        settings.range(
            of: "meaning-preview-settings-disable",
            range: settingsDisable.lowerBound..<settings.endIndex
        )
    )
    #expect(
        !settings[settingsDisable.lowerBound..<settingsDisableEnd.upperBound]
            .contains(".disabled")
    )
}

@Test("Meaning Preview is conditionally navigable and uses no authored motion")
func meaningPreviewIsConditionalAndReducedMotionSafe() throws {
    let views = accessibilityRepositoryRoot()
        .appending(path: "Sources/CAMAssistantApp/Views")
    let sidebar = try String(
        contentsOf: views.appending(path: "Sidebar.swift"),
        encoding: .utf8
    )
    let window = try String(
        contentsOf: views.appending(path: "AssistantWindow.swift"),
        encoding: .utf8
    )
    let preview = try String(
        contentsOf: views.appending(path: "MeaningPreviewView.swift"),
        encoding: .utf8
    )
    #expect(sidebar.contains("meaningPreviewVisible"))
    #expect(sidebar.contains("filter"))
    #expect(sidebar.contains("meaning-preview-sidebar"))
    #expect(window.contains("if model.isMeaningPreviewVisible"))
    #expect(window.contains("MeaningPreviewSettingsView"))
    #expect(window.contains("MeaningPreviewView"))
    for forbiddenMotion in [
        "withAnimation", ".animation(", "matchedGeometryEffect",
        "symbolEffect", "contentTransition",
    ] {
        #expect(!(sidebar + window + preview).contains(forbiddenMotion))
    }
}

@Test("sidebar accessibility identifiers are stable lowercase slugs")
func sidebarAccessibilityIdentifiersAreStableLowercaseSlugs() throws {
    let source = try String(
        contentsOf: accessibilityRepositoryRoot()
            .appending(path: "Sources/CAMAssistantApp/Views/Sidebar.swift"),
        encoding: .utf8
    )
    let requiredIdentifiers = [
        "assistant-section-assistant", "meaning-preview-sidebar",
        "assistant-section-library", "assistant-section-activity",
        "assistant-section-tasks", "assistant-section-modules",
        "assistant-section-cam", "assistant-section-research",
        "assistant-section-repositories", "assistant-section-mac-care",
        "assistant-section-settings",
    ]
    #expect(requiredIdentifiers.allSatisfy(source.contains))
    #expect(source.contains("section.accessibilityIdentifier"))
    #expect(!source.contains("assistant-section-\\(section.id.rawValue)"))
}

@Test("Meaning Preview package and pilot verifier require embedded resources")
func meaningPreviewPackageAndPilotVerifierRequireEmbeddedResources() throws {
    let root = accessibilityRepositoryRoot()
    let packageScript = try String(
        contentsOf: root.appending(path: "scripts/package-app.sh"),
        encoding: .utf8
    )
    let verifyScript = try String(
        contentsOf: root.appending(path: "scripts/verify.sh"),
        encoding: .utf8
    )
    let requiredPackageContracts = [
        "Contents/Resources/Modules/Core",
        "Modules/Core/meaning-preview.json",
        "\"$APP_DIR/CAMAssistant_CAMAssistantCore.bundle\"",
        "Contents/Resources/MeaningPreview",
        "docs/evidence/add2cam-09-named-model-report.json",
        "git -C \"$ROOT\" ls-files --error-unmatch",
    ]
    #expect(
        requiredPackageContracts.allSatisfy(packageScript.contains),
        "The app package must carry exact committed Meaning Preview resources without a source/build-tree runtime fallback."
    )
    #expect(
        !packageScript.contains(
            "\"$RESOURCES_DIR/CAMAssistant_CAMAssistantCore.bundle\""
        ),
        "SwiftPM Bundle.module resolves the core resource bundle at the app root, not Contents/Resources."
    )
    #expect(
        verifyScript.contains("meaning-preview-packaged)")
            && verifyScript.contains(
                "meaning-preview-packaged-journey-tests.sh"
            ),
        "The GUI-sensitive packaged pilot must remain an explicit suite separate from aggregate verification."
    )
}

@Test("Meaning Preview packaged journey preserves the native safety boundary")
func meaningPreviewPackagedJourneyPreservesNativeSafetyBoundary() throws {
    let journeyURL = accessibilityRepositoryRoot().appending(
        path: "Tests/ReleaseProofTests/meaning-preview-packaged-journey-tests.sh"
    )
    #expect(FileManager.default.fileExists(atPath: journeyURL.path))
    guard FileManager.default.fileExists(atPath: journeyURL.path) else {
        return
    }
    let journey = try String(contentsOf: journeyURL, encoding: .utf8)
    let requiredContracts = [
        "pgrep -x CAMAssistant",
        "git clone --quiet --local --no-hardlinks",
        "[[ -d \"$CLONE_ROOT/.git\" ]]",
        "open -n \"$PILOT_APP\" --env",
        "CAM_ASSISTANT_APPLICATION_SUPPORT_ROOT=$SUPPORT_ROOT",
        "chmod 000 \"$BUILD_DIR\"",
        "chmod 000 \"$SOURCE_MANIFEST_DIRECTORY\"",
        "alarm shift; exec @ARGV",
        "AXIsProcessTrusted()",
        "AXUIElementCreateApplication",
        "kAXChildrenAttribute",
        "AXUIElementPerformAction",
        "AXUIElementIsAttributeSettable",
        "kAXSelectedAttribute",
        "selectSidebar(\"assistant-section-settings\")",
        "selectSidebar(\"meaning-preview-sidebar\")",
        "waitAbsent(\"meaning-preview-settings\")",
        "within: \"meaning-preview-permission-state\"",
        "native_ax_phase capture",
        "native_ax_phase enable",
        "wait_for_enabled_without_access",
        "enable-granted-access",
        "watched-sources.json",
        "Thread.sleep(forTimeInterval: 1)",
        "Watched folder captured and indexed content locally.",
        "CGPreflightPostEventAccess()",
        "kAXVisibleChildrenAttribute",
        "kAXRowsAttribute",
        "kAXContentsAttribute",
        "AXChildrenInNavigationOrder",
        "executableURL",
        "assert_ordinary_unchanged",
        "postflight_git_state",
        "[[ \"$table\" =~ '^[A-Za-z0-9_]+$' ]]",
        "meaning-preview-sidebar",
        "meaning-preview-enable",
        "meaning-preview-grant",
        "meaning-preview-source-picker",
        "meaning-preview-request",
        "meaning-preview-inspect",
        "meaning-preview-disable",
        "meaning-preview-reflect-unavailable",
        "readLocal",
        "writeLocal",
        "outbound_byte_count",
        "/usr/sbin/lsof -nP -a -p",
        "exit 77",
    ]
    #expect(requiredContracts.allSatisfy(journey.contains))
    #expect(!journey.contains("kill "))
    #expect(!journey.contains("pkill"))
    #expect(!journey.contains("tccutil"))
    #expect(!journey.contains("codesign"))
    #expect(!journey.contains("CAM_ASSISTANT_SKIP_FRESH_CLONE"))
    #expect(!journey.contains("tell application \"System Events\""))
    #expect(!journey.contains("NSPasteboard"))
    #expect(!journey.contains("capture-sources-pane"))
    #expect(!journey.contains("Watching locally"))
    #expect(!journey.contains("[A-Za-z0-9_]##"))
    #expect(
        !journey.contains(
            "BUILD_DIR=\"$REPOSITORY_ROOT/.swift-build\""
        )
    )
    #expect(
        !journey.contains(
            "SOURCE_MANIFEST_DIRECTORY=\"$REPOSITORY_ROOT/Modules/Core\""
        )
    )
}

private struct AccessibilitySourceContract {
    let fileName: String
    let rootLabelPrefix: String
    let requiredStateText: [String]

    func isSatisfied(by source: String) -> Bool {
        let rootChain = """
        .padding()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(rootLabelPrefix)
        """

        return source.contains(rootChain)
            && requiredStateText.allSatisfy(source.contains)
    }
}

private func accessibilityRepositoryRoot() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
