import CAMAssistantCore
import SwiftUI

struct ModelProfilesView: View {
    let settings: ModelSettingsState?
    let errorMessage: String?
    let reload: () -> Void

    var body: some View {
        Form {
            Section("Active local model profile") {
                if let settings, let profile = settings.activeProfile {
                    LabeledContent("Profile", value: profile.id)
                    LabeledContent("Revision", value: String(profile.revision))
                    ForEach(profile.assignments.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { role in
                        if let assignment = profile.assignment(for: role) {
                            LabeledContent(roleLabel(role), value: assignment.modelID)
                        }
                    }
                    Text(settings.availabilityMessage)
                        .foregroundStyle(.secondary)
                } else {
                    Text(errorMessage ?? "No active local model profile.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Safety") {
                Text("Profiles are local. Cloud, web, and CAM routes remain unavailable until their privacy and approval contracts are verified.")
                    .foregroundStyle(.secondary)
                Button("Reload Local Profile State", action: reload)
                    .accessibilityHint("Reloads local model profile state without contacting any provider.")
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel("Local model profile settings")
    }

    private func roleLabel(_ role: ModelRouteRole) -> String {
        switch role {
        case .local: "Local"
        case .claude: "Claude"
        case .grok: "Grok"
        case .openAI: "OpenAI"
        }
    }
}
