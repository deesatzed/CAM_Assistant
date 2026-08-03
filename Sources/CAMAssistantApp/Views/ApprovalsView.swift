import CAMAssistantCore
import SwiftUI

struct ApprovalsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Exact approvals")
                    .font(.headline)
                Text(
                    "Review and dispatch exact-approved external or mutating work from this workspace. "
                        + "Activity remains status-only for ingest jobs."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()

            if model.isResearchAcquiring {
                ActionCardView(
                    card: model.pendingActionCard ?? model.researchAcquisitionProposal?.actionCard,
                    onCancel: model.cancelResearchAcquisition,
                    cancelTitle: "Cancel Acquisition",
                    isCancelling: false
                )
            } else if model.canApprovePendingResearchAcquisition {
                ActionCardView(
                    card: model.pendingActionCard ?? model.researchAcquisitionProposal?.actionCard,
                    onApprove: model.approveAndAcquireResearchSource,
                    approveTitle: "Approve & Acquire",
                    isApproving: model.isResearchAcquiring,
                    approveDisabled: !model.canApprovePendingResearchAcquisition
                )
            } else {
                ActionCardView(card: model.pendingActionCard)
            }

            if model.researchAcquisitionProposal != nil || model.pendingActionCard != nil {
                Button("Open Research workspace") {
                    model.selection = .research
                }
                .padding()
                .accessibilityHint("Opens Research for full acquisition context.")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Approvals. Exact approval dispatch for pending action cards.")
        .accessibilityIdentifier("approvals-workspace")
    }
}
