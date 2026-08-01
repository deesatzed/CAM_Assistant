import Foundation
import Testing

@Test("Meaning Preview native surfaces expose the complete explicit pilot journey")
func meaningPreviewSurfacesExposeExplicitPilotJourney() throws {
    let root = meaningPreviewRepositoryRoot()
    let views = root.appending(path: "Sources/CAMAssistantApp/Views")
    let requiredFiles = [
        "MeaningPreviewView.swift",
        "MeaningInspectView.swift",
        "MeaningPreviewSettingsView.swift",
    ]

    for fileName in requiredFiles {
        #expect(
            FileManager.default.fileExists(
                atPath: views.appending(path: fileName).path
            ),
            "Missing native Meaning Preview surface: \(fileName)"
        )
    }

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
        "meaning-preview-workspace",
        "meaning-preview-source-picker",
        "meaning-preview-request",
        "meaning-preview-card",
        "meaning-preview-inspect",
        "meaning-preview-now",
        "meaning-preview-later",
        "meaning-preview-release",
        "meaning-preview-helpful",
        "meaning-preview-not-helpful",
        "meaning-preview-disable",
        "meaning-preview-status",
        "Nothing practical surfaced",
        "Preview",
    ]
    #expect(workspaceContracts.allSatisfy(workspace.contains))

    let inspectContracts = [
        "meaning-preview-inspect-sheet",
        "Source evidence",
        "Counterevidence",
        "Provenance",
        "Uncertainty",
        "Why this surfaced",
        "Excluded context",
        "No private chain-of-thought",
    ]
    #expect(inspectContracts.allSatisfy(inspect.contains))

    let settingsContracts = [
        "meaning-preview-settings",
        "meaning-preview-enable",
        "meaning-preview-grant",
        "meaning-preview-settings-disable",
        "meaning-preview-recover",
        "Enablement grants no data access",
        "local read and isolated write access",
        "Ordinary Assistant remains unchanged",
    ]
    #expect(settingsContracts.allSatisfy(settings.contains))
}

@Test("Meaning Preview stays absent while disabled and uses no authored motion")
func meaningPreviewIsConditionalAndReducedMotionSafe() throws {
    let views = meaningPreviewRepositoryRoot()
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
    #expect(window.contains("model.isMeaningPreviewVisible"))
    #expect(window.contains("MeaningPreviewSettingsView"))
    #expect(window.contains("MeaningPreviewView"))

    let combined = sidebar + window + preview
    for forbiddenMotion in [
        "withAnimation",
        ".animation(",
        "matchedGeometryEffect",
        "symbolEffect",
        "contentTransition",
    ] {
        #expect(!combined.contains(forbiddenMotion))
    }
}

private func meaningPreviewRepositoryRoot() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
