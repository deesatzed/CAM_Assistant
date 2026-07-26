import CAMAssistantCore
import SwiftUI

struct AssistantWindow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $model.selection, health: model.health)
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
            ActionCardView(card: model.pendingActionCard)
        case .tasks:
            TaskListView(presentation: model.taskPresentation, errorMessage: model.taskError, isRefreshing: model.isRefreshingWorkspace, reload: model.reloadTasks, complete: model.completeTask)
        case .cam:
            CAMStatusView(status: model.camStatus)
        case .research:
            ResearchView(model: model)
        case .repositories:
            RepositoryView(model: model)
        case .macCare:
            MacCareView(presentation: model.macCarePresentation, errorMessage: model.macCareError, isAssessing: model.isMacCareAssessing, assess: model.assessMacCareReadOnly)
        case .settings:
            VStack(spacing: 0) {
                ModelProfilesView(settings: model.modelSettings, errorMessage: model.modelSettingsError, reload: model.reloadModelSettings)
                HotkeySettingsView(model: model)
                CaptureSourcesView(model: model)
            }
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
