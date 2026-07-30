import CAMAssistantCore
import SwiftUI

struct ModulesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Packaged text summary")
                    .font(.title3)
                Spacer()
                Button("Refresh", action: model.reloadPackagedTextSummaryModule)
            }

            Text(model.packagedTextSummaryPresentation.statusLabel)
                .foregroundStyle(.secondary)

            if !model.packagedTextSummaryPresentation.isInstalled {
                Button("Install Packaged Module", action: model.installPackagedTextSummaryModule)
            } else {
                HStack {
                    Button("Enable Module", action: model.enablePackagedTextSummaryModule)
                        .disabled(model.packagedTextSummaryPresentation.isEnabled)
                    Button("Grant Local Text Access", action: model.grantPackagedTextSummaryLocalRead)
                        .disabled(!model.packagedTextSummaryPresentation.isEnabled || model.packagedTextSummaryPresentation.hasLocalTextGrant)
                    Button("Disable Module", action: model.disablePackagedTextSummaryModule)
                        .disabled(!model.packagedTextSummaryPresentation.isEnabled)
                    Button("Remove Module", action: model.removePackagedTextSummaryModule)
                }

                TextField("Text to summarize", text: $model.packagedTextSummaryInput, axis: .vertical)
                    .lineLimit(3...8)
                Button("Summarize Locally", action: model.summarizeWithPackagedTextSummaryModule)
                    .disabled(!model.packagedTextSummaryPresentation.hasLocalTextGrant)

                if let result = model.packagedTextSummaryResult {
                    Text("Local summary: \(result.wordCount) words, \(result.characterCount) characters.")
                        .font(.caption)
                }
            }

            if let error = model.packagedTextSummaryError {
                Text(error).foregroundStyle(.red)
            }

            Text("No network, shell command, downloaded code, or vault browsing is available to this module. Its only operation counts words and characters in text you enter here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Modules. Trusted native module lifecycle. Install, enable, grant, summarize, disable, and remove remain explicit local actions.")
    }
}
