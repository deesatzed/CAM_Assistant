import CAMAssistantCore
import SwiftUI

struct ConversationView: View {
    @ObservedObject var model: AppModel
    @FocusState private var questionFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask your local assistant")
                .font(.title2)
            Text(model.health.statusMessage)
                .foregroundStyle(.secondary)
            Text(model.hotkeyStatus.label)
                .font(.caption)
                .foregroundStyle(model.hotkeyStatus == .active ? Color.secondary : Color.orange)
                .accessibilityLabel(model.hotkeyStatus.label)
                .accessibilityHint(model.hotkeyStatus.hint)

            HStack {
                TextField("Ask about your indexed local sources", text: $model.conversationQuestion)
                    .textFieldStyle(.roundedBorder)
                    .focused($questionFocused)
                    .onSubmit(model.sendLocalQuestion)
                    .accessibilityLabel("Local assistant question")
                Button("Ask locally", action: model.sendLocalQuestion)
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityHint("Uses local retrieval only; it does not contact a provider or CAM.")
                Button(
                    model.isGeneratingLocalModelAnswer
                        ? "Generating Locally…"
                        : "Ask Selected Local Model",
                    action: model.sendSelectedLocalModelQuestion
                )
                .disabled(
                    model.localModelHealth == nil
                        || model.isGeneratingLocalModelAnswer
                )
                .accessibilityHint("Uses the health-checked loopback model with retrieved local citations. It never falls back to cloud, web, or CAM.")
            }
            Button(
                model.isGeneratingOpenRouterAnswer
                    ? "Generating via OpenRouter…"
                    : "Ask OpenRouter"
            ) {
                model.sendOpenRouterQuestion()
            }
            .disabled(
                !model.openRouterEnabled
                    || model.openRouterHealth == nil
                    || model.isGeneratingOpenRouterAnswer
            )
            .accessibilityHint(
                "Sends only the current local evidence and question to OpenRouter using your saved Keychain API key. No other provider fallback."
            )
            Button("Capture Clipboard Locally", action: model.captureCurrentClipboard)
                .accessibilityHint("Captures plain-text clipboard content into the local vault and indexes it without a network request.")
            if let captureMessage = model.captureMessage {
                Text(captureMessage).font(.caption).foregroundStyle(.secondary)
            }

            if let error = model.conversationError {
                Text(error).foregroundStyle(.red).accessibilityLabel("Question error: \(error)")
            }
            if let response = model.conversationResponse {
                responseView(response)
            } else {
                ContentUnavailableView(
                    "No answer yet",
                    systemImage: "text.bubble",
                    description: Text("Answers are ephemeral until you explicitly keep them. Add local sources to receive citations."))
            }
            Spacer()
        }
        .padding()
        .onAppear { questionFocused = true }
    }

    @ViewBuilder
    private func responseView(_ response: ConversationResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(response.text)
            Text(routeLabel(response))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let modelIdentity = response.modelIdentity,
               let endpointIdentity = response.endpointIdentity {
                Text("Model: \(modelIdentity) · Endpoint: \(endpointIdentity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if response.citations.isEmpty {
                Text("No local citation is available. Add or index a source before keeping or promoting this answer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let followUp = response.followUp {
                    Text("Next local step: \(followUp)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(response.citations, id: \.passageID) { citation in
                    HStack {
                        Text("Source: \(citation.sourceID) · \(citation.passageID)")
                            .font(.caption)
                        Button("Open in Library") {
                            model.openLibrarySource(for: citation)
                        }
                        .buttonStyle(.link)
                        .accessibilityHint("Opens the matching local derived source and its capture provenance.")
                    }
                }
            }
            HStack {
                Button("Keep", action: model.keepConversationResponse)
                    .disabled(response.citations.isEmpty)
                Button("Discard", action: model.discardConversationResponse)
                Button("Promote to Task", action: model.promoteConversationToTask)
                    .disabled(model.conversationRecord?.disposition != .kept || response.citations.isEmpty)
                Button("Keep as Fact") { model.keepConversationAsKnowledge(kind: .fact) }
                    .disabled(model.conversationRecord?.disposition != .kept || response.citations.isEmpty)
                Button("Keep as Assumption") { model.keepConversationAsKnowledge(kind: .assumption) }
                    .disabled(model.conversationRecord?.disposition != .kept || response.citations.isEmpty)
                if let record = model.conversationRecord {
                    Text(record.disposition == .kept ? "Kept locally" : "Discarded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let task = model.promotedTask {
                Text("Saved local task: \(task.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Local answer. \(response.text)")
    }

    private func routeLabel(_ response: ConversationResponse) -> String {
        let route = response.route == .localModel
            ? "selected local model"
            : "local retrieval"
        let confidence = response.confidence == .supported ? "supported" : "low"
        return "Route: \(route) · Confidence: \(confidence)"
    }
}
