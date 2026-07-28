import CAMAssistantCore
import SwiftUI

struct ActivityView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if model.pendingActionCard != nil {
                ActionCardView(card: model.pendingActionCard)
                    .frame(minHeight: 260)
                Divider()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local ingest activity")
                        .font(.headline)
                    Text("Cancel pending extraction or resume a cancelled or failed job. Original source bytes remain local.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isRefreshingActivity {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing local ingest activity")
                }
                Button("Refresh", action: model.reloadIngestJobs)
                    .disabled(
                        model.isRefreshingActivity
                            || model.isUpdatingIngestJob
                    )
            }
            .padding()

            if let activityError = model.activityError {
                Label(activityError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Activity error. \(activityError)")
            }

            if model.ingestJobs.isEmpty && !model.isRefreshingActivity {
                ContentUnavailableView(
                    "No ingest jobs yet",
                    systemImage: "tray",
                    description: Text(
                        "Clipboard and watched-folder captures appear here after they enter the local vault."
                    )
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.ingestJobs) { job in
                            IngestJobRow(
                                job: job,
                                isUpdating: model.isUpdatingIngestJob,
                                cancel: {
                                    model.cancelIngestJob(job.sourceID)
                                },
                                resume: {
                                    model.resumeIngestJob(job.sourceID)
                                }
                            )
                            Divider()
                        }
                    }
                    .padding(.horizontal)
                }
                .accessibilityLabel("Local ingest jobs")
            }
        }
        .onAppear(perform: model.reloadIngestJobs)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity and local ingest controls")
    }
}

private struct IngestJobRow: View {
    let job: IngestJobRecord
    let isUpdating: Bool
    let cancel: () -> Void
    let resume: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.sourceName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(statusLabel)
                    Text(job.contentType)
                    Text("Attempt \(job.attempts) of \(job.maxAttempts)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("Updated \(job.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            switch job.status {
            case .pending:
                Button("Cancel", action: cancel)
                    .disabled(isUpdating)
                    .accessibilityLabel("Cancel pending ingest for \(job.sourceName)")
            case .cancelled, .failed:
                Button("Resume", action: resume)
                    .disabled(isUpdating)
                    .accessibilityLabel("Resume ingest for \(job.sourceName)")
            case .retrying, .completed:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }

    private var statusLabel: String {
        switch job.status {
        case .pending: "Pending"
        case .retrying: "Retrying"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    private var statusSymbol: String {
        switch job.status {
        case .pending: "clock"
        case .retrying: "arrow.clockwise"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .pending, .retrying: .blue
        case .completed: .green
        case .failed: .orange
        case .cancelled: .secondary
        }
    }
}
