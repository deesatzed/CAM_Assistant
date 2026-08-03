import CAMAssistantCore
import SwiftUI

struct MacCareView: View {
    let presentation: MacCarePresentation?
    let errorMessage: String?
    let isAssessing: Bool
    let assess: () -> Void
    var manualGuide: MacCareOrganizationManualGuide?

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
            else {
                Text(
                    "Selected storage, application, and startup facts can be assessed locally. "
                        + "Mutations are unavailable in this milestone; the app will not apply or undo changes."
                )
            }

            manualGuidanceSection

            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mac Care. Read-only assessment. App-owned apply and undo are unavailable. Manual user steps only.")
    }

    @ViewBuilder
    private var manualGuidanceSection: some View {
        GroupBox("Manual reorganization (you run it)") {
            VStack(alignment: .leading, spacing: 8) {
                Text(MacCareOrganizationManualGuide.userResponsibilityNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let manualGuide {
                    Text("Shell (copy and run yourself):")
                        .font(.caption.weight(.semibold))
                    Text(manualGuide.shellCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    Text("Inverse if you need to put it back:")
                        .font(.caption.weight(.semibold))
                    Text(manualGuide.inverseShellCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    ForEach(Array(manualGuide.finderSteps.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(step)")
                            .font(.caption)
                    }
                } else {
                    Text(
                        "Example pattern after you choose paths yourself:\n"
                            + "mv \"/path/to/root/Inbox/file.txt\" \"/path/to/root/Archive/file.txt\""
                    )
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("Manual reorganization guidance. You run the steps yourself.")
    }
}
