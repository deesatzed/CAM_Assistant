import CAMAssistantCore
import SwiftUI

struct LibraryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(model.libraryPresentation.documentCount) indexed local sources").font(.title3)
                Spacer()
                Button("Refresh", action: model.reloadLibrary).disabled(model.isRefreshingWorkspace)
            }
            if model.isRefreshingWorkspace { ProgressView("Refreshing local library") }
            if model.libraryPresentation.documentCount == 0 {
                ContentUnavailableView("Your local library is empty", systemImage: "books.vertical", description: Text("Capture the clipboard or index a selected repository to add local sources."))
            } else {
                ForEach(DocumentModality.allCases, id: \.self) { modality in
                    if let count = model.libraryPresentation.modalityCounts[modality], count > 0 { LabeledContent(modality.rawValue.capitalized, value: "\(count)") }
                }
                Divider()
                Text("Local sources").font(.headline)
                ForEach(model.libraryPresentation.rows) { row in
                    Button {
                        model.selectedLibrarySourceID = row.id
                    } label: {
                        HStack {
                            Text(row.modalityLabel)
                            Text(row.id).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(row.captures.count) \(row.captures.count == 1 ? "capture" : "captures")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open local \(row.modalityLabel) source \(row.id)")
                }
                if let selectedID = model.selectedLibrarySourceID,
                   let row = model.libraryPresentation.rows.first(where: { $0.id == selectedID }) {
                    Divider()
                    Text("Source detail").font(.headline)
                    LabeledContent("Source ID", value: row.id)
                    LabeledContent("Citation passage", value: row.passageID)
                    LabeledContent("Modality", value: row.modalityLabel)
                    LabeledContent("Extractor", value: row.extractorID)
                    Text(row.preview)
                        .textSelection(.enabled)
                        .accessibilityLabel("Derived local text preview. \(row.preview)")
                    Text("Capture provenance").font(.subheadline)
                    ForEach(row.captures) { capture in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(capture.sourceName)
                            Text("\(capture.originLabel) · \(capture.contentType)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            if let error = model.libraryError { Text(error).foregroundStyle(.red) }
            if !model.knowledgeClaims.isEmpty {
                Divider(); Text("Kept local knowledge").font(.headline)
                ForEach(model.knowledgeClaims, id: \.id) { claim in Text("\(claim.kind.rawValue.capitalized): \(claim.statement)").font(.caption) }
                if model.knowledgeClaims.count >= 2 {
                    Divider(); Text("Record contradiction for review").font(.headline)
                    Picker("First position", selection: $model.contradictionLeftID) { Text("Choose").tag(""); ForEach(model.knowledgeClaims, id: \.id) { Text($0.statement).tag($0.id) } }
                    Picker("Second position", selection: $model.contradictionRightID) { Text("Choose").tag(""); ForEach(model.knowledgeClaims, id: \.id) { Text($0.statement).tag($0.id) } }
                    TextField("Steelman", text: $model.contradictionSteelman)
                    TextField("Bridge suggestion (optional)", text: $model.contradictionBridgeSuggestion)
                    Button("Keep Contradiction Candidate", action: model.keepContradictionCandidate)
                    if let error = model.knowledgeError { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            if !model.contradictionCandidates.isEmpty {
                Text("Unresolved contradiction candidates").font(.headline)
                ForEach(model.contradictionCandidates, id: \.id) { candidate in
                    Text("\(candidate.left.statement) ↔ \(candidate.right.statement)").font(.caption)
                }
            }
            Spacer()
        }.padding().accessibilityLabel("Library. \(model.libraryPresentation.documentCount) indexed local sources.")
    }
}
