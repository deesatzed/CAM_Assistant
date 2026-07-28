import CAMAssistantCore
import SwiftUI

struct TaskListView: View {
    let presentation: TaskListPresentation
    let errorMessage: String?
    let isRefreshing: Bool
    let reload: () -> Void
    let complete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(presentation.openCount) open local tasks")
                    .font(.title3)
                Spacer()
                Button("Refresh", action: reload).disabled(isRefreshing)
            }
            if isRefreshing { ProgressView("Refreshing local tasks") }
            if presentation.rows.isEmpty {
                ContentUnavailableView("No saved tasks", systemImage: "checklist", description: Text("Keep a cited local answer, then promote it to create a review task."))
            } else {
                List(presentation.rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title).font(.headline)
                        Text("\(row.statusLabel) · \(row.authorityLabel) · \(row.citationLabel)").font(.caption).foregroundStyle(.secondary)
                        ForEach(row.acceptanceCriteria, id: \.self) { criterion in
                            Text("• \(criterion)").font(.caption)
                        }
                        if row.statusLabel == "Open" {
                            Button("Mark Complete") { complete(row.id) }
                                .accessibilityHint("Marks this local task complete. It does not execute the task or alter its authority.")
                        }
                    }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tasks. \(presentation.openCount) open local tasks.")
    }
}
