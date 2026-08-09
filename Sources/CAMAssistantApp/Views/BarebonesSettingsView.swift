import CAMAssistantCore
import SwiftUI

enum BarebonesSettingsSection: String, CaseIterable, Equatable, Identifiable {
    case capture
    case localAI
    case backupRestore
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capture: "Capture"
        case .localAI: "Local AI"
        case .backupRestore: "Backup & Restore"
        case .advanced: "Advanced"
        }
    }

    var summary: String {
        switch self {
        case .capture:
            "Choose folders CAM can save from automatically."
        case .localAI:
            "Optional. Answers still work from matching passages when it is off."
        case .backupRestore:
            "Make a local backup you can verify and restore safely."
        case .advanced:
            "Technical controls and diagnostics when you need them."
        }
    }
}

enum BarebonesSettingsPresentation {
    static let privacyNote = "Your saved content stays on this Mac."

    static var primaryText: String {
        ([privacyNote] + BarebonesSettingsSection.allCases.flatMap {
            [$0.title, $0.summary]
        }).joined(separator: " ")
    }
}

struct BarebonesSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var showCapture = false
    @State private var showBackup = false
    @State private var showAdvanced = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings").font(.largeTitle.bold())
                Text(BarebonesSettingsPresentation.privacyNote)
                    .foregroundStyle(.secondary)
                captureCard
                localAICard
                backupCard
                advancedCard
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings. Four groups: Capture, Local AI, Backup and Restore, and Advanced.")
        .onAppear {
            model.reloadModelSettings()
            honorRequestedSection()
        }
        .onChange(of: model.requestedSettingsSection) { _, _ in
            honorRequestedSection()
        }
        .sheet(isPresented: $showCapture) {
            DismissibleSheetChrome(title: "Watched folders") {
                CaptureSourcesView(model: model)
            }
            .frame(minWidth: 600, minHeight: 480)
        }
        .sheet(isPresented: $showBackup) {
            DismissibleSheetChrome(title: "Backup & Restore") {
                BackupRecoveryView(model: model)
            }
            .frame(minWidth: 680, minHeight: 560)
        }
        .sheet(isPresented: $showAdvanced) {
            DismissibleSheetChrome(title: "Advanced Settings") {
                AdvancedSettingsView(model: model)
            }
            .frame(minWidth: 720, minHeight: 620)
        }
    }

    private var captureCard: some View {
        settingsCard(.capture, icon: "tray.and.arrow.down") {
            Text("Save Clipboard shortcut: Command–Option–C")
                .font(.callout)
            Text(
                "\(model.watchedSourcePresentation.count) "
                    + (model.watchedSourcePresentation.count == 1
                        ? "folder added" : "folders added")
            )
            .foregroundStyle(.secondary)
            Button("Manage Folders") { showCapture = true }
        }
    }

    private var localAICard: some View {
        settingsCard(.localAI, icon: "sparkles") {
            Label(localAIStatus, systemImage: localAIStatusIcon)
            if !model.localCatalogModelIDs.isEmpty {
                Picker("Model", selection: $model.selectedLocalCatalogModelID) {
                    ForEach(model.localCatalogModelIDs, id: \.self) { modelID in
                        Text(model.friendlyLocalModelLabel(for: modelID))
                            .tag(modelID)
                            .help(modelID)
                    }
                }
                .onChange(of: model.selectedLocalCatalogModelID) { _, modelID in
                    guard !modelID.isEmpty else { return }
                    model.applySelectedLocalModelFromCatalog()
                }
                if !model.selectedLocalCatalogModelID.isEmpty {
                    Text("Full id: \(model.selectedLocalCatalogModelID)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
            Button("Check Again", action: model.checkLocalAIFromSettings)
                .disabled(
                    model.isRefreshingLocalCatalog || model.isCheckingLocalModel
                )
            if let error = model.localCatalogError ?? model.localModelHealthError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var backupCard: some View {
        settingsCard(.backupRestore, icon: "externaldrive") {
            Button("Open Backup & Restore") { showBackup = true }
        }
    }

    private var advancedCard: some View {
        settingsCard(.advanced, icon: "wrench.and.screwdriver") {
            Button("Open Advanced Settings") { showAdvanced = true }
        }
    }

    private func settingsCard<Content: View>(
        _ section: BarebonesSettingsSection,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label(section.title, systemImage: icon).font(.title3.bold())
                Text(section.summary).foregroundStyle(.secondary)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var localAIStatus: String {
        if model.localModelHealth != nil { return "Ready" }
        if model.isRefreshingLocalCatalog || model.isCheckingLocalModel {
            return "Checking…"
        }
        if !model.localCatalogModelIDs.isEmpty { return "Detected" }
        return "Not running"
    }

    private var localAIStatusIcon: String {
        model.localModelHealth == nil ? "circle" : "checkmark.circle.fill"
    }

    private func honorRequestedSection() {
        switch model.requestedSettingsSection {
        case .capture: showCapture = true
        case .backupRestore: showBackup = true
        case .advanced: showAdvanced = true
        case .localAI, .none: break
        }
        model.requestedSettingsSection = nil
    }
}

private enum AdvancedSettingsPane: String, CaseIterable, Identifiable {
    case localAI = "Local AI Details"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }
}

private struct AdvancedSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var pane = AdvancedSettingsPane.localAI

    var body: some View {
        VStack(spacing: 0) {
            Picker("Advanced settings", selection: $pane) {
                ForEach(AdvancedSettingsPane.allCases) { pane in
                    Text(pane.rawValue).tag(pane)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            switch pane {
            case .localAI:
                ModelProfilesView(model: model)
            case .shortcuts:
                HotkeySettingsView(model: model)
            }
            // Meaning Preview is a parked specialist pilot. It is not offered
            // on the ordinary Advanced surface (Pattern A primary product).
            Text(
                "Tip: Press Escape or Done to leave Advanced and return to Settings."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding([.horizontal, .bottom])
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("Advanced technical settings")
    }
}
