import CAMAssistantCore
import Foundation

struct LibraryItemPresentation: Equatable, Identifiable {
    let sourceID: String
    let title: String
    let capturedAt: Date
    let dateText: String
    let preview: String
    let type: String
    let extractorID: String

    var id: String { sourceID }

    init(
        sourceID: String,
        sourceNames: [String],
        capturedAt: Date,
        preview: String,
        type: String,
        extractorID: String
    ) {
        self.sourceID = sourceID
        title = Self.title(sourceNames: sourceNames, type: type)
        self.capturedAt = capturedAt
        dateText = capturedAt.formatted(
            .dateTime.month(.abbreviated).day().year().hour().minute()
        )
        self.preview = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.extractorID = extractorID
    }

    init(row: LibrarySourceRow) {
        self.init(
            sourceID: row.id,
            sourceNames: row.captures.map(\.sourceName),
            capturedAt: row.capturedAt,
            preview: row.preview,
            type: row.modalityLabel,
            extractorID: row.extractorID
        )
    }

    var primaryText: String {
        [title, dateText, preview, type].joined(separator: " ")
    }

    var detailsText: String {
        "Source ID: \(sourceID) Extractor: \(extractorID)"
    }

    var accessibilityLabel: String {
        "\(title), \(type), saved \(dateText). \(preview)"
    }

    func matches(_ query: String) -> Bool {
        let terms = query
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
        guard !terms.isEmpty else { return true }
        let searchable = primaryText.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return terms.allSatisfy(searchable.contains)
    }

    static func filter(
        _ items: [LibraryItemPresentation],
        query: String
    ) -> [LibraryItemPresentation] {
        items.filter { $0.matches(query) }
    }

    private static func title(sourceNames: [String], type: String) -> String {
        let names = sourceNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let recognizable = names.first(where: {
            $0.localizedCaseInsensitiveCompare("Clipboard") != .orderedSame
        }) {
            return URL(fileURLWithPath: recognizable).lastPathComponent
        }
        if names.contains(where: {
            $0.localizedCaseInsensitiveCompare("Clipboard") == .orderedSame
        }) {
            return "Clipboard note"
        }
        return "Saved \(type.lowercased())"
    }
}
