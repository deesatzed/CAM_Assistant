import CAMAssistantCore
import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppModel
    @FocusState private var questionFocused: Bool

    private var presentation: HomePresentation {
        HomePresentation(
            libraryItemCount: model.libraryPresentation.documentCount
        )
    }

    private var localAIAvailability: LocalAssistantAvailability {
        model.localModelHealth == nil ? .unavailable : .available
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                welcome
                capture
                ask
                result
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
        }
        .onAppear { questionFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Home. Save something, find it later, and keep only what matters.")
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(presentation.title)
                .font(.largeTitle.bold())
            Text(
                model.libraryPresentation.documentCount == 0
                    ? "Save something once, then find it whenever you need it."
                    : "Ask about anything you have saved."
            )
            .font(.title3)
            .foregroundStyle(.secondary)
            Text(presentation.privacyNote)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var capture: some View {
        GroupBox("Save something") {
            VStack(alignment: .leading, spacing: 10) {
                Button("Save Clipboard", action: model.captureCurrentClipboard)
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint(
                        "Saves text currently copied on this Mac to your private Library."
                    )
                Button("Watch a Folder") {
                    model.selection = .settings
                }
                .buttonStyle(.link)
                .accessibilityHint(
                    "Opens Settings where you can choose a folder to save from automatically."
                )
                if let message = model.captureMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let safetyMessage = model.captureNotice?.contentSafetyMessage {
                    Text(safetyMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if model.captureNotice?.canRetry == true {
                    Button("Try Again", action: model.captureCurrentClipboard)
                }
                if let details = model.captureNotice?.technicalDetails {
                    DisclosureGroup("Technical details") {
                        Text(details)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ask: some View {
        GroupBox("Find something") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField(
                        "What are you looking for?",
                        text: $model.conversationQuestion
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($questionFocused)
                    .onSubmit(model.sendLocalQuestion)
                    .accessibilityLabel("What are you looking for?")

                    Button("Ask", action: model.sendLocalQuestion)
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            model.conversationQuestion
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty || model.isGeneratingLocalModelAnswer
                        )
                }
                if model.isGeneratingLocalModelAnswer {
                    ProgressView("Searching your Library")
                }
                Text(localAIAvailability.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var result: some View {
        if let error = model.conversationError {
            ContentUnavailableView(
                "CAM couldn't finish that search",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if let response = model.conversationResponse {
            answer(response)
        } else if model.libraryPresentation.documentCount > 0 {
            ContentUnavailableView(
                "Ready when you are",
                systemImage: "magnifyingglass",
                description: Text("Ask about anything in your Library.")
            )
        }
    }

    private func answer(_ response: ConversationResponse) -> some View {
        GroupBox("What CAM found") {
            VStack(alignment: .leading, spacing: 12) {
                Text(response.text)
                    .textSelection(.enabled)

                if response.citations.isEmpty {
                    Text("CAM couldn't find enough support in your Library to save this answer.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Sources")
                        .font(.headline)
                    ForEach(
                        Array(response.citations.enumerated()),
                        id: \.element.passageID
                    ) { index, citation in
                        Button("Open source \(index + 1)") {
                            model.openLibrarySource(for: citation)
                        }
                        .buttonStyle(.link)
                    }
                }

                HStack {
                    Button("Keep", action: model.keepConversationResponse)
                        .buttonStyle(.borderedProminent)
                        .disabled(response.citations.isEmpty)
                    Button("Discard", action: model.discardConversationResponse)
                }

                if let record = model.conversationRecord {
                    Text(
                        record.disposition == .kept
                            ? "Kept in your Library."
                            : "Discarded. Nothing was saved."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                DisclosureGroup("Details") {
                    Text(
                        response.modelIdentity == nil
                            ? "Answer method: matching local sources"
                            : "Answer method: Local AI"
                    )
                    .font(.caption)
                    if let identity = response.modelIdentity {
                        Text("Local AI: \(identity)")
                            .font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
