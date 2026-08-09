import CAMAssistantCore
import SwiftUI

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @State private var searchText = ""
    @State private var selectedType = "All"

    private var totalSavedCount: Int {
        model.libraryPresentation.documentCount + model.keptMemories.count
    }

    private var activeItems: [LibraryItemPresentation] {
        let items = model.libraryPresentation.rows.map(LibraryItemPresentation.init)
        return LibraryItemPresentation.filter(items, query: searchText)
            .filter { selectedType == "All" || $0.type == selectedType }
    }

    private var availableTypes: [String] {
        ["All"] + Set(
            model.libraryPresentation.rows.map(\.modalityLabel)
        ).sorted()
    }

    private var visibleKeptMemories: [KeptMemory] {
        guard selectedType == "All" else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.keptMemories }
        return model.keptMemories.filter {
            $0.text.localizedCaseInsensitiveContains(query)
                || $0.citations.contains {
                    $0.quote.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var selectedRow: LibrarySourceRow? {
        guard let selectedID = model.selectedLibrarySourceID else { return nil }
        return (model.libraryPresentation.rows + model.libraryPresentation.hiddenRows)
            .first { $0.id == selectedID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if model.isRefreshingWorkspace {
                    ProgressView("Refreshing your Library")
                }
                if totalSavedCount == 0 {
                    emptyState
                } else {
                    searchAndFilter
                    keptMemoryList
                    itemList
                }
                if let selectedRow {
                    itemDetail(selectedRow)
                }
                hiddenItems
                if let error = model.libraryError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Library. \(totalSavedCount) saved items.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Library")
                    .font(.largeTitle.bold())
                Text(
                    "\(totalSavedCount) "
                        + (totalSavedCount == 1
                            ? "saved item" : "saved items")
                )
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Refresh", action: model.reloadLibrary)
                .disabled(model.isRefreshingWorkspace)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing saved yet",
            systemImage: "books.vertical",
            description: Text("Use Save Clipboard on Home to add your first item.")
        )
    }

    private var searchAndFilter: some View {
        HStack {
            TextField("Search your Library", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search your Library")
            Picker("Type", selection: $selectedType) {
                ForEach(availableTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .frame(maxWidth: 180)
        }
    }

    @ViewBuilder
    private var itemList: some View {
        if activeItems.isEmpty && visibleKeptMemories.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if !activeItems.isEmpty {
            LazyVStack(spacing: 8) {
                ForEach(activeItems) { item in
                    Button {
                        model.selectLibrarySource(item.sourceID)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon(for: item.type))
                                .font(.title2)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(item.dateText) · \(item.type)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.preview.isEmpty ? "No preview available" : item.preview)
                                    .lineLimit(2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.accessibilityLabel)
                    .accessibilityHint("Opens this saved item")
                }
            }
        }
    }

    @ViewBuilder
    private var keptMemoryList: some View {
        if !visibleKeptMemories.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Kept answers").font(.headline)
                ForEach(visibleKeptMemories) { memory in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(memory.text)
                            .font(.headline)
                            .lineLimit(3)
                        Text(
                            "Kept \(memory.updatedAt.formatted(date: .abbreviated, time: .shortened))"
                                + " · \(memory.citations.count) "
                                + (memory.citations.count == 1 ? "source" : "sources")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        ForEach(
                            Array(memory.citations.enumerated()),
                            id: \.element.passageID
                        ) { index, citation in
                            Button("Show source in Library (\(index + 1))") {
                                model.openLibrarySource(for: citation)
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityElement(children: .contain)
                }
            }
        }
    }

    private func itemDetail(_ row: LibrarySourceRow) -> some View {
        let item = LibraryItemPresentation(row: row)
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Button("Close") {
                        model.clearLibrarySelection()
                    }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityHint("Hides this item detail and returns to the list.")
                }
                Text(item.preview.isEmpty ? "No preview available" : item.preview)
                    .textSelection(.enabled)
                DisclosureGroup("More about this item") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Type", value: item.type)
                        LabeledContent("Saved", value: item.dateText)
                        Button("Verify original is still on this Mac") {
                            model.inspectRawLibrarySource(row.id)
                        }
                        .disabled(model.isInspectingRawSource)
                        rawInspection(for: row)
                        provenance(row)
                        Button(row.lifecycleActionLabel) {
                            model.setLibrarySourceLifecycle(
                                row.lifecycle == .active ? .hidden : .active,
                                sourceID: row.id
                            )
                        }
                        .disabled(model.isUpdatingLibraryLifecycle)
                        DisclosureGroup("Technical identifiers") {
                            LabeledContent("Source ID", value: row.id)
                            LabeledContent("Citation passage", value: row.passageID)
                            LabeledContent("Extractor", value: row.extractorID)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func rawInspection(for row: LibrarySourceRow) -> some View {
        if model.isInspectingRawSource {
            ProgressView("Verifying the original source")
        }
        if let inspection = model.rawSourceInspection,
           inspection.sourceID.rawValue == row.id {
            LabeledContent("SHA-256", value: inspection.verifiedSHA256)
            LabeledContent("Size", value: "\(inspection.byteCount) bytes")
            LabeledContent("Original name", value: inspection.sourceName)
            if let preview = inspection.preview {
                Text(preview).textSelection(.enabled)
            } else {
                Text("This binary source cannot be shown as text.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func provenance(_ row: LibrarySourceRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Save history").font(.subheadline.bold())
            ForEach(row.captures) { capture in
                Text("\(capture.sourceName) · \(capture.originLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var hiddenItems: some View {
        if !model.libraryPresentation.hiddenRows.isEmpty {
            DisclosureGroup(
                "Hidden items (\(model.libraryPresentation.hiddenCount))"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hidden items are not included in search or answers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(model.libraryPresentation.hiddenRows) { row in
                        HStack {
                            Text(LibraryItemPresentation(row: row).title)
                            Spacer()
                            Button("Restore") {
                                model.setLibrarySourceLifecycle(.active, sourceID: row.id)
                            }
                            .disabled(model.isUpdatingLibraryLifecycle)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func icon(for type: String) -> String {
        switch type.lowercased() {
        case "image": "photo"
        case "audio": "waveform"
        case "code": "chevron.left.forwardslash.chevron.right"
        case "pdf": "doc.richtext"
        default: "doc.text"
        }
    }
}
