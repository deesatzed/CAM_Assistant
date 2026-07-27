import Testing
@testable import CAMAssistantCore

@Test("local conversation returns an ephemeral cited response from local context")
func localConversationReturnsEphemeralCitedResponse() throws {
    let context = ContextBundle(
        formatVersion: "context-v1",
        passages: [ContextPassage(sourceID: "source-1", passageID: "passage-1", modality: "text", text: "CAM Assistant keeps sources local by default.")],
        serializedContext: "", totalCharacters: 0, estimatedTokens: 0, droppedPassages: 0, thrashRate: 0
    )
    let response = try ConversationCoordinator().respond(question: "Where are sources kept?", context: context)

    #expect(response.route == .localRetrieval)
    #expect(response.retention == .ephemeral)
    #expect(response.citations.map(\.sourceID) == ["source-1"])
    #expect(response.confidence == .supported)
}

@Test("local conversation returns bounded extractive evidence from multiple cited passages")
func localConversationReturnsBoundedExtractiveEvidence() throws {
    let context = ContextBundle(
        formatVersion: "context-v1",
        passages: [
            ContextPassage(sourceID: "source-1", passageID: "passage-1", modality: "text", text: "First local evidence explains the storage boundary."),
            ContextPassage(sourceID: "source-2", passageID: "passage-2", modality: "markdown", text: "Second local evidence explains the approval boundary."),
            ContextPassage(sourceID: "source-3", passageID: "passage-3", modality: "code", text: "Third local evidence must fit within the response bound."),
            ContextPassage(sourceID: "source-4", passageID: "passage-4", modality: "text", text: "Fourth evidence is not shown because the extractive response is bounded."),
        ],
        serializedContext: "", totalCharacters: 0, estimatedTokens: 0, droppedPassages: 0, thrashRate: 0
    )

    let response = try ConversationCoordinator().respond(question: "What are the local boundaries?", context: context)

    #expect(response.text == "Local evidence (extractive):\n• First local evidence explains the storage boundary.\n• Second local evidence explains the approval boundary.\n• Third local evidence must fit within the response bound.")
    #expect(response.citations.map(\.passageID) == ["passage-1", "passage-2", "passage-3"])
    #expect(response.citations.map(\.quote) == [
        "First local evidence explains the storage boundary.",
        "Second local evidence explains the approval boundary.",
        "Third local evidence must fit within the response bound.",
    ])
}

@Test("local conversation rejects blank questions and marks missing context low confidence")
func localConversationRejectsBlankQuestionsAndMarksMissingContextLowConfidence() throws {
    let empty = ContextBundle(formatVersion: "context-v1", passages: [], serializedContext: "", totalCharacters: 0, estimatedTokens: 0, droppedPassages: 0, thrashRate: 0)
    let coordinator = ConversationCoordinator()

    #expect(throws: ConversationError.blankQuestion) {
        _ = try coordinator.respond(question: "  ", context: empty)
    }
    let response = try coordinator.respond(question: "What is known?", context: empty)
    #expect(response.confidence == .low)
    #expect(response.followUp == "Capture or index one relevant local source, then ask again.")
}

@Test("explicit local model abstention remains identified and unpromotable")
func explicitLocalModelAbstentionRemainsIdentifiedAndUnpromotable() throws {
    let generated = LocalModelGeneratedAnswer(
        text: "",
        modelID: "local/qwen",
        endpointIdentity: "http://127.0.0.1:8080/v1",
        citations: [],
        retention: .ephemeral
    )

    let response = try ConversationCoordinator().respond(
        question: "What is not in the evidence?",
        generated: generated
    )

    #expect(response.route == .localModel)
    #expect(response.confidence == .low)
    #expect(response.citations.isEmpty)
    #expect(response.modelIdentity == "local/qwen")
    #expect(response.endpointIdentity == "http://127.0.0.1:8080/v1")
    #expect(
        response.followUp
            == "Capture or index one relevant local source, then ask again."
    )
    #expect(
        throws: ConversationTransitionError.uncitedResponse
    ) {
        _ = try ConversationCoordinator().promoteToTask(
            ConversationCoordinator().keep(response),
            title: "Unsupported",
            acceptanceCriteria: ["Must remain unpromotable."],
            authority: .localRead
        )
    }
}

@Test("conversation keep discard and task promotion require explicit retained cited state")
func conversationKeepDiscardAndTaskPromotionRequireExplicitRetainedCitedState() throws {
    let context = ContextBundle(
        formatVersion: "context-v1",
        passages: [ContextPassage(sourceID: "source-1", passageID: "passage-1", modality: "text", text: "A cited local answer.")],
        serializedContext: "", totalCharacters: 0, estimatedTokens: 0, droppedPassages: 0, thrashRate: 0
    )
    let coordinator = ConversationCoordinator()
    let response = try coordinator.respond(question: "What is cited?", context: context)
    let kept = coordinator.keep(response)
    let task = try coordinator.promoteToTask(
        kept,
        title: "Review local answer",
        acceptanceCriteria: ["Confirm the cited source."],
        authority: .localRead
    )

    #expect(kept.disposition == .kept)
    #expect(task.citations == response.citations)
    #expect(task.authority == .localRead)
    #expect(throws: ConversationTransitionError.discardedResponse) {
        _ = try coordinator.promoteToTask(coordinator.discard(response), title: "No", acceptanceCriteria: ["Never"], authority: .localRead)
    }
}

@Test("local conversation context provider selects matching derived local documents")
func localConversationContextProviderSelectsMatchingDerivedDocuments() throws {
    let documents = [
        DerivedDocument(sourceID: ContentID(rawValue: "source-a"), text: "CAM Assistant stores local research citations.", modality: .text, extractorID: "test", capturedAt: .distantPast),
        DerivedDocument(sourceID: ContentID(rawValue: "source-b"), text: "A different note about storage.", modality: .text, extractorID: "test", capturedAt: .distantPast),
    ]
    let context = try LocalConversationContextProvider(documents: documents).context(for: "research citations")

    #expect(context.passages.map(\.sourceID) == ["source-a"])
    #expect(context.passages.first?.passageID == "source-a#0")
}
