import SwiftUI

struct MeaningPreviewSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Meaning Preview") {
                LabeledContent("State", value: lifecycleLabel)
                Text("Meaning Preview is an optional, local-first pilot. Enablement grants no data access and starts no background work.")
                    .foregroundStyle(.secondary)

                lifecycleControls

                if model.meaningPreviewLifecycle == .corruptedStore
                    || model.meaningPreviewLifecycle == .incompatibleStore {
                    Button("Archive & Reinitialize Isolated State") {
                        Task { await model.recoverMeaningPreview() }
                    }
                    .disabled(model.isMeaningPreviewWorking)
                    .accessibilityIdentifier("meaning-preview-recover")
                    .accessibilityHint("Archives only the isolated Meaning Preview store and initializes an empty compatible store. Ordinary CAM data is unchanged.")
                }

                if let status = model.meaningPreviewStatus {
                    Text(status)
                        .accessibilityIdentifier("meaning-preview-settings-status")
                }
                if let error = model.meaningPreviewError {
                    Text(error)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("meaning-preview-settings-error")
                }
            }

            Section("Boundary") {
                Text("A separate grant is required for local read and isolated write access. No network, notification, cloud, CAM execution, or web authority is granted.")
                Text("Ordinary Assistant remains unchanged when Meaning Preview is disabled or unavailable.")
            }
        }
        .formStyle(.grouped)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meaning Preview settings")
        .accessibilityIdentifier("meaning-preview-settings")
    }

    @ViewBuilder
    private var lifecycleControls: some View {
        switch model.meaningPreviewLifecycle {
        case .disabled:
            Button("Enable Meaning Preview") {
                Task { await model.enableMeaningPreview() }
            }
            .id("meaning-preview-enable-control")
            .disabled(model.isMeaningPreviewWorking)
            .accessibilityIdentifier("meaning-preview-enable")
            .accessibilityHint("Reveals the optional workspace but grants no local data access.")
        case .enabledWithoutLocalRead:
            Button("Grant Local Read & Isolated Write") {
                Task { await model.grantMeaningPreviewLocalRead() }
            }
            .id("meaning-preview-grant-control")
            .disabled(model.isMeaningPreviewWorking)
            .accessibilityIdentifier("meaning-preview-grant")
            .accessibilityHint("Grants access only to one explicitly selected active derived local source and Meaning Preview's isolated state.")
            disableButton
        case .ready:
            Text("Access is ready. Choose an active derived source in the Meaning Preview workspace before requesting a Preview.")
                .foregroundStyle(.secondary)
            disableButton
        case .corruptedStore:
            Text("The isolated Preview store is corrupted. Archive and reinitialize it before requesting another Preview.")
                .foregroundStyle(.secondary)
            disableButton
        case .incompatibleStore:
            Text("The isolated Preview store schema is incompatible. Archive and reinitialize it before requesting another Preview.")
                .foregroundStyle(.secondary)
            disableButton
        case .unavailable:
            Text("Meaning Preview is unavailable. Ordinary Assistant remains available.")
                .foregroundStyle(.secondary)
        }
    }

    private var disableButton: some View {
        Button("Disable Meaning Preview", role: .destructive) {
            Task { await model.disableMeaningPreview() }
        }
        .accessibilityIdentifier("meaning-preview-settings-disable")
        .accessibilityHint("Stops Preview behavior, removes its workspace, and returns to ordinary Assistant without deleting CAM data.")
    }

    private var lifecycleLabel: String {
        switch model.meaningPreviewLifecycle {
        case .disabled: "Disabled"
        case .enabledWithoutLocalRead: "Enabled; no local access"
        case .ready: "Enabled with explicit local access"
        case .corruptedStore: "Corrupted isolated store"
        case .incompatibleStore: "Incompatible isolated store"
        case .unavailable: "Unavailable"
        }
    }
}
