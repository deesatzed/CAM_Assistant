import CAMAssistantCore
import SwiftUI

struct Sidebar: View {
    @Binding var selection: AssistantSection
    let health: AppHealth
    let meaningPreviewVisible: Bool

    private var visibleSections: [AssistantSection] {
        AssistantSection.allCases.filter {
            meaningPreviewVisible || $0 != .meaningPreview
        }
    }

    var body: some View {
        List(visibleSections, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.systemImage)
                .tag(section)
                .accessibilityIdentifier(section.accessibilityIdentifier)
        }
        .safeAreaInset(edge: .bottom) {
            Label(health.statusMessage, systemImage: statusSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("System status: \(health.statusMessage)")
        }
        .navigationTitle(BuildIdentity.productName)
    }

    private var statusSymbol: String {
        switch health.mode {
        case .localReady:
            "checkmark.circle"
        case .degraded:
            "exclamationmark.triangle"
        case .offline:
            "wifi.slash"
        }
    }
}

private extension AssistantSection {
    var accessibilityIdentifier: String {
        switch self {
        case .assistant: "assistant-section-assistant"
        case .meaningPreview: "meaning-preview-sidebar"
        case .library: "assistant-section-library"
        case .activity: "assistant-section-activity"
        case .tasks: "assistant-section-tasks"
        case .modules: "assistant-section-modules"
        case .cam: "assistant-section-cam"
        case .research: "assistant-section-research"
        case .repositories: "assistant-section-repositories"
        case .macCare: "assistant-section-mac-care"
        case .settings: "assistant-section-settings"
        }
    }
}
