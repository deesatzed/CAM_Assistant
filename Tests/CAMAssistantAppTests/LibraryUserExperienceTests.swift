import Foundation
import Testing
@testable import CAMAssistantApp

@Test("Library items lead with a recognizable filename instead of an identifier")
func libraryItemUsesRecognizableFilename() {
    let item = LibraryItemPresentation(
        sourceID: String(repeating: "a", count: 64),
        sourceNames: ["Meeting Notes.txt"],
        capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        preview: "Decisions from the planning meeting.",
        type: "Text",
        extractorID: "plain-text-v1"
    )

    #expect(item.title == "Meeting Notes.txt")
    #expect(!item.primaryText.contains(item.sourceID))
    #expect(item.detailsText.contains(item.sourceID))
}

@Test("clipboard and unnamed captures still receive ordinary titles")
func libraryItemCreatesFallbackTitles() {
    let clipboard = LibraryItemPresentation(
        sourceID: "clipboard-id",
        sourceNames: ["Clipboard"],
        capturedAt: .distantPast,
        preview: "Call the dentist on Tuesday.",
        type: "Text",
        extractorID: "plain-text-v1"
    )
    let code = LibraryItemPresentation(
        sourceID: "code-id",
        sourceNames: ["  "],
        capturedAt: .distantPast,
        preview: "func save() {}",
        type: "Code",
        extractorID: "code-v1"
    )

    #expect(clipboard.title == "Clipboard note")
    #expect(code.title == "Saved code")
}

@Test("Library search covers title, preview, and type without exposing hidden rows")
func librarySearchUsesRecognizableFields() {
    let item = LibraryItemPresentation(
        sourceID: "source-id",
        sourceNames: ["Garden Plan.md"],
        capturedAt: .distantPast,
        preview: "Plant tomatoes beside basil.",
        type: "Text",
        extractorID: "markdown-v1"
    )

    #expect(item.matches("garden"))
    #expect(item.matches("tomatoes"))
    #expect(item.matches("text"))
    #expect(!item.matches("airfare"))
    #expect(LibraryItemPresentation.filter([item], query: "garden").count == 1)
    #expect(LibraryItemPresentation.filter([], query: "garden").isEmpty)
}

@Test("Library accessibility describes the item without reading its hash")
func libraryAccessibilityUsesHumanMeaning() {
    let item = LibraryItemPresentation(
        sourceID: "opaque-hash",
        sourceNames: ["Budget.pdf"],
        capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        preview: "The annual budget was approved.",
        type: "PDF",
        extractorID: "pdf-v1"
    )

    #expect(item.accessibilityLabel.contains("Budget.pdf"))
    #expect(item.accessibilityLabel.contains("PDF"))
    #expect(!item.accessibilityLabel.contains("opaque-hash"))
}
