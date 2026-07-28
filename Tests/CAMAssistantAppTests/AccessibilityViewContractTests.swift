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
