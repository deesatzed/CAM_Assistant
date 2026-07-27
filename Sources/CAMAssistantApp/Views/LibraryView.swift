import CAMAssistantCore
import SwiftUI

struct LibraryView: View {
    @ObservedObject var model: AppModel

    private var selectedRow: LibrarySourceRow? {
        guard let selectedID = model.selectedLibrarySourceID else {
            return nil
        }
        return (model.libraryPresentation.rows
            + model.libraryPresentation.hiddenRows)
            .first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(model.libraryPresentation.documentCount) active indexed local sources").font(.title3)
                Spacer()
                Button("Refresh", action: model.reloadLibrary).disabled(model.isRefreshingWorkspace)
            }
            if model.isRefreshingWorkspace { ProgressView("Refreshing local library") }
            if model.isUpdatingLibraryLifecycle {
                ProgressView("Updating local source visibility")
            }
            if model.libraryPresentation.documentCount == 0
                && model.libraryPresentation.hiddenCount == 0 {
                ContentUnavailableView("Your local library is empty", systemImage: "books.vertical", description: Text("Capture the clipboard or index a selected repository to add local sources."))
            } else {
                ForEach(DocumentModality.allCases, id: \.self) { modality in
                    if let count = model.libraryPresentation.modalityCounts[modality], count > 0 { LabeledContent(modality.rawValue.capitalized, value: "\(count)") }
                }
                Divider()
                Text("Local sources").font(.headline)
                ForEach(model.libraryPresentation.rows) { row in
                    Button {
                        model.selectLibrarySource(row.id)
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
                if let row = selectedRow {
                    Divider()
                    Text("Source detail").font(.headline)
                    LabeledContent("Source ID", value: row.id)
                    LabeledContent("Citation passage", value: row.passageID)
                    LabeledContent("Modality", value: row.modalityLabel)
                    LabeledContent("Extractor", value: row.extractorID)
                    LabeledContent(
                        "Visibility",
                        value: row.lifecycle.rawValue.capitalized
                    )
                    Text(row.preview)
                        .textSelection(.enabled)
                        .accessibilityLabel("Derived local text preview. \(row.preview)")
                    Button("Inspect Immutable Source") {
                        model.inspectRawLibrarySource(row.id)
                    }
                    .disabled(model.isInspectingRawSource)
                    .accessibilityHint(
                        "Verifies the local SHA-256 identity, then shows a bounded text preview or metadata only for binary content. It does not change the source."
                    )
                    if model.isInspectingRawSource {
                        ProgressView("Verifying immutable local source")
                    }
                    if let inspection = model.rawSourceInspection,
                       inspection.sourceID.rawValue == row.id {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Verified immutable source")
                                .font(.subheadline)
                            LabeledContent(
                                "SHA-256",
                                value: inspection.verifiedSHA256
                            )
                            LabeledContent(
                                "Bytes",
                                value: "\(inspection.byteCount)"
                            )
                            LabeledContent(
                                "Content type",
                                value: inspection.contentType
                            )
                            LabeledContent(
                                "Original name",
                                value: inspection.sourceName
                            )
                            if let preview = inspection.preview {
                                Text(preview)
                                    .textSelection(.enabled)
                                    .accessibilityLabel(
                                        "Verified bounded immutable source preview. \(preview)"
                                    )
                                if inspection.isPreviewTruncated {
                                    Text("Preview truncated at the local safety limit.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text(
                                    "Binary content is verified, but raw bytes are not rendered as text."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button(row.lifecycleActionLabel) {
                        model.setLibrarySourceLifecycle(
                            row.lifecycle == .active ? .hidden : .active,
                            sourceID: row.id
                        )
                    }
                    .disabled(model.isUpdatingLibraryLifecycle)
                    .accessibilityHint("Hides this derived source from Library citation navigation and local chat without deleting immutable source bytes or provenance.")
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
                if !model.libraryPresentation.hiddenRows.isEmpty {
                    Divider()
                    Text("Hidden local sources").font(.headline)
                    Text("Hidden sources remain in the immutable local vault and keep their provenance. Restore one to include it in Library citation navigation and local chat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(model.libraryPresentation.hiddenRows) { row in
                        HStack {
                            Button {
                                model.selectLibrarySource(row.id)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(row.modalityLabel)
                                    Text(row.id)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                "Open hidden local \(row.modalityLabel) source \(row.id)"
                            )
                            Spacer()
                            Button(row.lifecycleActionLabel) {
                                model.setLibrarySourceLifecycle(
                                    .active,
                                    sourceID: row.id
                                )
                            }
                            .disabled(model.isUpdatingLibraryLifecycle)
                            .accessibilityHint("Restores this immutable local source to Library citation navigation and local chat.")
                        }
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
        }.padding().accessibilityLabel("Library. \(model.libraryPresentation.documentCount) active and \(model.libraryPresentation.hiddenCount) hidden indexed local sources.")
    }
}
