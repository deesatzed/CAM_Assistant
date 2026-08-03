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
                .accessibilityIdentifier("meaning-preview-disable")
                .accessibilityHint("Stops Preview behavior and returns to ordinary Assistant.")
            }

            if model.meaningPreviewLifecycle == .enabledWithoutLocalRead {
                permissionState
            } else if model.meaningPreviewLifecycle == .ready {
                requestControls
                presentationState
                reflectiveState
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

    private var reflectiveState: some View {
        GroupBox("Optional local reflection") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Reflection runs only when explicitly requested, uses two to eight selected current sources, and never replaces practical Preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.isMeaningPreviewReflectionAvailable {
                    ForEach(model.libraryPresentation.rows) { row in
                        Toggle(
                            row.captures.first?.sourceName
                                ?? String(row.preview.prefix(80)),
                            isOn: Binding(
                                get: {
                                    model.meaningPreviewReflectiveSourceIDs
                                        .contains(row.id)
                                },
                                set: { _ in
                                    model.toggleMeaningPreviewReflectiveSource(
                                        id: row.id
                                    )
                                }
                            )
                        )
                        .accessibilityIdentifier(
                            "meaning-preview-reflect-source-\(row.id)"
                        )
                    }
                    Button("Reflect on Selected Context") {
                        Task { await model.requestMeaningPreviewReflection() }
                    }
                    .disabled(!model.canRequestMeaningPreviewReflection)
                    .accessibilityIdentifier("meaning-preview-reflect")
                } else {
                    Text("Reflection is unavailable because no fresh canonical named-model report admits the current selected loopback assignment. Practical Preview remains available.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("meaning-preview-reflect-unavailable")
                }
                if model.isMeaningPreviewReflecting {
                    ProgressView("Checking selected context locally")
                        .accessibilityIdentifier("meaning-preview-reflect-loading")
                }
                if let reflection = model.meaningPreviewReflection {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reflection.text)
                            .textSelection(.enabled)
                        Text("Ephemeral · \(reflection.modelID) · support \(reflection.supportIDs.count) · counterevidence \(reflection.counterevidenceIDs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("One ephemeral validated reflection")
                    .accessibilityIdentifier("meaning-preview-reflection")
                }
                if let status = model.meaningPreviewReflectionStatus {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("meaning-preview-reflect-status")
                }
                if let error = model.meaningPreviewReflectionError {
                    Text(error).foregroundStyle(.red)
                        .accessibilityIdentifier("meaning-preview-reflect-error")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("meaning-preview-reflective-lane")
    }

    private var permissionState: some View {
        // Prefer an explicit VStack over ContentUnavailableView actions so the
        // grant control keeps a stable accessibility identifier and button role
        // for packaged AX journeys.
        VStack(spacing: 12) {
            Label("Local access is not granted", systemImage: "lock")
                .font(.title3)
            Text("Enablement alone grants no access. Grant local read and isolated write access before selecting and requesting a Preview.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Grant Local Read & Isolated Write") {
                Task { await model.grantMeaningPreviewLocalRead() }
            }
            .disabled(model.isMeaningPreviewWorking)
            .accessibilityIdentifier("meaning-preview-grant")
            .accessibilityHint("Grants local read and isolated write only after explicit confirmation. Enablement never grants this.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meaning-preview-permission-state")
        .accessibilityLabel("Local access is not granted")
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
                            Text(
                                row.captures.first?.sourceName
                                    ?? "\(row.modalityLabel) · \(String(row.preview.prefix(80)))"
                            )
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
        } else if let presentation = model.meaningPreviewPresentation {
            if let card = presentation.card {
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
            } else {
                ContentUnavailableView {
                    Label("Nothing practical surfaced", systemImage: "circle.dashed")
                } description: {
                    Text("Silence is a valid result. No automatic retry, notification, or escalation will occur.")
                } actions: {
                    Button("Inspect exclusions") { isInspectPresented = true }
                        .accessibilityIdentifier("meaning-preview-inspect")
                }
                .accessibilityIdentifier("meaning-preview-silence")
            }
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
            Label(recoveryTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(recoveryDescription)
        } actions: {
            Button("Archive & Reinitialize Isolated State") {
                Task { await model.recoverMeaningPreview() }
            }
            .disabled(model.isMeaningPreviewWorking)
            .accessibilityIdentifier("meaning-preview-recover")
            .accessibilityHint("Archives only the isolated Meaning Preview store and initializes an empty compatible store.")
        }
        .accessibilityIdentifier("meaning-preview-recovery-state")
    }

    private var recoveryTitle: String {
        switch model.meaningPreviewLifecycle {
        case .corruptedStore: "Meaning Preview store is corrupted"
        case .incompatibleStore: "Meaning Preview store is incompatible"
        default: "Meaning Preview is unavailable"
        }
    }

    private var recoveryDescription: String {
        "Archive and reinitialize the isolated Preview state, or disable it. Ordinary Assistant remains unchanged."
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
