import CAMAssistantCore
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case models
    case hotkeys
    case captureSources
    case backupRecovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .models: "Models"
        case .hotkeys: "Hotkeys"
        case .captureSources: "Capture Sources"
        case .backupRecovery: "Backup & Recovery"
        }
    }
}

struct AssistantWindow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            Sidebar(
                selection: $model.selection,
                health: model.health,
                meaningPreviewVisible: model.isMeaningPreviewVisible
            )
        } detail: {
            detail
                .navigationTitle(model.selection.rawValue)
        }
        .onAppear { model.registerHotkeys() }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .assistant:
            ConversationView(model: model)
        case .library:
            LibraryView(model: model)
        case .activity:
            ActivityView(model: model)
        case .tasks:
            TaskListView(presentation: model.taskPresentation, errorMessage: model.taskError, isRefreshing: model.isRefreshingWorkspace, reload: model.reloadTasks, complete: model.completeTask)
        case .modules:
            ModulesView(model: model)
        case .cam:
            CAMStatusView(status: model.camStatus)
        case .research:
            ResearchView(model: model)
        case .repositories:
            RepositoryView(model: model)
        case .macCare:
            MacCareView(presentation: model.macCarePresentation, errorMessage: model.macCareError, isAssessing: model.isMacCareAssessing, assess: model.assessMacCareReadOnly)
        case .meaningPreview:
            if model.isMeaningPreviewVisible {
                MeaningPreviewView(model: model)
            } else {
                ConversationView(model: model)
            }
        case .settings:
            SettingsWorkspace(model: model)
        }
    }
}

private struct SettingsWorkspace: View {
    @ObservedObject var model: AppModel
    @State private var selectedPane = SettingsPane.models
    @State private var isMeaningPreviewSettingsPresented = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Settings pane", selection: $selectedPane) {
                    ForEach(SettingsPane.allCases) { pane in
                        Text(pane.title).tag(pane)
                    }
                }
                .pickerStyle(.segmented)

                Button("Meaning Preview…") {
                    isMeaningPreviewSettingsPresented = true
                }
                .accessibilityIdentifier("meaning-preview-settings-open")
                .accessibilityHint("Opens the optional Meaning Preview lifecycle and permission settings even while the Preview is disabled.")
            }
            .padding()

            switch selectedPane {
            case .models:
                ModelProfilesView(
                    settings: model.modelSettings,
                    errorMessage: model.modelSettingsError,
                    localHealth: model.localModelHealth,
                    localHealthError: model.localModelHealthError,
                    isChecking: model.isCheckingLocalModel,
                    reload: model.reloadModelSettings,
                    checkLocalModel: model.checkSelectedLocalModel
                )
            case .hotkeys:
                HotkeySettingsView(model: model)
            case .captureSources:
                CaptureSourcesView(model: model)
            case .backupRecovery:
                BackupRecoveryView(model: model)
            }
        }
        .accessibilityLabel("Assistant settings")
        .sheet(isPresented: $isMeaningPreviewSettingsPresented) {
            MeaningPreviewSettingsView(model: model)
                .frame(minWidth: 560, minHeight: 480)
        }
    }
}

private struct AssistantEmptyState: View {
    let health: AppHealth

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            VStack(spacing: 8) {
                Text(health.statusMessage)
                Text("Nothing is sent to a cloud model unless you explicitly route it there.")
                    .font(.caption)
            }
        } actions: {
            HStack {
                Button("Capture from Clipboard") {}
                    .disabled(true)
                    .help("Clipboard capture is added in the ingestion milestone")
                Button("Choose Folder…") {}
                    .disabled(true)
                    .help("Folder capture is added in the ingestion milestone")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(health.statusMessage)")
    }

    private var title: String {
        switch health.mode {
        case .localReady:
            "Ready for a local question"
        case .degraded:
            "Local intelligence needs attention"
        case .offline:
            "Working offline"
        }
    }

    private var symbol: String {
        switch health.mode {
        case .localReady:
            "sparkles"
        case .degraded:
            "exclamationmark.triangle"
        case .offline:
            "wifi.slash"
        }
    }
}

private struct PlaceholderState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
        .accessibilityLabel("\(title). \(message)")
    }
}
