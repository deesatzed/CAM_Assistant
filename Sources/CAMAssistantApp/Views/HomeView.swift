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
                DirectionStripView(model: model)
                capture
                ask
                result
                recentMemories
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(24)
        }
        .onAppear {
            questionFocused = true
            model.reloadDirectionProfile()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Home. Direction, save something, find it later, and keep only what matters."
        )
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
                Button("Watch a Folder…") {
                    model.openCaptureSettings()
                }
                .buttonStyle(.link)
                .accessibilityHint(
                    "Opens folder settings. Press Escape or Done to leave that sheet."
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
                        Button("Show in Library (\(index + 1))") {
                            model.openLibrarySource(for: citation)
                        }
                        .buttonStyle(.link)
                        .accessibilityHint("Opens Library focused on this saved item.")
                    }
                }

                HStack {
                    Button("Keep", action: model.keepConversationResponse)
                        .buttonStyle(.borderedProminent)
                        .disabled(response.citations.isEmpty)
                    Button("Discard", action: model.discardConversationResponse)
                }

                if let candidate = model.keptMemoryCandidate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A similar memory is already saved:")
                            .font(.callout)
                        Text(candidate.text)
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button(
                                "Update Existing",
                                action: model.updateExistingConversationMemory
                            )
                            Button(
                                "Save Separately",
                                action: model.saveConversationMemorySeparately
                            )
                        }
                    }
                } else if let status = model.keptMemoryStatus {
                    Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if model.canUndoLastKeptMemory {
                    Button("Undo Keep", action: model.undoLastKeptMemory)
                        .buttonStyle(.link)
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

    @ViewBuilder
    private var recentMemories: some View {
        if !model.keptMemories.isEmpty {
            GroupBox("Recently kept") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(model.keptMemories.prefix(3))) { memory in
                        Button {
                            model.selection = .library
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(memory.text)
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Text(
                                    "\(memory.citations.count) "
                                        + (memory.citations.count == 1
                                            ? "source" : "sources")
                                        + " · Open Library"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens Library where kept answers are listed.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
