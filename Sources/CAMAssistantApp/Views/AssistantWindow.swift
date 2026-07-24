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
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .assistant:
            AssistantEmptyState(health: model.health)
        case .library:
            PlaceholderState(
                title: "Your library is empty",
                message: "Folder and clipboard capture arrive in the ingestion milestone.",
                systemImage: "books.vertical"
            )
        case .activity:
            PlaceholderState(
                title: "No activity yet",
                message: "Verified actions and research checkpoints will appear here.",
                systemImage: "clock"
            )
        case .settings:
            PlaceholderState(
                title: "Settings are local",
                message: "Model profiles and confidence thresholds arrive in their dedicated milestone.",
                systemImage: "gearshape"
            )
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
