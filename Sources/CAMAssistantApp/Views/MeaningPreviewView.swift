import SwiftUI

struct MeaningPreviewView: View {
    @ObservedObject var model: AppModel
    @State private var isInspectPresented = false
    @FocusState private var sourcePickerFocused: Bool

    private var selectedSourceID: Binding<String> {
        Binding(
            get: { model.meaningPreviewSelectedSource?.id ?? "" },
            set: { selectedID in
                guard !selectedID.isEmpty else { return }
                model.selectMeaningPreviewSource(id: selectedID)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meaning Preview")
                        .font(.title2)
                    Text("Preview · Optional · Local · User-pull")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Disable") {
                    Task { await model.disableMeaningPreview() }
                }
                .disabled(model.isMeaningPreviewWorking)
                .accessibilityIdentifier("meaning-preview-disable")
                .accessibilityHint("Stops Preview behavior and returns to ordinary Assistant.")
            }

            if model.meaningPreviewLifecycle == .enabledWithoutLocalRead {
                permissionState
            } else if model.meaningPreviewLifecycle == .ready {
                requestControls
                presentationState
            } else {
                unavailableState
            }

            statusState
            Spacer(minLength: 0)
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meaning Preview workspace")
        .accessibilityIdentifier("meaning-preview-workspace")
        .sheet(isPresented: $isInspectPresented) {
            if let inspect = model.meaningPreviewPresentation?.inspect {
                MeaningInspectView(presentation: inspect)
            }
        }
        .task { sourcePickerFocused = true }
    }

    private var permissionState: some View {
        ContentUnavailableView {
            Label("Local access is not granted", systemImage: "lock")
        } description: {
            Text("Enablement alone grants no access. Grant local read and isolated write access before selecting and requesting a Preview.")
        } actions: {
            Button("Grant Local Read & Isolated Write") {
                Task { await model.grantMeaningPreviewLocalRead() }
            }
            .disabled(model.isMeaningPreviewWorking)
            .accessibilityIdentifier("meaning-preview-grant")
        }
        .accessibilityIdentifier("meaning-preview-permission-state")
    }

    private var requestControls: some View {
        GroupBox("Explicit local context") {
            VStack(alignment: .leading, spacing: 10) {
                if model.libraryPresentation.rows.isEmpty {
                    Text("No active derived local sources are available. Add or restore a source in Library first.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Selected source", selection: selectedSourceID) {
                        Text("Choose one active source").tag("")
                        ForEach(model.libraryPresentation.rows) { row in
                            Text("\(row.modalityLabel) · \(row.id)")
                                .tag(row.id)
                        }
                    }
                    .focused($sourcePickerFocused)
                    .accessibilityIdentifier("meaning-preview-source-picker")
                    .accessibilityHint("Selects one active CAM-derived source by opaque identifier. Selection does not count as feedback.")
                }

                Button("Request Meaning Preview") {
                    Task { await model.requestMeaningPreview() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canRequestMeaningPreview)
                .accessibilityIdentifier("meaning-preview-request")
                .accessibilityHint("Checks only the explicitly selected active derived source and returns zero or one practical Preview.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var presentationState: some View {
        if model.isMeaningPreviewWorking {
            ProgressView("Checking selected local context")
                .accessibilityIdentifier("meaning-preview-loading")
        } else if let presentation = model.meaningPreviewPresentation,
                  let card = presentation.card {
            GroupBox("Practical Preview") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.text)
                        .font(.title3)
                        .textSelection(.enabled)
                    Text("This is a bounded possibility, not a judgment, diagnosis, instruction, or completed action.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Inspect") { isInspectPresented = true }
                            .accessibilityIdentifier("meaning-preview-inspect")
                        Spacer()
                        actionButton("Now", action: .now, identifier: "meaning-preview-now")
                        actionButton("Later", action: .later, identifier: "meaning-preview-later")
                        actionButton("Release", action: .release, identifier: "meaning-preview-release")
                    }
                    HStack {
                        Text("Optional feedback")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        feedbackButton("Helpful", feedback: .helpful, identifier: "meaning-preview-helpful")
                        feedbackButton("Not Helpful", feedback: .notHelpful, identifier: "meaning-preview-not-helpful")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("One practical Meaning Preview")
            .accessibilityIdentifier("meaning-preview-card")
        } else if model.meaningPreviewStatus?.contains("Nothing practical surfaced") == true {
            ContentUnavailableView(
                "Nothing practical surfaced",
                systemImage: "circle.dashed",
                description: Text("Silence is a valid result. No automatic retry, notification, or escalation will occur.")
            )
            .accessibilityIdentifier("meaning-preview-silence")
        } else {
            ContentUnavailableView(
                "No Preview requested",
                systemImage: "lightbulb.slash",
                description: Text("Choose one active derived local source, then request a Preview. Nothing runs automatically.")
            )
            .accessibilityIdentifier("meaning-preview-empty")
        }
    }

    private var unavailableState: some View {
        ContentUnavailableView {
            Label("Meaning Preview is unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Recover the isolated Preview state from Settings or disable it. Ordinary Assistant remains unchanged.")
        } actions: {
            Button("Recover Isolated State") {
                Task { await model.recoverMeaningPreview() }
            }
            .disabled(model.isMeaningPreviewWorking)
            .accessibilityIdentifier("meaning-preview-recover")
        }
        .accessibilityIdentifier("meaning-preview-recovery-state")
    }

    @ViewBuilder
    private var statusState: some View {
        if let status = model.meaningPreviewStatus {
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Meaning Preview status: \(status)")
                .accessibilityIdentifier("meaning-preview-status")
        }
        if let error = model.meaningPreviewError {
            Text(error)
                .foregroundStyle(.red)
                .accessibilityLabel("Meaning Preview error: \(error)")
                .accessibilityIdentifier("meaning-preview-error")
        }
    }

    private func actionButton(
        _ title: String,
        action: MeaningPreviewCardAction,
        identifier: String
    ) -> some View {
        Button(title) {
            Task { await model.applyMeaningPreviewAction(action) }
        }
        .disabled(model.isMeaningPreviewWorking)
        .accessibilityIdentifier(identifier)
        .accessibilityHint("Records only the \(title) disposition in isolated Preview state. It does not imply helpfulness or execute an external action.")
    }

    private func feedbackButton(
        _ title: String,
        feedback: MeaningPreviewFeedback,
        identifier: String
    ) -> some View {
        Button(title) {
            Task { await model.recordMeaningPreviewFeedback(feedback) }
        }
        .disabled(model.isMeaningPreviewWorking)
        .accessibilityIdentifier(identifier)
        .accessibilityHint("Records explicit, domain-scoped \(title.lowercased()) feedback for this exact card.")
    }
}
