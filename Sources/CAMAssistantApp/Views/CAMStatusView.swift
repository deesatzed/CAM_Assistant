import CAMAssistantCore
import SwiftUI

struct CAMStatusView: View {
    let status: CAMIntegrationStatus

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            VStack(spacing: 10) {
                Text(status.contractIdentity)
                    .font(.headline)
                Text(status.runtimeMessage)
                Text("This native adapter verifies pinned contract snapshots only. It does not start, configure, query, mine, or send work to CAM.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CAM status. \(status.contractIdentity). \(status.runtimeMessage). Execution is disabled.")
    }

    private var title: String {
        switch status.health {
        case .ready:
            "CAM contract is conformant"
        case .unavailable:
            "CAM runtime is not connected"
        case .incompatible:
            "CAM runtime is incompatible"
        }
    }

    private var symbol: String {
        switch status.health {
        case .ready:
            "checkmark.shield"
        case .unavailable:
            "link.badge.plus"
        case .incompatible:
            "exclamationmark.triangle"
        }
    }
}
