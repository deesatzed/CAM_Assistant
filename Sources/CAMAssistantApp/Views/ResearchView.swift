import CAMAssistantCore
import SwiftUI

struct ResearchView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Local research plan") {
                TextField(
                    "Research question",
                    text: $model.researchQuery
                )
                Button(
                    "Create Local Research Plan",
                    action: model.beginLocalResearch
                )
                Button(
                    "Keep Local Research Plan",
                    action: model.keepLocalResearchPlan
                )
                .disabled(model.currentResearchRun == nil)
                Text(model.researchPresentation.statusMessage)
                    .foregroundStyle(.secondary)
                repositoryProvenance
            }

            Section("Bounded public document acquisition") {
                TextField(
                    "Public HTTPS document URL",
                    text: $model.researchSourceURL
                )
                .textContentType(.URL)
                Button(
                    "Prepare Public Document Acquisition",
                    action: model.prepareResearchAcquisition
                )
                .disabled(
                    model.isPreparingResearchAcquisition
                        || model.isResearchAcquiring
                )
                if model.isPreparingResearchAcquisition {
                    ProgressView("Checking target and privacy boundary")
                }
                Text(
                    "One caller-selected public HTTPS text, Markdown, JSON, "
                        + "or PDF document; at most 5 MB and USD 0."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("No provider search, browser automation, cookies, credentials, cloud model, CAM call, or automatic retention.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let proposal = model.researchAcquisitionProposal {
                Section("Exact public-document proposal") {
                    LabeledContent(
                        "Target",
                        value: proposal.actionCard.target
                    )
                    LabeledContent(
                        "Maximum response",
                        value: "\(proposal.request.maxBytes) bytes"
                    )
                    LabeledContent(
                        "Cost limit",
                        value: "USD \(proposal.request.maximumCostUSD)"
                    )
                    LabeledContent(
                        "Route",
                        value: proposal.request.route
                    )
                    LabeledContent(
                        "Tool",
                        value: proposal.request.toolID
                    )
                    LabeledContent(
                        "Approval",
                        value: "Exact · one use · expires "
                            + proposal.actionCard.expiresAt.formatted()
                    )
                    Text(proposal.actionCard.riskReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent(
                        "Will not access",
                        value: proposal.actionCard.excludedResources
                            .joined(separator: " · ")
                    )
                    Button(
                        "Approve & Acquire",
                        action: model.approveAndAcquireResearchSource
                    )
                    .disabled(model.isResearchAcquiring)
                }
            }

            if model.isResearchAcquiring {
                Section("Acquisition in progress") {
                    ProgressView(
                        "Fetching the exact approved public document"
                    )
                    Button(
                        "Cancel Acquisition",
                        action: model.cancelResearchAcquisition
                    )
                    Text(
                        "Cancellation retains no packet. A later resume "
                            + "requires a new exact approval."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if let status = model.researchAcquisitionStatus {
                Section("Research status") {
                    Text(status)
                }
            }
            if let error = model.researchAcquisitionError {
                Section("Research error") {
                    Text(error).foregroundStyle(.red)
                }
            }
            if let error = model.researchError {
                Section("Local plan error") {
                    Text(error).foregroundStyle(.red)
                }
            }

            if let result = model.researchAcquisitionResult {
                packetSection(result)
            }

            if !model.researchAcquisitionJobs.isEmpty {
                Section("Recent acquisition jobs") {
                    ForEach(model.researchAcquisitionJobs) { job in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(
                                "Target",
                                value: job.request.target.absoluteString
                            )
                            LabeledContent(
                                "Status",
                                value: job.status.rawValue.capitalized
                            )
                            LabeledContent(
                                "Attempts",
                                value: "\(job.attempts) of "
                                    + "\(job.maxAttempts)"
                            )
                            if let errorCode = job.errorCode {
                                LabeledContent(
                                    "Safe failure",
                                    value: errorCode
                                )
                            }
                            if (job.status == .cancelled
                                || job.status == .failed),
                               job.attempts < job.maxAttempts {
                                Button("Prepare Resume Approval") {
                                    model.prepareResearchAcquisitionResume(
                                        job.id
                                    )
                                }
                            }
                            if job.status == .completed,
                               job.receipt != nil {
                                Button("Review Ephemeral Packet") {
                                    model.reviewCompletedResearchAcquisition(
                                        job.id
                                    )
                                }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(
                            "Research acquisition "
                                + "\(job.status.rawValue), "
                                + "\(job.attempts) of "
                                + "\(job.maxAttempts) attempts"
                        )
                    }
                }
            }

            if !model.retainedResearchPackets.isEmpty {
                Section("Kept research packets") {
                    ForEach(
                        model.retainedResearchPackets,
                        id: \.runID
                    ) { packet in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(packet.runID)
                            Text(
                                "\(packet.sourceReceipts.count) sources · "
                                    + "\(packet.verifiedFacts.count) facts · "
                                    + "\(packet.unansweredQuestions.count) "
                                    + "unanswered"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            LabeledContent(
                                "Retention",
                                value: packet.retention.rawValue
                            )
                        }
                    }
                }
            }

            if !model.retainedResearchPlans.isEmpty {
                Section("Kept local research plans") {
                    ForEach(
                        model.retainedResearchPlans,
                        id: \.run.id
                    ) { plan in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    plan.run.queries.joined(
                                        separator: " · "
                                    )
                                )
                                Text(
                                    "Checkpoint: "
                                        + "\(plan.run.checkpoint.phase.rawValue), "
                                        + "version "
                                        + "\(plan.run.checkpoint.stateVersion)"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Resume") {
                                model.resumeLocalResearchPlan(plan)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Research. Bounded public document acquisition requires "
                + "one exact approval. Acquired packets remain ephemeral "
                + "until Keep."
        )
    }

    @ViewBuilder
    private var repositoryProvenance: some View {
        if let provenance = model.currentResearchRun?.provenance {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    "Repository idea evidence · commit "
                        + "\(provenance.sourceCommit.prefix(12)) · "
                        + "confidence "
                        + "\(Int(provenance.confidence * 100))%"
                )
                .font(.caption)
                ForEach(provenance.citations, id: \.passageID) {
                    citation in
                    Text("Cited: \(citation.passageID)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(
                    "Counterevidence: "
                        + provenance.counterevidence.joined(
                            separator: " · "
                        )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                Text(
                    "Validation: \(provenance.validationExperiment)"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func packetSection(
        _ result: ResearchAcquisitionResult
    ) -> some View {
        Section("Ephemeral research packet") {
            LabeledContent(
                "Route",
                value: result.receipt.route
            )
            LabeledContent(
                "Tool",
                value: result.receipt.toolID
            )
            LabeledContent(
                "Source",
                value: result.receipt.finalURL
            )
            LabeledContent(
                "Content",
                value: "\(result.receipt.contentType) · "
                    + "\(result.receipt.byteCount) bytes"
            )
            LabeledContent(
                "Digest",
                value: result.receipt.sha256
            )
            LabeledContent(
                "Cost",
                value: "USD \(result.receipt.actualCostUSD)"
            )
            LabeledContent(
                "Source quality",
                value: result.receipt.quality.reviewed
                    ? result.receipt.quality.kind.rawValue
                    : "Unreviewed · "
                        + result.receipt.quality.kind.rawValue
            )
            LabeledContent(
                "Publisher",
                value: result.receipt.quality.publisherHost
            )
            LabeledContent(
                "Retrieved",
                value: result.receipt.quality.retrievedAt.ISO8601Format()
            )
            if let modified = result.receipt.quality.sourceModifiedAt {
                LabeledContent(
                    "Source modified",
                    value: modified.ISO8601Format()
                )
            } else {
                LabeledContent("Source modified", value: "Not supplied")
            }
            LabeledContent(
                "Acquisition timing",
                value: result.receipt.startedAt.ISO8601Format()
                    + " – "
                    + result.receipt.completedAt.ISO8601Format()
            )
            LabeledContent(
                "Untrusted content signals",
                value: safetySignalSummary(result.receipt)
            )
            packetTypedResults(result.packet)
            HStack {
                Button(
                    "Keep Packet",
                    action: model.keepResearchAcquisitionPacket
                )
                .disabled(model.isResearchPacketRetentionRunning)
                Button(
                    "Discard Packet",
                    action: model.discardResearchAcquisitionPacket
                )
                .disabled(model.isResearchPacketRetentionRunning)
            }
            Text(
                "The source bytes are already immutable local evidence. "
                    + "Keep retains this packet; Discard removes "
                    + "only the ephemeral packet presentation."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func safetySignalSummary(
        _ receipt: ResearchSourceReceipt
    ) -> String {
        guard receipt.safetyInspectionPerformed == true else {
            return "Not inspected for textual signals"
        }
        return receipt.safetySignals.isEmpty
            ? "None detected"
            : receipt.safetySignals.map(\.rawValue).joined(separator: " · ")
    }

    @ViewBuilder
    private func packetTypedResults(
        _ packet: ResearchPacket
    ) -> some View {
        LabeledContent(
            "Facts",
            value: "\(packet.verifiedFacts.count)"
        )
        LabeledContent(
            "Inferences",
            value: "\(packet.inferences.count)"
        )
        LabeledContent(
            "Contradictions",
            value: "\(packet.contradictions.count)"
        )
        if !packet.unansweredQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("Unanswered questions").font(.headline)
                ForEach(packet.unansweredQuestions, id: \.id) {
                    question in
                    Text(question.question)
                    Text(question.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        if !packet.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("Recommendations").font(.headline)
                ForEach(packet.recommendations, id: \.id) {
                    recommendation in
                    Text(recommendation.statement)
                }
            }
        }
        if !packet.limitations.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("Limitations").font(.headline)
                ForEach(packet.limitations, id: \.id) { limitation in
                    Text(limitation.statement)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
