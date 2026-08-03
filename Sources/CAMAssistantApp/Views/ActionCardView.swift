import CAMAssistantCore
import SwiftUI

struct ActionCardView: View {
    let card: ActionCard?
    var onApprove: (() -> Void)? = nil
    var approveTitle: String = "Approve"
    var isApproving: Bool = false
    var approveDisabled: Bool = false
    var onCancel: (() -> Void)? = nil
    var cancelTitle: String = "Cancel"
    var isCancelling: Bool = false

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
                        if let onApprove {
                            Button(approveTitle, action: onApprove)
                                .disabled(approveDisabled || isApproving)
                                .accessibilityIdentifier("approvals-approve")
                            if isApproving {
                                ProgressView("Working…")
                                    .controlSize(.small)
                            }
                        } else if onCancel == nil {
                            Text(
                                "Open Approvals to approve or cancel this action. "
                                    + "This card alone does not dispatch work."
                            )
                            .foregroundStyle(.secondary)
                        }
                        if let onCancel {
                            Button(cancelTitle, action: onCancel)
                                .disabled(isCancelling)
                                .accessibilityIdentifier("approvals-cancel")
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView(
                    "No action awaiting approval",
                    systemImage: "checklist",
                    description: Text(
                        "Local reads can run within enabled modules. External or mutating requests appear here first as exact, reviewable action cards."
                    )
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Action proposals")
    }
}
