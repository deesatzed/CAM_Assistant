import SwiftUI

struct MeaningInspectView: View {
    let presentation: MeaningPreviewInspectPresentation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Inspect Preview")
                    .font(.title2)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Text(presentation.summary)
                .textSelection(.enabled)

            Divider()
            evidenceSection(
                title: "Source evidence",
                identifiers: presentation.evidenceIDs,
                emptyText: "No supporting source identifiers were supplied."
            )
            evidenceSection(
                title: "Counterevidence",
                identifiers: presentation.counterevidenceIDs,
                emptyText: "No counterevidence identifiers were supplied."
            )
            LabeledContent("Provenance", value: presentation.provenanceLabel)
            LabeledContent("Uncertainty", value: presentation.uncertaintyLabel)
            LabeledContent("Why this surfaced", value: presentation.whySurfaced)

            if !presentation.exclusionLabels.isEmpty {
                LabeledContent(
                    "Excluded context",
                    value: presentation.exclusionLabels.joined(separator: ", ")
                )
            }

            Text("No private chain-of-thought is shown. Inspect reports bounded source identifiers, provenance, uncertainty, exclusions, and the policy reason for surfacing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 520, idealWidth: 620, minHeight: 430)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meaning Preview inspection")
        .accessibilityIdentifier("meaning-preview-inspect-sheet")
    }

    @ViewBuilder
    private func evidenceSection(
        title: String,
        identifiers: [String],
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            if identifiers.isEmpty {
                Text(emptyText).foregroundStyle(.secondary)
            } else {
                ForEach(identifiers, id: \.self) { identifier in
                    Text(identifier)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
