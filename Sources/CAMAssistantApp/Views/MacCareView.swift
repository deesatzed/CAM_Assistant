import CAMAssistantCore
import SwiftUI

struct MacCareView: View {
    let presentation: MacCarePresentation?
    let errorMessage: String?
    let isAssessing: Bool
    let assess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mac Care is read-only").font(.title3)
            Button("Assess Standard Locations", action: assess).disabled(isAssessing)
            if isAssessing { ProgressView("Assessing locally") }
            if let presentation {
                Text(presentation.storageLabel)
                Text(presentation.storageStatusLabel)
                Text(presentation.applicationLabel)
                Text(presentation.startupLabel)
                ForEach(presentation.reviewFindings, id: \.self) { finding in
                    Text(finding).font(.caption).foregroundStyle(.secondary)
                }
                Text(presentation.mutationStatus).foregroundStyle(.secondary)
            }
            else { Text("Selected storage, application, and startup facts can be assessed locally. Any maintenance plan needs exact approval and cannot apply or undo changes in this milestone.") }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }.padding().accessibilityLabel("Mac Care. Read-only assessment. Apply and undo are unavailable.")
    }
}
