import CAMAssistantCore
import SwiftUI

struct Sidebar: View {
    @Binding var selection: AssistantSection
    let health: AppHealth

    var body: some View {
        List(AssistantSection.allCases, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.systemImage)
                .tag(section)
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
