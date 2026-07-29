import Foundation
import Testing

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
