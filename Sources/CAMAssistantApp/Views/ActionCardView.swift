import CAMAssistantCore
import SwiftUI

struct ActionCardView: View {
    let card: ActionCard?

    var body: some View {
        Group {
            if let card {
                Form {
                    Section("Proposed action") {
                        LabeledContent("Goal", value: card.goal)
                        LabeledContent("Module", value: card.moduleID)
                        LabeledContent("Target", value: card.target)
                        LabeledContent("Risk", value: card.outboundManifest.riskClass.rawValue)
                    }
                    Section("Access and limits") {
                        LabeledContent("May access", value: card.accessedResources.joined(separator: ", "))
                        LabeledContent("Will not access", value: card.excludedResources.joined(separator: ", "))
                        Text(card.riskReason)
                            .foregroundStyle(.secondary)
                    }
                    Section("Approval") {
                        LabeledContent("Required", value: "Exact approval")
                        LabeledContent("Expires", value: card.expiresAt.formatted())
                        LabeledContent("Rollback", value: card.rollbackDescription)
                        Text("This screen is read-only. No action is dispatched from this card.")
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView(
                    "No action awaiting approval",
                    systemImage: "checklist",
                    description: Text("Local reads can run within enabled modules. External or mutating requests appear here first as exact, reviewable action cards.")
                )
            }
        }
        .accessibilityLabel("Action proposals")
    }
}
