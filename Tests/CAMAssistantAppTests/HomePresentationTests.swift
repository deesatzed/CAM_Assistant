import CAMAssistantCore
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
    #expect(source.contains("DirectionStripView"))

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

@Test("Direction strip empty copy stays plain language")
func directionStripEmptyCopyIsFriendly() {
    let value = DirectionPresentation.empty
    #expect(value.isEmpty)
    #expect(value.peopleLine == "Who matters to you?")
    #expect(value.promiseLine == "One small promise this week?")
    #expect(!value.peopleLine.localizedCaseInsensitiveContains("entity"))
    #expect(!value.northStarLine.localizedCaseInsensitiveContains("endpoint"))
}

@Test("Direction strip lists people and open promises")
func directionStripListsPeopleAndPromises() {
    let profile = DirectionProfile(
        people: [
            DirectionPerson(name: "Jordan", relation: "friend"),
            DirectionPerson(name: "Avery", relation: "partner"),
        ],
        promises: [
            DirectionPromise(text: "Call this week", toward: "Jordan"),
        ],
        northStar: "Be present"
    )
    let value = DirectionPresentation(profile: profile)
    #expect(!value.isEmpty)
    #expect(value.peopleLine.contains("Jordan"))
    #expect(value.peopleLine.contains("Avery"))
    #expect(value.promiseLine.contains("Call this week"))
    #expect(value.northStarLine.contains("Be present"))
}

@Test("local model labels hide path prefixes for ordinary pickers")
func localModelLabelsHidePathPrefixes() {
    #expect(
        LocalModelDisplayName.friendly("mlx-community/Llama-3.2-3B-Instruct-4bit")
            == "Llama-3.2-3B"
    )
    #expect(LocalModelDisplayName.friendly("qwen2.5") == "qwen2.5")
    #expect(
        HotkeySettingsView.normalizeKeyField("  C  ") == "c"
    )
    #expect(HotkeySettingsView.normalizeKeyField("space") == " ")
}

@Test("Direction strip exposes manage and done promise controls")
func directionStripSourceExposesManageAndDone() throws {
    let source = try String(
        contentsOf: homeRepositoryRoot()
            .appending(path: "Sources/CAMAssistantApp/Views/DirectionStripView.swift"),
        encoding: .utf8
    )
    #expect(source.contains("Manage"))
    #expect(source.contains("markDirectionPromiseDone"))
    #expect(source.contains("removeDirectionPerson"))
    #expect(source.contains("confirmationDialog"))
}

@Test("watched folders require confirm before remove")
func watchedFoldersRequireConfirmBeforeRemove() throws {
    let source = try String(
        contentsOf: homeRepositoryRoot()
            .appending(path: "Sources/CAMAssistantApp/Views/CaptureSourcesView.swift"),
        encoding: .utf8
    )
    #expect(source.contains("Remove…"))
    #expect(source.contains("confirmationDialog"))
    #expect(source.contains("Items already in your Library stay saved"))
}

private func homeRepositoryRoot() -> URL {
    URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
