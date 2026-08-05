import Foundation
import Testing
@testable import CAMAssistantApp

@Test("empty Home offers one primary capture action without technical language")
func emptyHomeCopyIsFriendly() {
    let value = HomePresentation.empty

    #expect(value.title == "Your private Library is empty")
    #expect(value.primaryActionTitle == "Save Clipboard")
    #expect(value.questionPrompt == "What are you looking for?")
    #expect(value.privacyNote == "Your saved content stays on this Mac.")
    #expect(!value.visibleText.localizedCaseInsensitiveContains("index"))
    #expect(!value.visibleText.localizedCaseInsensitiveContains("endpoint"))
    #expect(!value.visibleText.localizedCaseInsensitiveContains("provider"))
}

@Test("model absence preserves a useful local result")
func noModelFallbackCopyIsFriendly() {
    #expect(
        LocalAssistantAvailability.unavailable.explanation
            == "Local AI is not running, so CAM will show matching passages from your Library."
    )
}

@Test("primary Home exposes one Ask action and no provider controls")
func homeSourceHasOneAskPath() throws {
    let source = try String(
        contentsOf: homeRepositoryRoot()
            .appending(path: "Sources/CAMAssistantApp/Views/HomeView.swift"),
        encoding: .utf8
    )

    #expect(source.components(separatedBy: "Button(\"Ask\"").count - 1 == 1)
    #expect(source.contains("Save Clipboard"))
    #expect(source.contains("What are you looking for?"))

    let forbiddenUserFacingCopy = [
        "Ask locally",
        "Ask Selected Local Model",
        "Ask OpenRouter",
        "loopback",
        "provider",
        "schema",
        "passage ID",
        "ingest",
    ]
    #expect(forbiddenUserFacingCopy.allSatisfy { !source.contains($0) })
}

private func homeRepositoryRoot() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
